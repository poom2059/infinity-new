import crypto from 'crypto';
import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { db, initDb, dbDriver } from './db.mjs';
import {
  authMiddleware,
  requireRole,
  requestOtp,
  verifyOtp,
  verifyFirebaseIdToken,
  loginWithSocial,
  userPublic,
} from './auth.mjs';
import { registerOauthRoutes } from './oauth.mjs';
import {
  createPaymentIntent,
  getPaymentIntent,
  handleOmiseWebhook,
  confirmSimulated,
  creditWallet,
} from './payments.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverRoot = path.join(__dirname, '..');

export async function createApp() {
  await initDb();
  const app = express();
  app.set('trust proxy', 1);

  const corsOrigin = (process.env.CORS_ORIGIN || '').trim();
  app.use(
    cors(
      corsOrigin
        ? { origin: corsOrigin.split(',').map((s) => s.trim()).filter(Boolean), credentials: true }
        : undefined,
    ),
  );
  app.use(express.json({ limit: '12mb' }));

  const auth = authMiddleware(db);

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      service: 'infinity-api',
      db: dbDriver(),
      rev: process.env.RENDER_GIT_COMMIT || process.env.GIT_COMMIT || 'local',
      deployed_at: process.env.RENDER_GIT_COMMIT ? undefined : new Date().toISOString(),
    });
  });

  // ---- Auth ----
  app.post('/v1/auth/request-otp', async (req, res, next) => {
    try {
      res.json(await requestOtp(req.body?.phone));
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/auth/verify-otp', async (req, res, next) => {
    try {
      res.json(await verifyOtp(req.body?.phone, req.body?.code));
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/auth/firebase', async (req, res, next) => {
    try {
      res.json(await verifyFirebaseIdToken(req.body?.id_token));
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/auth/social', async (req, res, next) => {
    try {
      res.json(
        await loginWithSocial({
          provider: req.body?.provider,
          idToken: req.body?.id_token,
          accessToken: req.body?.access_token,
        }),
      );
    } catch (e) {
      next(e);
    }
  });

  registerOauthRoutes(app);

  app.get('/v1/me', auth, async (req, res, next) => {
    try {
      res.json(await userPublic(req.userId));
    } catch (e) {
      next(e);
    }
  });

  app.patch('/v1/me', auth, async (req, res, next) => {
    try {
      const { name } = req.body || {};
      if (name) await db.run('UPDATE users SET name = ? WHERE id = ?', [String(name), req.userId]);
      res.json(await userPublic(req.userId));
    } catch (e) {
      next(e);
    }
  });

  // ---- Catalog / orders / addresses ----
  app.get('/v1/merchants', auth, async (req, res, next) => {
    try {
      const rows = await db.all('SELECT * FROM merchants WHERE approved = 1 ORDER BY usage_count DESC');
      res.json({ merchants: rows });
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/merchants/:slug/menu', auth, async (req, res, next) => {
    try {
      const m = await db.one('SELECT * FROM merchants WHERE slug = ?', [req.params.slug]);
      if (!m) return res.status(404).json({ error: 'merchant not found' });
      const items = await db.all('SELECT * FROM menu_items WHERE merchant_id = ?', [m.id]);
      res.json({ merchant: m, items });
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/orders', auth, async (req, res, next) => {
    try {
      const rows = await db.all('SELECT * FROM orders WHERE user_id = ? ORDER BY placed_at DESC', [
        req.userId,
      ]);
      res.json({ orders: rows });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/orders', auth, async (req, res, next) => {
    try {
      const body = req.body || {};
      if (body.payment_intent_id) {
        const pi = await db.one('SELECT * FROM payment_intents WHERE id = ? AND user_id = ?', [
          body.payment_intent_id,
          req.userId,
        ]);
        if (!pi || pi.status !== 'succeeded') {
          return res.status(402).json({ error: 'ยังไม่ได้ชำระเงินสำเร็จ' });
        }
      }
      const id = `ord-${Date.now()}`;
      const placedAt = new Date().toISOString();
      await db.run(
        `INSERT INTO orders (id, user_id, merchant_slug, placed_at, total_baht, pickup_mode, status, lines_json, breakdown_json, payment_intent_id)
         VALUES (?,?,?,?,?,?,?,?,?,?)`,
        [
          id,
          req.userId,
          String(body.merchant_slug || ''),
          placedAt,
          Number(body.total_baht || 0),
          body.pickup_mode ? 1 : 0,
          String(body.status || 'กำลังจัดส่ง'),
          JSON.stringify(body.lines || []),
          JSON.stringify(body.breakdown || {}),
          body.payment_intent_id || null,
        ],
      );
      await notifyUser(req.userId, 'ออเดอร์ใหม่', `สั่งซื้อสำเร็จ ${id}`, 'order');
      const row = await db.one('SELECT * FROM orders WHERE id = ?', [id]);
      res.status(201).json(row);
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/orders/:id/complete', auth, async (req, res, next) => {
    try {
      await db.run('UPDATE orders SET status = ? WHERE id = ? AND user_id = ?', [
        'สำเร็จ',
        req.params.id,
        req.userId,
      ]);
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/addresses', auth, async (req, res, next) => {
    try {
      res.json({ addresses: await db.all('SELECT * FROM addresses WHERE user_id = ?', [req.userId]) });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/addresses', auth, async (req, res, next) => {
    try {
      const id = crypto.randomUUID();
      const { label, detail } = req.body || {};
      await db.run('INSERT INTO addresses (id, user_id, label, detail) VALUES (?,?,?,?)', [
        id,
        req.userId,
        String(label || ''),
        String(detail || ''),
      ]);
      res.status(201).json(await db.one('SELECT * FROM addresses WHERE id = ?', [id]));
    } catch (e) {
      next(e);
    }
  });

  // ---- Wallet / payments ----
  app.get('/v1/wallet', auth, async (req, res, next) => {
    try {
      const u = await db.one('SELECT wallet_balance_baht, points FROM users WHERE id = ?', [req.userId]);
      res.json({
        balance_baht: Number(u?.wallet_balance_baht || 0),
        points: Number(u?.points || 0),
      });
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/wallet/ledger', auth, async (req, res, next) => {
    try {
      const rows = await db.all(
        'SELECT * FROM wallet_ledger WHERE user_id = ? ORDER BY created_at DESC',
        [req.userId],
      );
      res.json({ entries: rows });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/payments/intents', auth, async (req, res, next) => {
    try {
      const body = req.body || {};
      const intent = await createPaymentIntent({
        userId: req.userId,
        amountBaht: body.amount_baht,
        purpose: body.purpose || 'order',
        orderId: body.order_id || null,
        returnUri: body.return_uri || null,
      });
      res.status(201).json(intent);
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/payments/:id', auth, async (req, res, next) => {
    try {
      const intent = await getPaymentIntent(req.params.id, req.userId);
      if (!intent) return res.status(404).json({ error: 'not found' });
      res.json(intent);
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/payments/:id/confirm-simulate', auth, async (req, res, next) => {
    try {
      res.json(await confirmSimulated(req.params.id, req.userId));
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/payments/omise-webhook', async (req, res, next) => {
    try {
      res.json(await handleOmiseWebhook(req.body || {}));
    } catch (e) {
      next(e);
    }
  });

  // ---- Maps ----
  app.get('/v1/maps/geocode', auth, async (req, res, next) => {
    try {
      const q = String(req.query.q || 'Bangkok');
      const key = (process.env.GOOGLE_MAPS_SERVER_KEY || '').trim();
      if (!key) {
        return res.status(503).json({ error: 'ยังไม่ได้ตั้งค่า GOOGLE_MAPS_SERVER_KEY' });
      }
      const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(q)}&key=${key}&language=th&region=th`;
      const r = await fetch(url);
      const data = await r.json();
      const first = data.results?.[0];
      if (!first) return res.status(404).json({ error: 'ไม่พบตำแหน่ง' });
      res.json({
        label: first.formatted_address,
        lat: first.geometry.location.lat,
        lng: first.geometry.location.lng,
      });
    } catch (e) {
      next(e);
    }
  });

  // ---- Push / notifications ----
  app.post('/v1/notifications/device', auth, async (req, res, next) => {
    try {
      const t = String((req.body || {}).token || '');
      if (!t) return res.status(400).json({ error: 'missing token' });
      if (dbDriver() === 'pg') {
        await db.run(
          `INSERT INTO device_tokens (token, user_id) VALUES (?, ?)
           ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id`,
          [t, req.userId],
        );
      } else {
        await db.run('INSERT OR REPLACE INTO device_tokens (token, user_id) VALUES (?, ?)', [
          t,
          req.userId,
        ]);
      }
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/notifications', auth, async (req, res, next) => {
    try {
      const rows = await db.all(
        'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 100',
        [req.userId],
      );
      res.json({ notifications: rows });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/notifications/:id/read', auth, async (req, res, next) => {
    try {
      await db.run('UPDATE notifications SET read = 1 WHERE id = ? AND user_id = ?', [
        req.params.id,
        req.userId,
      ]);
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });

  // ---- Saved places ----
  app.get('/v1/saved-places', auth, async (req, res, next) => {
    try {
      res.json({ places: await db.all('SELECT * FROM saved_places WHERE user_id = ?', [req.userId]) });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/saved-places', auth, async (req, res, next) => {
    try {
      const id = crypto.randomUUID();
      const { label, detail, lat, lng } = req.body || {};
      await db.run(
        'INSERT INTO saved_places (id, user_id, label, detail, lat, lng) VALUES (?,?,?,?,?,?)',
        [id, req.userId, String(label || ''), String(detail || ''), lat ?? null, lng ?? null],
      );
      res.status(201).json(await db.one('SELECT * FROM saved_places WHERE id = ?', [id]));
    } catch (e) {
      next(e);
    }
  });

  app.delete('/v1/saved-places/:id', auth, async (req, res, next) => {
    try {
      await db.run('DELETE FROM saved_places WHERE id = ? AND user_id = ?', [req.params.id, req.userId]);
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });

  // ---- Bookings (ride / express / travel) ----
  app.post('/v1/bookings', auth, async (req, res, next) => {
    try {
      const { kind, payload } = req.body || {};
      if (!kind) return res.status(400).json({ error: 'missing kind' });
      const id = crypto.randomUUID();
      const created = new Date().toISOString();
      await db.run(
        'INSERT INTO bookings (id, user_id, kind, payload_json, status, created_at) VALUES (?,?,?,?,?,?)',
        [id, req.userId, String(kind), JSON.stringify(payload || {}), 'pending', created],
      );
      await notifyUser(req.userId, 'รับคำขอแล้ว', `คำขอ ${kind} ถูกบันทึกแล้ว`, 'system');
      // notify admins
      const admins = await db.all(`SELECT id FROM users WHERE role = 'admin'`);
      for (const a of admins) {
        await notifyUser(a.id, 'คำขอใหม่', `มีคำขอ ${kind} จากผู้ใช้`, 'system');
      }
      res.status(201).json({ id, kind, status: 'pending', created_at: created });
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/bookings', auth, async (req, res, next) => {
    try {
      const rows = await db.all(
        'SELECT * FROM bookings WHERE user_id = ? ORDER BY created_at DESC',
        [req.userId],
      );
      res.json({
        bookings: rows.map((r) => ({
          ...r,
          payload: safeJson(r.payload_json),
        })),
      });
    } catch (e) {
      next(e);
    }
  });

  // ---- Jobs ----
  registerJobRoutes(app, auth);

  // ---- Admin / merchant (kept minimal from previous API) ----
  registerAdminMerchantRoutes(app, auth);

  // ---- Static Flutter web ----
  const serveWeb = String(process.env.SERVE_WEB || 'true').toLowerCase() !== 'false';
  const webCandidates = [
    process.env.WEB_ROOT ? path.resolve(process.env.WEB_ROOT) : null,
    path.join(serverRoot, 'public'),
    path.join(serverRoot, '..', 'build', 'web'),
  ].filter(Boolean);
  let webRoot = null;
  if (serveWeb) {
    webRoot = webCandidates.find((p) => fs.existsSync(path.join(p, 'index.html'))) || null;
    if (webRoot) {
      app.use(
        express.static(webRoot, {
          index: 'index.html',
          maxAge: '1y',
          setHeaders(res, filePath) {
            const base = path.basename(filePath);
            if (
              base === 'index.html' ||
              base === 'flutter_service_worker.js' ||
              base === 'flutter_bootstrap.js' ||
              base === 'manifest.json' ||
              base === 'main.dart.js' ||
              base === 'main.dart.js.map'
            ) {
              res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
            }
          },
        }),
      );
      app.use((req, res, next) => {
        if (req.method !== 'GET' && req.method !== 'HEAD') return next();
        if (req.path.startsWith('/v1/') || req.path === '/health') return next();
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        res.sendFile(path.join(webRoot, 'index.html'), (err) => {
          if (err) next();
        });
      });
    }
  }

  app.use((err, _req, res, _next) => {
    const status = err.status || 500;
    console.error(err);
    res.status(status).json({ error: err.message || 'server error' });
  });

  return app;
}

function safeJson(s) {
  try {
    return JSON.parse(s || '{}');
  } catch {
    return {};
  }
}

async function notifyUser(userId, title, body, category = 'system') {
  await db.run(
    'INSERT INTO notifications (id, user_id, title, body, category, created_at, read) VALUES (?,?,?,?,?,?,0)',
    [crypto.randomUUID(), userId, title, body, category, new Date().toISOString()],
  );
  // FCM send if configured
  try {
    await sendFcmToUser(userId, title, body);
  } catch (e) {
    console.warn('FCM send skipped:', e.message);
  }
}

async function sendFcmToUser(userId, title, body) {
  const raw = (process.env.FIREBASE_SERVICE_ACCOUNT || '').trim();
  if (!raw) return;
  const tokens = await db.all('SELECT token FROM device_tokens WHERE user_id = ?', [userId]);
  if (!tokens.length) return;
  const admin = await import('firebase-admin');
  if (!admin.default.apps.length) {
    admin.default.initializeApp({
      credential: admin.default.credential.cert(JSON.parse(raw)),
    });
  }
  await admin.default.messaging().sendEachForMulticast({
    tokens: tokens.map((t) => t.token),
    notification: { title, body },
  });
}

function registerJobRoutes(app, auth) {
  app.get('/v1/jobs', auth, async (req, res, next) => {
    try {
      const rows = await db.all('SELECT * FROM jobs ORDER BY created_at DESC LIMIT 200');
      const out = [];
      for (const j of rows) {
        const applicants = await db.all('SELECT * FROM job_applicants WHERE job_id = ?', [j.id]);
        out.push(mapJob(j, applicants));
      }
      res.json({ jobs: out });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/jobs', auth, async (req, res, next) => {
    try {
      const b = req.body || {};
      const id = crypto.randomUUID();
      const created = new Date().toISOString();
      const total = Math.round(Number(b.total_baht || 0));
      if (total < 100) return res.status(400).json({ error: 'ค่าจ้างอย่างน้อย 100 บาท' });

      let escrowIntentId = null;
      if (b.create_escrow) {
        const half = Math.ceil(total / 2);
        const intent = await createPaymentIntent({
          userId: req.userId,
          amountBaht: half,
          purpose: 'job_escrow',
        });
        escrowIntentId = intent.id;
      }

      await db.run(
        `INSERT INTO jobs (
          id, poster_id, title, profession, description, total_baht, age_min, age_max,
          work_time_label, store_phone, store_address, contact_phone, worker_gender,
          status, chosen_applicant_id, escrow_intent_id, created_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [
          id,
          req.userId,
          String(b.title || ''),
          String(b.profession || ''),
          String(b.description || ''),
          total,
          Number(b.age_min || 18),
          Number(b.age_max || 60),
          String(b.work_time_label || ''),
          String(b.store_phone || ''),
          String(b.store_address || ''),
          String(b.contact_phone || ''),
          String(b.worker_gender || 'any'),
          escrowIntentId ? 'pending_payment' : 'open',
          null,
          escrowIntentId,
          created,
        ],
      );
      const j = await db.one('SELECT * FROM jobs WHERE id = ?', [id]);
      res.status(201).json({ job: mapJob(j, []), escrow_intent_id: escrowIntentId });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/jobs/:id/publish', auth, async (req, res, next) => {
    try {
      const j = await db.one('SELECT * FROM jobs WHERE id = ?', [req.params.id]);
      if (!j || j.poster_id !== req.userId) return res.status(404).json({ error: 'not found' });
      if (j.escrow_intent_id) {
        const pi = await db.one('SELECT * FROM payment_intents WHERE id = ?', [j.escrow_intent_id]);
        if (!pi || pi.status !== 'succeeded') {
          return res.status(402).json({ error: 'มัดจำยังไม่สำเร็จ' });
        }
      }
      await db.run('UPDATE jobs SET status = ? WHERE id = ?', ['open', j.id]);
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/jobs/:id/apply', auth, async (req, res, next) => {
    try {
      const j = await db.one('SELECT * FROM jobs WHERE id = ?', [req.params.id]);
      if (!j || j.status !== 'open') return res.status(400).json({ error: 'งานนี้รับสมัครไม่ได้' });
      if (j.poster_id === req.userId) return res.status(400).json({ error: 'ไม่สามารถสมัครงานตัวเอง' });
      const exists = await db.one(
        'SELECT id FROM job_applicants WHERE job_id = ? AND user_id = ?',
        [j.id, req.userId],
      );
      if (exists) return res.status(400).json({ error: 'สมัครแล้ว' });
      const u = await userPublic(req.userId);
      await db.run(
        'INSERT INTO job_applicants (id, job_id, user_id, display_name, applied_at) VALUES (?,?,?,?,?)',
        [crypto.randomUUID(), j.id, req.userId, u.name || 'ผู้สมัคร', new Date().toISOString()],
      );
      await notifyUser(j.poster_id, 'มีผู้สมัครงาน', `${u.name} สมัครงานของคุณ`, 'order');
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/jobs/:id/assign', auth, async (req, res, next) => {
    try {
      const j = await db.one('SELECT * FROM jobs WHERE id = ?', [req.params.id]);
      if (!j || j.poster_id !== req.userId) return res.status(404).json({ error: 'not found' });
      const applicantId = String(req.body?.applicant_user_id || '');
      const a = await db.one('SELECT * FROM job_applicants WHERE job_id = ? AND user_id = ?', [
        j.id,
        applicantId,
      ]);
      if (!a) return res.status(404).json({ error: 'ไม่พบผู้สมัคร' });
      await db.run('UPDATE jobs SET status = ?, chosen_applicant_id = ? WHERE id = ?', [
        'assigned',
        applicantId,
        j.id,
      ]);
      await notifyUser(applicantId, 'คุณได้รับงาน', `ได้รับมอบหมายงาน: ${j.title}`, 'order');
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/jobs/:id/messages', auth, async (req, res, next) => {
    try {
      const rows = await db.all(
        'SELECT * FROM job_messages WHERE job_id = ? ORDER BY sent_at ASC',
        [req.params.id],
      );
      res.json({ messages: rows });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/jobs/:id/messages', auth, async (req, res, next) => {
    try {
      const text = String(req.body?.text || '').trim();
      if (!text) return res.status(400).json({ error: 'ข้อความว่าง' });
      const u = await userPublic(req.userId);
      const id = crypto.randomUUID();
      const sentAt = new Date().toISOString();
      await db.run(
        'INSERT INTO job_messages (id, job_id, sender_id, sender_label, text, sent_at) VALUES (?,?,?,?,?,?)',
        [id, req.params.id, req.userId, u.name || 'ผู้ใช้', text, sentAt],
      );
      res.status(201).json({
        id,
        job_id: req.params.id,
        sender_id: req.userId,
        sender_label: u.name,
        text,
        sent_at: sentAt,
      });
    } catch (e) {
      next(e);
    }
  });
}

function mapJob(j, applicants) {
  return {
    id: j.id,
    poster_id: j.poster_id,
    title: j.title,
    profession: j.profession,
    description: j.description,
    total_baht: j.total_baht,
    age_min: j.age_min,
    age_max: j.age_max,
    work_time_label: j.work_time_label,
    store_phone: j.store_phone,
    store_address: j.store_address,
    contact_phone: j.contact_phone,
    worker_gender: j.worker_gender,
    status: j.status,
    chosen_applicant_id: j.chosen_applicant_id,
    escrow_intent_id: j.escrow_intent_id,
    created_at: j.created_at,
    applicants: applicants.map((a) => ({
      id: a.user_id,
      display_name: a.display_name,
      applied_at: a.applied_at,
    })),
  };
}

function registerAdminMerchantRoutes(app, auth) {
  async function merchantRecordForUser(userId) {
    const u = await db.one('SELECT merchant_slug FROM users WHERE id = ?', [userId]);
    if (!u?.merchant_slug) return null;
    return db.one('SELECT * FROM merchants WHERE slug = ?', [u.merchant_slug]);
  }

  app.get('/v1/admin/users', auth, requireRole('admin'), async (_req, res, next) => {
    try {
      res.json({ users: await db.all('SELECT id, phone, email, name, role, merchant_slug FROM users') });
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/admin/bookings', auth, requireRole('admin'), async (_req, res, next) => {
    try {
      const rows = await db.all('SELECT * FROM bookings ORDER BY created_at DESC LIMIT 200');
      res.json({
        bookings: rows.map((r) => ({ ...r, payload: safeJson(r.payload_json) })),
      });
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/merchant/my-menu', auth, requireRole('merchant'), async (req, res, next) => {
    try {
      const merchant = await merchantRecordForUser(req.userId);
      if (!merchant) return res.status(404).json({ error: 'ยังไม่มีร้านผูกกับบัญชี' });
      const items = await db.all('SELECT * FROM menu_items WHERE merchant_id = ?', [merchant.id]);
      res.json({ merchant, items });
    } catch (e) {
      next(e);
    }
  });

  app.post('/v1/merchant/applications', auth, async (req, res, next) => {
    try {
      const { shop_name, category, proposed_slug, notes } = req.body || {};
      const id = crypto.randomUUID();
      await db.run(
        `INSERT INTO merchant_applications (id, user_id, shop_name, category, proposed_slug, notes, status, created_at)
         VALUES (?,?,?,?,?,?, 'pending', ?)`,
        [
          id,
          req.userId,
          String(shop_name || ''),
          String(category || ''),
          String(proposed_slug || ''),
          String(notes || ''),
          new Date().toISOString(),
        ],
      );
      res.status(201).json({ id, status: 'pending' });
    } catch (e) {
      next(e);
    }
  });
}
