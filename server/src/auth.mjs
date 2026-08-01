import crypto from 'crypto';
import { db } from './db.mjs';

function hashCode(code) {
  return crypto.createHash('sha256').update(String(code)).digest('hex');
}

function normalizePhone(phone) {
  let p = String(phone || '').replace(/\D/g, '');
  if (p.startsWith('66') && p.length >= 11) p = `0${p.slice(2)}`;
  return p;
}

export async function createSession(userId) {
  const token = crypto.randomBytes(24).toString('hex');
  await db.run('INSERT INTO sessions (token, user_id) VALUES (?, ?)', [token, userId]);
  return token;
}

export async function userPublic(userId) {
  return db.one(
    'SELECT id, phone, email, name, role, merchant_slug, wallet_balance_baht, points FROM users WHERE id = ?',
    [userId],
  );
}

export async function findOrCreatePhoneUser(phone, name = 'สมาชิก Infinity') {
  const p = normalizePhone(phone);
  let user = await db.one('SELECT * FROM users WHERE phone = ?', [p]);
  if (!user) {
    const id = crypto.randomUUID();
    await db.run(
      'INSERT INTO users (id, phone, name, role, wallet_balance_baht, points) VALUES (?,?,?,?,0,0)',
      [id, p, name, 'customer'],
    );
    user = await db.one('SELECT * FROM users WHERE id = ?', [id]);
  }
  return user;
}

async function sendSms(phone, message) {
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_FROM_NUMBER;
  if (!sid || !token || !from) {
    console.log(`[otp] SMS provider not configured. Message for ${phone}: ${message}`);
    return { ok: true, logged: true, sms_sent: false };
  }
  const to = phone.startsWith('0') ? `+66${phone.slice(1)}` : phone;
  const auth = Buffer.from(`${sid}:${token}`).toString('base64');
  const body = new URLSearchParams({ To: to, From: from, Body: message });
  const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  if (!res.ok) {
    const text = await res.text();
    const err = new Error(`ส่ง SMS ไม่สำเร็จ: ${text}`);
    err.status = 502;
    throw err;
  }
  return { ok: true, sms_sent: true };
}

function allowDevOtp() {
  // เปิดเมื่อยังไม่มี Twilio — ให้ทดสอบล็อกอินได้จนกว่าจะตั้ง SMS จริง
  // ปิดด้วย ALLOW_DEV_OTP=false เมื่อขึ้น production มี Twilio แล้ว
  if (process.env.ALLOW_DEV_OTP === 'false') return false;
  if (process.env.ALLOW_DEV_OTP === 'true') return true;
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_FROM_NUMBER;
  return !(sid && token && from);
}

export async function requestOtp(phoneRaw) {
  const phone = normalizePhone(phoneRaw);
  if (!/^\d{9,15}$/.test(phone)) {
    const err = new Error('เบอร์โทรไม่ถูกต้อง');
    err.status = 400;
    throw err;
  }
  const code = String(Math.floor(100000 + Math.random() * 900000));
  const id = crypto.randomUUID();
  const expires = new Date(Date.now() + 10 * 60 * 1000).toISOString();
  await db.run('DELETE FROM otp_challenges WHERE phone = ?', [phone]);
  await db.run(
    'INSERT INTO otp_challenges (id, phone, code_hash, expires_at, attempts) VALUES (?,?,?,?,0)',
    [id, phone, hashCode(code), expires],
  );
  const sms = await sendSms(phone, `รหัสยืนยัน Infinity ของคุณคือ ${code} (หมดอายุใน 10 นาที)`);
  const out = {
    ok: true,
    challenge_id: id,
    expires_at: expires,
    sms_sent: sms.sms_sent === true,
  };
  if (allowDevOtp() && !out.sms_sent) {
    out.dev_code = code;
    out.dev_hint = 'ยังไม่ได้ตั้ง Twilio — ใช้รหัสนี้ชั่วคราว';
  }
  return out;
}

export async function verifyOtp(phoneRaw, code) {
  const phone = normalizePhone(phoneRaw);
  if (!/^\d{6}$/.test(String(code || ''))) {
    const err = new Error('รหัสยืนยันไม่ถูกต้อง');
    err.status = 400;
    throw err;
  }
  const row = await db.one(
    'SELECT * FROM otp_challenges WHERE phone = ? ORDER BY expires_at DESC',
    [phone],
  );
  if (!row) {
    const err = new Error('ยังไม่ได้ขอรหัส หรือรหัสหมดอายุแล้ว');
    err.status = 400;
    throw err;
  }
  if (new Date(row.expires_at).getTime() < Date.now()) {
    await db.run('DELETE FROM otp_challenges WHERE id = ?', [row.id]);
    const err = new Error('รหัสหมดอายุแล้ว กรุณาขอใหม่');
    err.status = 400;
    throw err;
  }
  if (Number(row.attempts) >= 5) {
    const err = new Error('ลองผิดหลายครั้งเกินไป กรุณาขอรหัสใหม่');
    err.status = 429;
    throw err;
  }
  if (row.code_hash !== hashCode(code)) {
    await db.run('UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = ?', [row.id]);
    const err = new Error('รหัสยืนยันไม่ถูกต้อง');
    err.status = 400;
    throw err;
  }
  await db.run('DELETE FROM otp_challenges WHERE phone = ?', [phone]);
  const user = await findOrCreatePhoneUser(phone);
  const token = await createSession(user.id);
  return { token, user: await userPublic(user.id) };
}

let firebaseApp = null;

async function getFirebaseAuth() {
  if (firebaseApp) return firebaseApp.auth();
  const raw = (process.env.FIREBASE_SERVICE_ACCOUNT || '').trim();
  if (!raw) return null;
  const admin = await import('firebase-admin');
  const cred = JSON.parse(raw);
  firebaseApp = admin.default.initializeApp({
    credential: admin.default.credential.cert(cred),
  });
  return firebaseApp.auth();
}

export async function verifyFirebaseIdToken(idToken) {
  const auth = await getFirebaseAuth();
  if (!auth) {
    const err = new Error('ยังไม่ได้ตั้งค่า FIREBASE_SERVICE_ACCOUNT');
    err.status = 503;
    throw err;
  }
  const decoded = await auth.verifyIdToken(idToken);
  const phone = normalizePhone(decoded.phone_number || '');
  if (!phone) {
    const err = new Error('โทเค็น Firebase ไม่มีเบอร์โทร');
    err.status = 400;
    throw err;
  }
  const user = await findOrCreatePhoneUser(phone, decoded.name || 'สมาชิก Infinity');
  const token = await createSession(user.id);
  return { token, user: await userPublic(user.id) };
}

/** ผู้ให้บริการที่ตั้งค่า OAuth ฝั่งเซิร์ฟเวอร์ครบแล้ว */
export function socialProviderStatus() {
  const has = (id, secret) =>
    Boolean((process.env[id] || '').trim() && (process.env[secret] || '').trim());
  return {
    google: has('GOOGLE_OAUTH_CLIENT_ID', 'GOOGLE_OAUTH_CLIENT_SECRET'),
    facebook: has('FACEBOOK_APP_ID', 'FACEBOOK_APP_SECRET'),
    line: has('LINE_CHANNEL_ID', 'LINE_CHANNEL_SECRET'),
  };
}

/** สร้าง/ผูกบัญชีจากโปรไฟล์โซเชียล แล้วออก session */
export async function upsertSocialUser({ provider, providerUid, email, name }) {
  const p = String(provider || '').toLowerCase();
  if (!providerUid) {
    const err = new Error('ไม่ได้รับรหัสผู้ใช้จากผู้ให้บริการ');
    err.status = 401;
    throw err;
  }
  const displayName = name || 'สมาชิก Infinity';
  let user = await db.one(
    'SELECT * FROM users WHERE auth_provider = ? AND provider_uid = ?',
    [p, providerUid],
  );
  if (!user && email) {
    user = await db.one('SELECT * FROM users WHERE email = ?', [email]);
  }
  if (!user) {
    const id = crypto.randomUUID();
    await db.run(
      `INSERT INTO users (id, phone, email, name, role, auth_provider, provider_uid, wallet_balance_baht, points)
       VALUES (?,?,?,?,?,?,?,0,0)`,
      [id, null, email, displayName, 'customer', p, providerUid],
    );
    user = await db.one('SELECT * FROM users WHERE id = ?', [id]);
  } else {
    await db.run(
      'UPDATE users SET auth_provider = ?, provider_uid = ?, email = COALESCE(email, ?), name = ? WHERE id = ?',
      [p, providerUid, email, displayName, user.id],
    );
  }
  const token = await createSession(user.id);
  return { token, user: await userPublic(user.id) };
}

export async function loginWithSocial({ provider, idToken, accessToken }) {
  const p = String(provider || '').toLowerCase();
  let email = null;
  let name = 'สมาชิก Infinity';
  let providerUid = null;

  if (!idToken && !accessToken) {
    const configured = socialProviderStatus()[p];
    const err = new Error(
      configured
        ? `เปิดหน้าเข้าสู่ระบบ ${p} ไม่สำเร็จ กรุณาลองใหม่`
        : `ยังไม่ได้ตั้งค่าการเข้าสู่ระบบด้วย ${p} บนเซิร์ฟเวอร์`,
    );
    err.status = configured ? 400 : 501;
    throw err;
  }

  if (p === 'google') {
    if (idToken) {
      const res = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`);
      if (!res.ok) {
        const err = new Error('ยืนยัน Google token ไม่สำเร็จ');
        err.status = 401;
        throw err;
      }
      const data = await res.json();
      email = data.email || null;
      name = data.name || name;
      providerUid = data.sub;
    } else if (accessToken) {
      const res = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (!res.ok) {
        const err = new Error('ยืนยัน Google access token ไม่สำเร็จ');
        err.status = 401;
        throw err;
      }
      const data = await res.json();
      email = data.email || null;
      name = data.name || name;
      providerUid = data.sub;
    } else {
      const err = new Error('ต้องส่ง id_token หรือ access_token ของ Google');
      err.status = 400;
      throw err;
    }
  } else if (p === 'line') {
    if (!idToken && !accessToken) {
      const err = new Error('ต้องส่ง id_token หรือ access_token ของ LINE');
      err.status = 400;
      throw err;
    }
    if (idToken) {
      const channelId = process.env.LINE_CHANNEL_ID;
      const res = await fetch('https://api.line.me/oauth2/v2.1/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ id_token: idToken, client_id: channelId || '' }),
      });
      if (!res.ok) {
        const err = new Error('ยืนยัน LINE token ไม่สำเร็จ');
        err.status = 401;
        throw err;
      }
      const data = await res.json();
      email = data.email || null;
      name = data.name || name;
      providerUid = data.sub;
    } else {
      const res = await fetch('https://api.line.me/v2/profile', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (!res.ok) {
        const err = new Error('ยืนยัน LINE profile ไม่สำเร็จ');
        err.status = 401;
        throw err;
      }
      const data = await res.json();
      name = data.displayName || name;
      providerUid = data.userId;
    }
  } else if (p === 'facebook') {
    const token = accessToken || idToken;
    if (!token) {
      const err = new Error('ต้องส่ง access_token ของ Facebook');
      err.status = 400;
      throw err;
    }
    const res = await fetch(
      `https://graph.facebook.com/me?fields=id,name,email&access_token=${encodeURIComponent(token)}`,
    );
    if (!res.ok) {
      const err = new Error('ยืนยัน Facebook token ไม่สำเร็จ');
      err.status = 401;
      throw err;
    }
    const data = await res.json();
    email = data.email || null;
    name = data.name || name;
    providerUid = data.id;
  } else {
    const err = new Error('ผู้ให้บริการไม่รองรับ');
    err.status = 400;
    throw err;
  }

  return upsertSocialUser({ provider: p, providerUid, email, name });
}

export function authMiddleware(dbRef) {
  return async (req, res, next) => {
    try {
      const h = req.headers.authorization || '';
      const token = h.startsWith('Bearer ') ? h.slice(7) : null;
      if (!token) return res.status(401).json({ error: 'missing token' });
      const row = await dbRef.one('SELECT user_id FROM sessions WHERE token = ?', [token]);
      if (!row) return res.status(401).json({ error: 'invalid token' });
      req.userId = row.user_id;
      next();
    } catch (e) {
      next(e);
    }
  };
}

export function requireRole(role) {
  return async (req, res, next) => {
    try {
      const u = await db.one('SELECT role FROM users WHERE id = ?', [req.userId]);
      if (!u || u.role !== role) return res.status(403).json({ error: 'forbidden' });
      next();
    } catch (e) {
      next(e);
    }
  };
}
