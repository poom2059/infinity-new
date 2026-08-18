/**
 * Thin DB layer: Postgres when DATABASE_URL is set, else SQLite.
 */
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverRoot = path.join(__dirname, '..');

let driver = null;
let pool = null;
let sqlite = null;

export function dbDriver() {
  return driver;
}

function toPg(sql) {
  if (driver !== 'pg') return sql;
  let i = 0;
  return sql.replace(/\?/g, () => `$${++i}`);
}

async function rawExec(sql, params = []) {
  if (driver === 'pg') {
    await pool.query(toPg(sql), params);
    return;
  }
  sqlite.prepare(sql).run(...params);
}

async function rawAll(sql, params = []) {
  if (driver === 'pg') {
    const r = await pool.query(toPg(sql), params);
    return r.rows;
  }
  return sqlite.prepare(sql).all(...params);
}

async function rawOne(sql, params = []) {
  if (driver === 'pg') {
    const r = await pool.query(toPg(sql), params);
    return r.rows[0] || null;
  }
  return sqlite.prepare(sql).get(...params) || null;
}

async function rawRun(sql, params = []) {
  if (driver === 'pg') {
    const r = await pool.query(toPg(sql), params);
    return { changes: r.rowCount || 0 };
  }
  const info = sqlite.prepare(sql).run(...params);
  return { changes: info.changes };
}

export const db = {
  exec: rawExec,
  all: rawAll,
  one: rawOne,
  run: rawRun,
};

export async function initDb() {
  const databaseUrl = (process.env.DATABASE_URL || '').trim();
  if (databaseUrl) {
    const pg = await import('pg');
    pool = new pg.default.Pool({
      connectionString: databaseUrl,
      ssl: process.env.PGSSL === 'false' ? false : { rejectUnauthorized: false },
    });
    driver = 'pg';
    await migratePg();
  } else {
    const Database = (await import('better-sqlite3')).default;
    const dataDir = path.join(serverRoot, 'data');
    if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
    const dbPath = process.env.DB_PATH
      ? path.resolve(process.env.DB_PATH)
      : path.join(dataDir, 'infinity.sqlite');
    sqlite = new Database(dbPath);
    sqlite.pragma('journal_mode = WAL');
    driver = 'sqlite';
    migrateSqlite();
  }
  await seedIfEmpty();
  await ensureAdminsFromEnv();
}

function migrateSqlite() {
  sqlite.exec(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  phone TEXT UNIQUE,
  email TEXT,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'customer',
  merchant_slug TEXT,
  auth_provider TEXT,
  provider_uid TEXT,
  wallet_balance_baht REAL NOT NULL DEFAULT 0,
  points INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS otp_challenges (
  id TEXT PRIMARY KEY,
  phone TEXT NOT NULL,
  code_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0
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
  menu_section TEXT NOT NULL DEFAULT 'อื่นๆ'
);
CREATE TABLE IF NOT EXISTS addresses (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  label TEXT NOT NULL,
  detail TEXT NOT NULL
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
  payment_intent_id TEXT
);
CREATE TABLE IF NOT EXISTS wallet_ledger (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  amount_baht REAL NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS payment_intents (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  amount_baht INTEGER NOT NULL,
  status TEXT NOT NULL,
  order_id TEXT,
  purpose TEXT NOT NULL DEFAULT 'order',
  omise_charge_id TEXT,
  omise_source_id TEXT,
  qr_image_url TEXT,
  meta_json TEXT
);
CREATE TABLE IF NOT EXISTS device_tokens (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS merchant_applications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  shop_name TEXT NOT NULL,
  category TEXT NOT NULL,
  proposed_slug TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY,
  poster_id TEXT NOT NULL,
  title TEXT NOT NULL,
  profession TEXT NOT NULL,
  description TEXT NOT NULL,
  total_baht INTEGER NOT NULL,
  age_min INTEGER NOT NULL,
  age_max INTEGER NOT NULL,
  work_time_label TEXT NOT NULL,
  store_phone TEXT NOT NULL,
  store_address TEXT NOT NULL,
  contact_phone TEXT NOT NULL DEFAULT '',
  worker_gender TEXT NOT NULL DEFAULT 'any',
  status TEXT NOT NULL DEFAULT 'open',
  chosen_applicant_id TEXT,
  escrow_intent_id TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS job_applicants (
  id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  applied_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS job_messages (
  id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  sender_label TEXT NOT NULL,
  text TEXT NOT NULL,
  sent_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS bookings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'system',
  created_at TEXT NOT NULL,
  read INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS saved_places (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  label TEXT NOT NULL,
  detail TEXT NOT NULL,
  lat REAL,
  lng REAL
);
`);
  const userCols = sqlite.prepare('PRAGMA table_info(users)').all().map((c) => c.name);
  for (const [col, ddl] of [
    ['merchant_slug', 'ALTER TABLE users ADD COLUMN merchant_slug TEXT'],
    ['email', 'ALTER TABLE users ADD COLUMN email TEXT'],
    ['auth_provider', 'ALTER TABLE users ADD COLUMN auth_provider TEXT'],
    ['provider_uid', 'ALTER TABLE users ADD COLUMN provider_uid TEXT'],
    ['wallet_balance_baht', 'ALTER TABLE users ADD COLUMN wallet_balance_baht REAL NOT NULL DEFAULT 0'],
    ['points', 'ALTER TABLE users ADD COLUMN points INTEGER NOT NULL DEFAULT 0'],
    ['avatar_url', 'ALTER TABLE users ADD COLUMN avatar_url TEXT'],
    ['avatar_frame', "ALTER TABLE users ADD COLUMN avatar_frame TEXT NOT NULL DEFAULT 'none'"],
  ]) {
    if (!userCols.includes(col)) sqlite.exec(ddl);
  }
  const menuCols = sqlite.prepare('PRAGMA table_info(menu_items)').all().map((c) => c.name);
  if (!menuCols.includes('menu_section')) {
    sqlite.exec(`ALTER TABLE menu_items ADD COLUMN menu_section TEXT NOT NULL DEFAULT 'อื่นๆ'`);
  }
}

async function migratePg() {
  await pool.query(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  phone TEXT UNIQUE,
  email TEXT,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'customer',
  merchant_slug TEXT,
  auth_provider TEXT,
  provider_uid TEXT,
  wallet_balance_baht DOUBLE PRECISION NOT NULL DEFAULT 0,
  points INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS sessions (token TEXT PRIMARY KEY, user_id TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS otp_challenges (
  id TEXT PRIMARY KEY, phone TEXT NOT NULL, code_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL, attempts INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS merchants (
  id TEXT PRIMARY KEY, slug TEXT UNIQUE NOT NULL, name TEXT NOT NULL, category TEXT NOT NULL,
  eta_minutes INTEGER NOT NULL, rating DOUBLE PRECISION NOT NULL, usage_count INTEGER NOT NULL,
  image_url TEXT NOT NULL, distance_km DOUBLE PRECISION NOT NULL, delivery_fee INTEGER NOT NULL,
  approved INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS menu_items (
  id TEXT PRIMARY KEY, merchant_id TEXT NOT NULL, name TEXT NOT NULL, price INTEGER NOT NULL,
  description TEXT, image_url TEXT, menu_section TEXT NOT NULL DEFAULT 'อื่นๆ'
);
CREATE TABLE IF NOT EXISTS addresses (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, label TEXT NOT NULL, detail TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, merchant_slug TEXT NOT NULL, placed_at TIMESTAMPTZ NOT NULL,
  total_baht INTEGER NOT NULL, pickup_mode INTEGER NOT NULL, status TEXT NOT NULL,
  lines_json TEXT NOT NULL, breakdown_json TEXT NOT NULL, payment_intent_id TEXT
);
CREATE TABLE IF NOT EXISTS wallet_ledger (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, title TEXT NOT NULL,
  amount_baht DOUBLE PRECISION NOT NULL, created_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS payment_intents (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, amount_baht INTEGER NOT NULL, status TEXT NOT NULL,
  order_id TEXT, purpose TEXT NOT NULL DEFAULT 'order', omise_charge_id TEXT,
  omise_source_id TEXT, qr_image_url TEXT, meta_json TEXT
);
CREATE TABLE IF NOT EXISTS device_tokens (token TEXT PRIMARY KEY, user_id TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS merchant_applications (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, shop_name TEXT NOT NULL, category TEXT NOT NULL,
  proposed_slug TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY, poster_id TEXT NOT NULL, title TEXT NOT NULL, profession TEXT NOT NULL,
  description TEXT NOT NULL, total_baht INTEGER NOT NULL, age_min INTEGER NOT NULL, age_max INTEGER NOT NULL,
  work_time_label TEXT NOT NULL, store_phone TEXT NOT NULL, store_address TEXT NOT NULL,
  contact_phone TEXT NOT NULL DEFAULT '', worker_gender TEXT NOT NULL DEFAULT 'any',
  status TEXT NOT NULL DEFAULT 'open', chosen_applicant_id TEXT, escrow_intent_id TEXT,
  created_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS job_applicants (
  id TEXT PRIMARY KEY, job_id TEXT NOT NULL, user_id TEXT NOT NULL,
  display_name TEXT NOT NULL, applied_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS job_messages (
  id TEXT PRIMARY KEY, job_id TEXT NOT NULL, sender_id TEXT NOT NULL,
  sender_label TEXT NOT NULL, text TEXT NOT NULL, sent_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS bookings (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, kind TEXT NOT NULL,
  payload_json TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', created_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'system', created_at TIMESTAMPTZ NOT NULL, read INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS saved_places (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL, label TEXT NOT NULL, detail TEXT NOT NULL,
  lat DOUBLE PRECISION, lng DOUBLE PRECISION
);
`);
  await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT`);
  await pool.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_frame TEXT DEFAULT 'none'`);
}

async function seedIfEmpty() {
  const row = await db.one('SELECT COUNT(*) AS c FROM merchants');
  const c = Number(row?.c ?? 0);
  if (c > 0) return;
  const merchants = [
    ['m1', 'infinity-chicken', 'ไก่ทอดอินฟินิตี้', 'ไก่ทอด', 15, 4.8, 1520, 'https://images.unsplash.com/photo-1562967914-608f82629710?w=1200&q=80', 1.3, 0],
    ['m2', 'daeng-noodle', 'แดงด่วนก๋วยเตี๋ยว', 'ก๋วยเตี๋ยว', 20, 4.7, 1380, 'https://images.unsplash.com/photo-1555126634-323283e090fa?w=1200&q=80', 2.4, 15],
    ['m3', 'white-bowl-salad', 'สลัดโบว์ขาว', 'สุขภาพ', 18, 4.6, 1240, 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200&q=80', 3.2, 20],
    ['m4', 'sushi-infinity', 'ซูชิอินฟินิตี้', 'ญี่ปุ่น', 25, 4.9, 1190, 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=1200&q=80', 4.9, 35],
    ['m5', 'tum-saeb', 'ตำแซ่บโคตรนัว', 'อีสาน', 22, 4.5, 980, 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=1200&q=80', 2.7, 20],
    ['m6', 'burger-lab', 'เบอร์เกอร์แล็บ', 'เบอร์เกอร์', 19, 4.6, 870, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1200&q=80', 5.5, 45],
  ];
  for (const r of merchants) {
    await db.run(
      `INSERT INTO merchants (id, slug, name, category, eta_minutes, rating, usage_count, image_url, distance_km, delivery_fee, approved)
       VALUES (?,?,?,?,?,?,?,?,?,?,1)`,
      r,
    );
  }
  const items = [
    ['i1', 'm1', 'ไก่ทอดซอสเกาหลี', 85, 'สะโพกไก่ทอดกรอบ', 'https://images.unsplash.com/photo-1562967914-608f82629710?w=1200&q=80', 'อาหารและเครื่องดื่ม'],
    ['i2', 'm1', 'ไก่เผ็ดดับเบิลชีส', 95, 'ไก่ทอดรสเผ็ด', 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=1200&q=80', 'อาหารและเครื่องดื่ม'],
    ['i3', 'm4', 'ข้าวหน้าปลาแซลมอน', 165, 'ปลาแซลมอนสด', 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=1200&q=80', 'อาหารและเครื่องดื่ม'],
  ];
  for (const r of items) {
    await db.run(
      `INSERT INTO menu_items (id, merchant_id, name, price, description, image_url, menu_section) VALUES (?,?,?,?,?,?,?)`,
      r,
    );
  }
}

async function ensureAdminsFromEnv() {
  const raw = (process.env.ADMIN_PHONES || '').trim();
  if (!raw) return;
  for (const phone of raw.split(',').map((s) => s.trim()).filter(Boolean)) {
    const existing = await db.one('SELECT id FROM users WHERE phone = ?', [phone]);
    if (!existing) {
      await db.run(
        'INSERT INTO users (id, phone, name, role, wallet_balance_baht, points) VALUES (?,?,?,?,0,0)',
        [crypto.randomUUID(), phone, 'ผู้ดูแลระบบ', 'admin'],
      );
    } else {
      await db.run('UPDATE users SET role = ? WHERE phone = ?', ['admin', phone]);
    }
  }
}
