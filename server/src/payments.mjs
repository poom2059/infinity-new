import crypto from 'crypto';
import { db } from './db.mjs';

function omiseAuthHeader() {
  const secret = (process.env.OMISE_SECRET_KEY || '').trim();
  if (!secret) return null;
  return `Basic ${Buffer.from(`${secret}:`).toString('base64')}`;
}

export async function creditWallet(userId, amountBaht, title) {
  await db.run('UPDATE users SET wallet_balance_baht = wallet_balance_baht + ? WHERE id = ?', [
    amountBaht,
    userId,
  ]);
  await db.run(
    'INSERT INTO wallet_ledger (id, user_id, title, amount_baht, created_at) VALUES (?,?,?,?,?)',
    [crypto.randomUUID(), userId, title, amountBaht, new Date().toISOString()],
  );
}

export async function createPaymentIntent({
  userId,
  amountBaht,
  purpose = 'order',
  orderId = null,
  returnUri = null,
}) {
  const amount = Math.round(Number(amountBaht || 0));
  if (!Number.isFinite(amount) || amount < 1) {
    const err = new Error('จำนวนเงินไม่ถูกต้อง');
    err.status = 400;
    throw err;
  }
  const id = `pi-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
  const auth = omiseAuthHeader();

  if (!auth) {
    // ถ้ายังไม่มี Omise key — อนุญาตจำลองจนกว่าจะตั้ง OMISE_ALLOW_SIMULATE=false
    const allowSim =
      process.env.OMISE_ALLOW_SIMULATE === 'true' ||
      (process.env.OMISE_ALLOW_SIMULATE !== 'false' && !(process.env.OMISE_SECRET_KEY || '').trim());
    if (allowSim) {
      await db.run(
        `INSERT INTO payment_intents (id, user_id, amount_baht, status, order_id, purpose, meta_json)
         VALUES (?,?,?,?,?,?,?)`,
        [id, userId, amount, 'pending', orderId, purpose, JSON.stringify({ simulate: true })],
      );
      return {
        id,
        status: 'pending',
        amount_baht: amount,
        purpose,
        simulate: true,
        omise_public_key: process.env.OMISE_PUBLIC_KEY || null,
      };
    }
    const err = new Error('ยังไม่ได้ตั้งค่า OMISE_SECRET_KEY');
    err.status = 503;
    throw err;
  }

  // Create PromptPay source + charge
  const sourceBody = new URLSearchParams({
    type: 'promptpay',
    amount: String(amount * 100),
    currency: 'thb',
  });
  const sourceRes = await fetch('https://api.omise.co/sources', {
    method: 'POST',
    headers: {
      Authorization: auth,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: sourceBody,
  });
  if (!sourceRes.ok) {
    const t = await sourceRes.text();
    const err = new Error(`สร้าง Omise source ไม่สำเร็จ: ${t}`);
    err.status = 502;
    throw err;
  }
  const source = await sourceRes.json();

  const chargeParams = new URLSearchParams({
    amount: String(amount * 100),
    currency: 'thb',
    source: source.id,
  });
  if (returnUri) chargeParams.set('return_uri', returnUri);

  const chargeRes = await fetch('https://api.omise.co/charges', {
    method: 'POST',
    headers: {
      Authorization: auth,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: chargeParams,
  });
  if (!chargeRes.ok) {
    const t = await chargeRes.text();
    const err = new Error(`สร้าง Omise charge ไม่สำเร็จ: ${t}`);
    err.status = 502;
    throw err;
  }
  const charge = await chargeRes.json();
  const qr =
    charge?.source?.scannable_code?.image?.download_uri ||
    charge?.source?.scannable_code?.image?.uri ||
    null;

  await db.run(
    `INSERT INTO payment_intents
      (id, user_id, amount_baht, status, order_id, purpose, omise_charge_id, omise_source_id, qr_image_url, meta_json)
     VALUES (?,?,?,?,?,?,?,?,?,?)`,
    [
      id,
      userId,
      amount,
      charge.status === 'successful' ? 'succeeded' : 'pending',
      orderId,
      purpose,
      charge.id,
      source.id,
      qr,
      JSON.stringify({ charge_status: charge.status }),
    ],
  );

  return {
    id,
    status: charge.status === 'successful' ? 'succeeded' : 'pending',
    amount_baht: amount,
    purpose,
    qr_image_url: qr,
    omise_charge_id: charge.id,
    omise_public_key: process.env.OMISE_PUBLIC_KEY || null,
    authorize_uri: charge.authorize_uri || null,
  };
}

export async function getPaymentIntent(id, userId) {
  const row = await db.one('SELECT * FROM payment_intents WHERE id = ? AND user_id = ?', [id, userId]);
  if (!row) return null;
  // Refresh from Omise if pending
  if (row.status === 'pending' && row.omise_charge_id && omiseAuthHeader()) {
    const res = await fetch(`https://api.omise.co/charges/${row.omise_charge_id}`, {
      headers: { Authorization: omiseAuthHeader() },
    });
    if (res.ok) {
      const charge = await res.json();
      if (charge.status === 'successful') {
        await markSucceeded(row);
        row.status = 'succeeded';
      } else if (charge.status === 'failed' || charge.status === 'expired') {
        await db.run('UPDATE payment_intents SET status = ? WHERE id = ?', ['failed', row.id]);
        row.status = 'failed';
      }
    }
  }
  let meta = {};
  try {
    meta = row.meta_json ? JSON.parse(row.meta_json) : {};
  } catch (_) {
    meta = {};
  }
  return {
    id: row.id,
    status: row.status,
    amount_baht: row.amount_baht,
    purpose: row.purpose,
    qr_image_url: row.qr_image_url,
    omise_charge_id: row.omise_charge_id,
    simulate: meta.simulate === true,
    omise_public_key: process.env.OMISE_PUBLIC_KEY || null,
  };
}

async function markSucceeded(row) {
  if (row.status === 'succeeded') return;
  await db.run('UPDATE payment_intents SET status = ? WHERE id = ?', ['succeeded', row.id]);
  if (row.purpose === 'wallet_topup') {
    await creditWallet(row.user_id, row.amount_baht, 'เติมเงินผ่าน Omise');
  }
}

export async function handleOmiseWebhook(payload) {
  const charge = payload?.data;
  if (!charge?.id) return { ok: true, ignored: true };
  const row = await db.one('SELECT * FROM payment_intents WHERE omise_charge_id = ?', [charge.id]);
  if (!row) return { ok: true, ignored: true };
  if (charge.status === 'successful') {
    await markSucceeded(row);
  } else if (charge.status === 'failed' || charge.status === 'expired') {
    await db.run('UPDATE payment_intents SET status = ? WHERE id = ?', ['failed', row.id]);
  }
  return { ok: true };
}

/** Staging-only: confirm simulated intent when OMISE_ALLOW_SIMULATE=true */
export async function confirmSimulated(intentId, userId) {
  const allowSim =
    process.env.OMISE_ALLOW_SIMULATE === 'true' ||
    (process.env.OMISE_ALLOW_SIMULATE !== 'false' && !(process.env.OMISE_SECRET_KEY || '').trim());
  if (!allowSim) {
    const err = new Error('จำลองการชำระเงินถูกปิด');
    err.status = 403;
    throw err;
  }
  const row = await db.one('SELECT * FROM payment_intents WHERE id = ? AND user_id = ?', [
    intentId,
    userId,
  ]);
  if (!row) {
    const err = new Error('ไม่พบรายการชำระเงิน');
    err.status = 404;
    throw err;
  }
  await markSucceeded(row);
  return { ok: true, status: 'succeeded' };
}
