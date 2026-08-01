import crypto from 'crypto';
import express from 'express';
import cors from 'cors';
import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverRoot = path.join(__dirname, '..');
const dataDir = path.join(serverRoot, 'data');
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}
const dbPath = process.env.DB_PATH
  ? path.resolve(process.env.DB_PATH)
  : path.join(dataDir, 'infinity.sqlite');
const db = new Database(dbPath);

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  phone TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'customer'
);
CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS merchants (
  id TEXT PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  eta_minutes INTEGER NOT NULL,
  rating REAL NOT NULL,
  usage_count INTEGER NOT NULL,
  image_url TEXT NOT NULL,
  distance_km REAL NOT NULL,
  delivery_fee INTEGER NOT NULL,
  approved INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS menu_items (
  id TEXT PRIMARY KEY,
  merchant_id TEXT NOT NULL,
  name TEXT NOT NULL,
  price INTEGER NOT NULL,
  description TEXT,
  image_url TEXT,
  FOREIGN KEY(merchant_id) REFERENCES merchants(id)
);
CREATE TABLE IF NOT EXISTS addresses (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  label TEXT NOT NULL,
  detail TEXT NOT NULL,
  FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  merchant_slug TEXT NOT NULL,
  placed_at TEXT NOT NULL,
  total_baht INTEGER NOT NULL,
  pickup_mode INTEGER NOT NULL,
  status TEXT NOT NULL,
  lines_json TEXT NOT NULL,
  breakdown_json TEXT NOT NULL,
  FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS wallet_ledger (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  amount_baht REAL NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS payment_intents (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  amount_baht INTEGER NOT NULL,
  status TEXT NOT NULL,
  order_id TEXT,
  FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS device_tokens (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  FOREIGN KEY(user_id) REFERENCES users(id)
);
`);

function migrate() {
  const userCols = db.prepare('PRAGMA table_info(users)').all();
  if (!userCols.some((c) => c.name === 'merchant_slug')) {
    db.exec('ALTER TABLE users ADD COLUMN merchant_slug TEXT');
  }
  db.exec(`
CREATE TABLE IF NOT EXISTS merchant_applications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  shop_name TEXT NOT NULL,
  category TEXT NOT NULL,
  proposed_slug TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL,
  FOREIGN KEY(user_id) REFERENCES users(id)
);
`);
}

migrate();

function migrateMenuSection() {
  const cols = db.prepare('PRAGMA table_info(menu_items)').all();
  if (!cols.some((c) => c.name === 'menu_section')) {
    db.exec(`ALTER TABLE menu_items ADD COLUMN menu_section TEXT NOT NULL DEFAULT 'อื่นๆ'`);
  }
}

migrateMenuSection();

function merchantRecordForUser(userId) {
  const u = db.prepare('SELECT merchant_slug FROM users WHERE id = ?').get(userId);
  const slug = u?.merchant_slug;
  if (!slug) return null;
  return db.prepare('SELECT * FROM merchants WHERE slug = ?').get(slug);
}

function seed() {
  const count = db.prepare('SELECT COUNT(*) AS c FROM merchants').get();
  if (count.c > 0) return;
  const merchants = [
    ['m1', 'infinity-chicken', 'ไก่ทอดอินฟินิตี้', 'ไก่ทอด', 15, 4.8, 1520, 'https://images.unsplash.com/photo-1562967914-608f82629710?w=1200&q=80', 1.3, 0],
    ['m2', 'daeng-noodle', 'แดงด่วนก๋วยเตี๋ยว', 'ก๋วยเตี๋ยว', 20, 4.7, 1380, 'https://images.unsplash.com/photo-1555126634-323283e090fa?w=1200&q=80', 2.4, 15],
    ['m3', 'white-bowl-salad', 'สลัดโบว์ขาว', 'สุขภาพ', 18, 4.6, 1240, 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200&q=80', 3.2, 20],
    ['m4', 'sushi-infinity', 'ซูชิอินฟินิตี้', 'ญี่ปุ่น', 25, 4.9, 1190, 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=1200&q=80', 4.9, 35],
    ['m5', 'tum-saeb', 'ตำแซ่บโคตรนัว', 'อีสาน', 22, 4.5, 980, 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=1200&q=80', 2.7, 20],
    ['m6', 'burger-lab', 'เบอร์เกอร์แล็บ', 'เบอร์เกอร์', 19, 4.6, 870, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1200&q=80', 5.5, 45],
  ];
  const insM = db.prepare(
    `INSERT INTO merchants (id, slug, name, category, eta_minutes, rating, usage_count, image_url, distance_km, delivery_fee) VALUES (?,?,?,?,?,?,?,?,?,?)`,
  );
  for (const r of merchants) insM.run(...r);

  const items = [
    ['i1', 'm1', 'ไก่ทอดซอสเกาหลี', 85, 'สะโพกไก่ทอดกรอบ', 'https://images.unsplash.com/photo-1562967914-608f82629710?w=1200&q=80'],
    ['i2', 'm1', 'ไก่เผ็ดดับเบิลชีส', 95, 'ไก่ทอดรสเผ็ด', 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=1200&q=80'],
    ['i3', 'm4', 'ข้าวหน้าปลาแซลมอน', 165, 'ปลาแซลมอนสด', 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=1200&q=80'],
  ];
  const insI = db.prepare(
    `INSERT INTO menu_items (id, merchant_id, name, price, description, image_url, menu_section) VALUES (?,?,?,?,?,?,?)`,
  );
  for (const r of items) insI.run(...r, 'อาหารและเครื่องดื่ม');

  const adminId = crypto.randomUUID();
  const merchantUserId = crypto.randomUUID();
  db.prepare('INSERT INTO users (id, phone, name, role) VALUES (?,?,?,?)').run(adminId, '0810000000', 'แอดมิน', 'admin');
  db.prepare('INSERT INTO users (id, phone, name, role) VALUES (?,?,?,?)').run(merchantUserId, '0810000001', 'เจ้าของร้าน', 'merchant');
  db.prepare('UPDATE users SET merchant_slug = ? WHERE id = ?').run('infinity-chicken', merchantUserId);
}

seed();

function backfillDemoMerchantSlug() {
  const row = db.prepare(`SELECT id FROM users WHERE phone = '0810000001' LIMIT 1`).get();
  if (row) {
    db.prepare(`UPDATE users SET merchant_slug = COALESCE(merchant_slug, 'infinity-chicken') WHERE id = ?`).run(row.id);
  }
}

backfillDemoMerchantSlug();

/** บัญชีผู้ดูแลระบบคงที่ — ล็อกอินด้วยเบอร์ + OTP 6 หลักใดก็ได้ (โหมด dev) */
function ensureSuperAdminAccounts() {
  const accounts = [
    { phone: '0810000000', name: 'แอดมิน', role: 'admin' },
    { phone: '0888888888', name: 'ผู้ดูแลระบบสูงสุด', role: 'admin' },
  ];
  for (const a of accounts) {
    const row = db.prepare('SELECT id FROM users WHERE phone = ?').get(a.phone);
    if (!row) {
      db.prepare('INSERT INTO users (id, phone, name, role) VALUES (?,?,?,?)').run(
        crypto.randomUUID(),
        a.phone,
        a.name,
        a.role,
      );
    } else {
      db.prepare('UPDATE users SET name = ?, role = ? WHERE phone = ?').run(a.name, a.role, a.phone);
    }
  }
}

ensureSuperAdminAccounts();

const app = express();

// Cloudways / reverse proxy
app.set('trust proxy', 1);

const corsOrigin = (process.env.CORS_ORIGIN || '').trim();
app.use(
  cors(
    corsOrigin
      ? {
          origin: corsOrigin.split(',').map((s) => s.trim()).filter(Boolean),
          credentials: true,
        }
      : undefined,
  ),
);
app.use(express.json({ limit: '12mb' }));

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'infinity-api' });
});

function auth(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'missing token' });
  const row = db.prepare('SELECT user_id FROM sessions WHERE token = ?').get(token);
  if (!row) return res.status(401).json({ error: 'invalid token' });
  req.userId = row.user_id;
  next();
}

function requireRole(role) {
  return (req, res, next) => {
    const u = db.prepare('SELECT role FROM users WHERE id = ?').get(req.userId);
    if (!u || u.role !== role) return res.status(403).json({ error: 'forbidden' });
    next();
  };
}

app.post('/v1/auth/request-otp', (req, res) => {
  res.json({ ok: true, message: 'dev: use any 6-digit code' });
});

app.post('/v1/auth/verify-otp', (req, res) => {
  const { phone, code } = req.body || {};
  if (!phone || !/^\d{10,15}$/.test(String(phone))) {
    return res.status(400).json({ error: 'invalid phone' });
  }
  if (!/^\d{6}$/.test(String(code))) {
    return res.status(400).json({ error: 'invalid code' });
  }
  let user = db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);
  if (!user) {
    const id = crypto.randomUUID();
    db.prepare('INSERT INTO users (id, phone, name, role) VALUES (?,?,?,?)').run(id, phone, 'สมาชิก Infinity', 'customer');
    user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  }
  const token = crypto.randomBytes(24).toString('hex');
  db.prepare('INSERT INTO sessions (token, user_id) VALUES (?, ?)').run(token, user.id);
  const full = db.prepare('SELECT id, phone, name, role, merchant_slug FROM users WHERE id = ?').get(user.id);
  res.json({
    token,
    user: {
      id: full.id,
      phone: full.phone,
      name: full.name,
      role: full.role,
      merchant_slug: full.merchant_slug ?? null,
    },
  });
});

app.get('/v1/me', auth, (req, res) => {
  const user = db.prepare('SELECT id, phone, name, role, merchant_slug FROM users WHERE id = ?').get(req.userId);
  res.json(user);
});

app.patch('/v1/me', auth, (req, res) => {
  const { name } = req.body || {};
  if (name) db.prepare('UPDATE users SET name = ? WHERE id = ?').run(String(name), req.userId);
  const user = db.prepare('SELECT id, phone, name, role, merchant_slug FROM users WHERE id = ?').get(req.userId);
  res.json(user);
});

app.get('/v1/merchants', auth, (req, res) => {
  const rows = db.prepare('SELECT * FROM merchants WHERE approved = 1 ORDER BY usage_count DESC').all();
  res.json({ merchants: rows });
});

app.get('/v1/merchants/:slug/menu', auth, (req, res) => {
  const m = db.prepare('SELECT * FROM merchants WHERE slug = ?').get(req.params.slug);
  if (!m) return res.status(404).json({ error: 'merchant not found' });
  const items = db.prepare('SELECT * FROM menu_items WHERE merchant_id = ?').all(m.id);
  res.json({ merchant: m, items });
});

app.get('/v1/orders', auth, (req, res) => {
  const rows = db.prepare('SELECT * FROM orders WHERE user_id = ? ORDER BY placed_at DESC').all(req.userId);
  res.json({ orders: rows });
});

app.post('/v1/orders', auth, (req, res) => {
  const body = req.body || {};
  const id = `ord-${Date.now()}`;
  const placedAt = new Date().toISOString();
  db.prepare(
    `INSERT INTO orders (id, user_id, merchant_slug, placed_at, total_baht, pickup_mode, status, lines_json, breakdown_json) VALUES (?,?,?,?,?,?,?,?,?)`,
  ).run(
    id,
    req.userId,
    String(body.merchant_slug || ''),
    placedAt,
    Number(body.total_baht || 0),
    body.pickup_mode ? 1 : 0,
    String(body.status || 'กำลังจัดส่ง'),
    JSON.stringify(body.lines || []),
    JSON.stringify(body.breakdown || {}),
  );
  const row = db.prepare('SELECT * FROM orders WHERE id = ?').get(id);
  res.status(201).json(row);
});

app.post('/v1/orders/:id/complete', auth, (req, res) => {
  db.prepare('UPDATE orders SET status = ? WHERE id = ? AND user_id = ?').run('สำเร็จ', req.params.id, req.userId);
  res.json({ ok: true });
});

app.get('/v1/addresses', auth, (req, res) => {
  const rows = db.prepare('SELECT * FROM addresses WHERE user_id = ?').all(req.userId);
  res.json({ addresses: rows });
});

app.post('/v1/addresses', auth, (req, res) => {
  const id = crypto.randomUUID();
  const { label, detail } = req.body || {};
  db.prepare('INSERT INTO addresses (id, user_id, label, detail) VALUES (?,?,?,?)').run(id, req.userId, String(label || ''), String(detail || ''));
  const row = db.prepare('SELECT * FROM addresses WHERE id = ?').get(id);
  res.status(201).json(row);
});

app.get('/v1/wallet', auth, (req, res) => {
  res.json({ balance_baht: 500.8, points: 3800 });
});

app.get('/v1/wallet/ledger', auth, (req, res) => {
  const rows = db.prepare('SELECT * FROM wallet_ledger WHERE user_id = ? ORDER BY created_at DESC').all(req.userId);
  res.json({ entries: rows });
});

app.post('/v1/payments/intents', auth, (req, res) => {
  const id = `pi-${Date.now()}`;
  const amount = Number((req.body || {}).amount_baht || 0);
  db.prepare('INSERT INTO payment_intents (id, user_id, amount_baht, status, order_id) VALUES (?,?,?,?,?)').run(
    id,
    req.userId,
    amount,
    'requires_confirmation',
    (req.body || {}).order_id || null,
  );
  res.status(201).json({ id, status: 'requires_confirmation', amount_baht: amount });
});

app.post('/v1/payments/:id/confirm-mock', auth, (req, res) => {
  db.prepare('UPDATE payment_intents SET status = ? WHERE id = ? AND user_id = ?').run('succeeded', req.params.id, req.userId);
  res.json({ ok: true });
});

app.get('/v1/maps/geocode', auth, (req, res) => {
  const q = String(req.query.q || 'Bangkok');
  res.json({ label: `${q} · สาธิต`, lat: 13.7563, lng: 100.5018 });
});

app.post('/v1/notifications/device', auth, (req, res) => {
  const t = String((req.body || {}).token || '');
  db.prepare('INSERT OR REPLACE INTO device_tokens (token, user_id) VALUES (?, ?)').run(t, req.userId);
  res.json({ ok: true });
});

app.get('/v1/admin/users', auth, requireRole('admin'), (req, res) => {
  const rows = db.prepare('SELECT id, phone, name, role, merchant_slug FROM users ORDER BY role, phone').all();
  res.json({ users: rows });
});

app.patch('/v1/admin/users/:id', auth, requireRole('admin'), (req, res) => {
  const targetId = req.params.id;
  if (targetId === req.userId) {
    return res.status(400).json({ error: 'ไม่สามารถเปลี่ยนบทบาทบัญชีที่กำลังล็อกอินอยู่' });
  }
  const body = req.body || {};
  const allowedRoles = new Set(['customer', 'merchant_applicant', 'merchant', 'admin']);
  if (body.role != null) {
    const r = String(body.role);
    if (!allowedRoles.has(r)) return res.status(400).json({ error: 'invalid role' });
    db.prepare('UPDATE users SET role = ? WHERE id = ?').run(r, targetId);
    if (r !== 'merchant') {
      db.prepare('UPDATE users SET merchant_slug = NULL WHERE id = ?').run(targetId);
    }
  }
  if (body.name != null && String(body.name).trim()) {
    db.prepare('UPDATE users SET name = ? WHERE id = ?').run(String(body.name).trim(), targetId);
  }
  const row = db.prepare('SELECT id, phone, name, role, merchant_slug FROM users WHERE id = ?').get(targetId);
  if (!row) return res.status(404).json({ error: 'user not found' });
  res.json(row);
});

app.post('/v1/admin/merchants/:id/approve', auth, requireRole('admin'), (req, res) => {
  const m = db.prepare('SELECT id, approved FROM merchants WHERE id = ?').get(req.params.id);
  if (!m) return res.status(404).json({ error: 'merchant not found' });
  if (m.approved === 1) return res.json({ ok: true });
  db.prepare('UPDATE merchants SET approved = 1 WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

app.get('/v1/admin/pending-merchants', auth, requireRole('admin'), (req, res) => {
  const rows = db.prepare('SELECT * FROM merchants WHERE approved = 0').all();
  res.json({ merchants: rows });
});

app.get('/v1/admin/merchant-applications', auth, requireRole('admin'), (req, res) => {
  const rows = db
    .prepare(
      `SELECT a.*, u.phone AS applicant_phone, u.name AS applicant_name
       FROM merchant_applications a
       JOIN users u ON u.id = a.user_id
       WHERE a.status = 'pending'
       ORDER BY datetime(a.created_at) DESC`,
    )
    .all();
  res.json({ applications: rows });
});

app.post('/v1/admin/merchant-applications/:id/approve', auth, requireRole('admin'), (req, res) => {
  const appRow = db.prepare('SELECT * FROM merchant_applications WHERE id = ?').get(req.params.id);
  if (!appRow || appRow.status !== 'pending') {
    return res.status(404).json({ error: 'application not found' });
  }
  const slug = appRow.proposed_slug;
  const exists = db.prepare('SELECT id FROM merchants WHERE slug = ?').get(slug);
  if (exists) {
    return res.status(409).json({ error: 'slug already exists' });
  }
  const mid = crypto.randomUUID();
  const imageUrl = 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=1200&q=80';
  db.prepare(
    `INSERT INTO merchants (id, slug, name, category, eta_minutes, rating, usage_count, image_url, distance_km, delivery_fee, approved)
     VALUES (?,?,?,?,?,?,?,?,?,?,1)`,
  ).run(mid, slug, appRow.shop_name, appRow.category, 20, 4.5, 0, imageUrl, 2.0, 20);
  const menuId = crypto.randomUUID();
  db.prepare(
    `INSERT INTO menu_items (id, merchant_id, name, price, description, image_url, menu_section) VALUES (?,?,?,?,?,?,?)`,
  ).run(
    menuId,
    mid,
    'เมนูตัวอย่าง (แก้ในระบบหลังบ้าน)',
    1,
    'ลูกค้าสั่งผ่าน slug เดียวกับร้านในแอปสั่งอาหาร',
    imageUrl,
    'อื่นๆ',
  );
  db.prepare(`UPDATE merchant_applications SET status = 'approved' WHERE id = ?`).run(appRow.id);
  db.prepare(`UPDATE users SET role = 'merchant', merchant_slug = ? WHERE id = ?`).run(slug, appRow.user_id);
  res.json({ ok: true, merchant_slug: slug });
});

app.post('/v1/admin/merchant-applications/:id/reject', auth, requireRole('admin'), (req, res) => {
  const appRow = db.prepare('SELECT * FROM merchant_applications WHERE id = ?').get(req.params.id);
  if (!appRow || appRow.status !== 'pending') {
    return res.status(404).json({ error: 'application not found' });
  }
  db.prepare(`UPDATE merchant_applications SET status = 'rejected' WHERE id = ?`).run(appRow.id);
  db.prepare(`UPDATE users SET role = 'customer' WHERE id = ? AND role = 'merchant_applicant'`).run(appRow.user_id);
  res.json({ ok: true });
});

app.post('/v1/merchant/applications', auth, (req, res) => {
  const u = db.prepare('SELECT id, role FROM users WHERE id = ?').get(req.userId);
  if (!u) return res.status(401).json({ error: 'no user' });
  if (u.role !== 'customer') {
    return res.status(403).json({ error: 'only customers can submit a new application' });
  }
  const pend = db
    .prepare(`SELECT id FROM merchant_applications WHERE user_id = ? AND status = 'pending'`)
    .get(req.userId);
  if (pend) return res.status(409).json({ error: 'application already pending' });
  const body = req.body || {};
  const shopName = String(body.shop_name || '').trim();
  const category = String(body.category || '').trim();
  let proposedSlug = String(body.proposed_slug || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
  const notes = String(body.notes || '').trim();
  if (!shopName || !category || !proposedSlug) {
    return res.status(400).json({ error: 'shop_name, category, proposed_slug required' });
  }
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(proposedSlug)) {
    return res.status(400).json({ error: 'invalid proposed_slug (use a-z 0-9 hyphen only)' });
  }
  if (db.prepare('SELECT id FROM merchants WHERE slug = ?').get(proposedSlug)) {
    return res.status(409).json({ error: 'slug already used by a merchant' });
  }
  if (
    db.prepare(`SELECT id FROM merchant_applications WHERE proposed_slug = ? AND status = 'pending'`).get(proposedSlug)
  ) {
    return res.status(409).json({ error: 'slug reserved by another pending application' });
  }
  const id = crypto.randomUUID();
  const created = new Date().toISOString();
  db.prepare(
    `INSERT INTO merchant_applications (id, user_id, shop_name, category, proposed_slug, notes, status, created_at)
     VALUES (?,?,?,?,?,?, 'pending', ?)`,
  ).run(id, req.userId, shopName, category, proposedSlug, notes, created);
  db.prepare(`UPDATE users SET role = 'merchant_applicant' WHERE id = ?`).run(req.userId);
  const row = db.prepare('SELECT * FROM merchant_applications WHERE id = ?').get(id);
  res.status(201).json({ application: row });
});

app.get('/v1/merchant/my-application', auth, (req, res) => {
  const row = db
    .prepare(`SELECT * FROM merchant_applications WHERE user_id = ? ORDER BY datetime(created_at) DESC LIMIT 1`)
    .get(req.userId);
  res.json({ application: row || null });
});

app.get('/v1/merchant/orders', auth, requireRole('merchant'), (req, res) => {
  const u = db.prepare('SELECT merchant_slug FROM users WHERE id = ?').get(req.userId);
  const slug = u?.merchant_slug;
  let rows;
  if (slug) {
    rows = db
      .prepare('SELECT * FROM orders WHERE merchant_slug = ? ORDER BY placed_at DESC LIMIT 50')
      .all(slug);
  } else {
    rows = db.prepare('SELECT * FROM orders ORDER BY placed_at DESC LIMIT 50').all();
  }
  res.json({ orders: rows });
});

app.get('/v1/merchant/my-menu', auth, requireRole('merchant'), (req, res) => {
  const merchant = merchantRecordForUser(req.userId);
  if (!merchant) {
    return res.status(404).json({ error: 'ยังไม่มีร้านผูกกับบัญชี' });
  }
  const items = db.prepare('SELECT * FROM menu_items WHERE merchant_id = ? ORDER BY menu_section, name').all(merchant.id);
  res.json({ merchant, items });
});

app.post('/v1/merchant/menu-items', auth, requireRole('merchant'), (req, res) => {
  const merchant = merchantRecordForUser(req.userId);
  if (!merchant) {
    return res.status(404).json({ error: 'ยังไม่มีร้านผูกกับบัญชี' });
  }
  const body = req.body || {};
  const name = String(body.name || '').trim();
  const price = Number(body.price);
  let menuSection = String(body.menu_section || 'อื่นๆ').trim();
  if (!menuSection) menuSection = 'อื่นๆ';
  const description = String(body.description ?? '').trim();
  const imageUrlRaw = body.image_url;
  const imageUrl =
    imageUrlRaw == null || imageUrlRaw === '' ? null : String(imageUrlRaw);
  if (!name) {
    return res.status(400).json({ error: 'ต้องระบุชื่อเมนู' });
  }
  if (!Number.isFinite(price) || price < 0) {
    return res.status(400).json({ error: 'ราคาไม่ถูกต้อง' });
  }
  if (imageUrl != null && imageUrl.length > 4_000_000) {
    return res.status(400).json({ error: 'รูปใหญ่เกินไป ลองเลือกรูปที่เล็กลง' });
  }
  const id = crypto.randomUUID();
  db.prepare(
    `INSERT INTO menu_items (id, merchant_id, name, price, description, image_url, menu_section) VALUES (?,?,?,?,?,?,?)`,
  ).run(id, merchant.id, name, Math.round(price), description, imageUrl, menuSection);
  const row = db.prepare('SELECT * FROM menu_items WHERE id = ?').get(id);
  res.status(201).json(row);
});

app.patch('/v1/merchant/menu-items/:id', auth, requireRole('merchant'), (req, res) => {
  const merchant = merchantRecordForUser(req.userId);
  if (!merchant) {
    return res.status(404).json({ error: 'ยังไม่มีร้านผูกกับบัญชี' });
  }
  const row = db.prepare('SELECT * FROM menu_items WHERE id = ?').get(req.params.id);
  if (!row || row.merchant_id !== merchant.id) {
    return res.status(404).json({ error: 'ไม่พบเมนู' });
  }
  const body = req.body || {};
  const name = body.name != null ? String(body.name).trim() : row.name;
  const price = body.price != null ? Number(body.price) : row.price;
  let menuSection = body.menu_section != null ? String(body.menu_section).trim() : row.menu_section;
  if (!menuSection) menuSection = 'อื่นๆ';
  const description = body.description != null ? String(body.description).trim() : row.description;
  let imageUrl = row.image_url;
  if (Object.prototype.hasOwnProperty.call(body, 'image_url')) {
    const v = body.image_url;
    imageUrl = v == null || v === '' ? null : String(v);
  }
  if (!name) {
    return res.status(400).json({ error: 'ต้องระบุชื่อเมนู' });
  }
  if (!Number.isFinite(price) || price < 0) {
    return res.status(400).json({ error: 'ราคาไม่ถูกต้อง' });
  }
  if (imageUrl != null && imageUrl.length > 4_000_000) {
    return res.status(400).json({ error: 'รูปใหญ่เกินไป ลองเลือกรูปที่เล็กลง' });
  }
  db.prepare(
    `UPDATE menu_items SET name = ?, price = ?, description = ?, image_url = ?, menu_section = ? WHERE id = ? AND merchant_id = ?`,
  ).run(name, Math.round(price), description, imageUrl, menuSection, req.params.id, merchant.id);
  const next = db.prepare('SELECT * FROM menu_items WHERE id = ?').get(req.params.id);
  res.json(next);
});

app.delete('/v1/merchant/menu-items/:id', auth, requireRole('merchant'), (req, res) => {
  const merchant = merchantRecordForUser(req.userId);
  if (!merchant) {
    return res.status(404).json({ error: 'ยังไม่มีร้านผูกกับบัญชี' });
  }
  const row = db.prepare('SELECT * FROM menu_items WHERE id = ?').get(req.params.id);
  if (!row || row.merchant_id !== merchant.id) {
    return res.status(404).json({ error: 'ไม่พบเมนู' });
  }
  db.prepare('DELETE FROM menu_items WHERE id = ? AND merchant_id = ?').run(req.params.id, merchant.id);
  res.json({ ok: true });
});

// เสิร์ฟ Flutter Web จาก public/ หรือ ../build/web (โหมด Cloudways Node)
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
    app.use(express.static(webRoot, {
      index: 'index.html',
      maxAge: '1y',
      setHeaders(res, filePath) {
        const base = path.basename(filePath);
        if (
          base === 'index.html' ||
          base === 'flutter_service_worker.js' ||
          base === 'flutter_bootstrap.js' ||
          base === 'manifest.json'
        ) {
          res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        }
      },
    }));
    // SPA fallback — อย่ากลืนเส้นทาง API
    app.use((req, res, next) => {
      if (req.method !== 'GET' && req.method !== 'HEAD') return next();
      if (req.path.startsWith('/v1/') || req.path === '/health') return next();
      res.sendFile(path.join(webRoot, 'index.html'), (err) => {
        if (err) next();
      });
    });
  }
}

const port = Number(process.env.PORT || 8787);
const host = process.env.HOST || '0.0.0.0';
app.listen(port, host, () => {
  console.log(`Infinity API http://${host}:${port}`);
  if (webRoot) {
    console.log(`Serving Flutter web from ${webRoot}`);
  } else if (serveWeb) {
    console.log('SERVE_WEB=true แต่ยังไม่พบ build/web หรือ server/public — เสิร์ฟเฉพาะ API');
  }
  console.log('ผู้ดูแลระบบ (OTP 6 หลักใดก็ได้): เบอร์ 0810000000 หรือ 0888888888');
});
