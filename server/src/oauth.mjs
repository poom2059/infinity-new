/**
 * OAuth แบบ redirect สำหรับเว็บ: Google / Facebook / LINE
 * ผู้ใช้กดปุ่ม -> /v1/auth/oauth/:provider/start -> หน้า login ของผู้ให้บริการ
 * -> /v1/auth/oauth/:provider/callback -> กลับเข้าแอปพร้อม ?auth_token=
 */
import crypto from 'crypto';
import { socialProviderStatus, upsertSocialUser } from './auth.mjs';

const PROVIDERS = {
  google: {
    idEnv: 'GOOGLE_OAUTH_CLIENT_ID',
    secretEnv: 'GOOGLE_OAUTH_CLIENT_SECRET',
    authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenUrl: 'https://oauth2.googleapis.com/token',
    scope: 'openid email profile',
  },
  facebook: {
    idEnv: 'FACEBOOK_APP_ID',
    secretEnv: 'FACEBOOK_APP_SECRET',
    authUrl: 'https://www.facebook.com/v21.0/dialog/oauth',
    tokenUrl: 'https://graph.facebook.com/v21.0/oauth/access_token',
    scope: 'public_profile,email',
  },
  line: {
    idEnv: 'LINE_CHANNEL_ID',
    secretEnv: 'LINE_CHANNEL_SECRET',
    authUrl: 'https://access.line.me/oauth2/v2.1/authorize',
    tokenUrl: 'https://api.line.me/oauth2/v2.1/token',
    scope: 'profile openid email',
  },
};

// state ชั่วคราว (อายุ 10 นาที) — พอสำหรับ single instance บน Render
const pendingStates = new Map();

function rememberState(state, payload) {
  pendingStates.set(state, { ...payload, expiresAt: Date.now() + 10 * 60 * 1000 });
  for (const [key, value] of pendingStates) {
    if (value.expiresAt < Date.now()) pendingStates.delete(key);
  }
}

function takeState(state) {
  const entry = pendingStates.get(state);
  if (!entry) return null;
  pendingStates.delete(state);
  if (entry.expiresAt < Date.now()) return null;
  return entry;
}

function publicBaseUrl(req) {
  const configured = (process.env.PUBLIC_BASE_URL || '').trim();
  if (configured) return configured.replace(/\/$/, '');
  return `${req.protocol}://${req.get('host')}`;
}

function redirectUri(req, provider) {
  return `${publicBaseUrl(req)}/v1/auth/oauth/${provider}/callback`;
}

function safeAppRedirect(req, raw) {
  const base = publicBaseUrl(req);
  if (!raw) return `${base}/`;
  try {
    const url = new URL(raw, base);
    if (url.origin !== new URL(base).origin) return `${base}/`;
    url.searchParams.delete('auth_token');
    url.searchParams.delete('auth_error');
    return url.toString();
  } catch {
    return `${base}/`;
  }
}

async function exchangeCode(provider, cfg, code, redirect) {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: redirect,
    client_id: process.env[cfg.idEnv],
    client_secret: process.env[cfg.secretEnv],
  });
  const res = await fetch(cfg.tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!res.ok) {
    throw new Error(`แลกโทเคน ${provider} ไม่สำเร็จ: ${await res.text()}`);
  }
  return res.json();
}

async function fetchProfile(provider, tokens) {
  if (provider === 'google') {
    const res = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    });
    if (!res.ok) throw new Error('อ่านโปรไฟล์ Google ไม่สำเร็จ');
    const d = await res.json();
    return { providerUid: d.sub, email: d.email || null, name: d.name };
  }
  if (provider === 'facebook') {
    const res = await fetch(
      `https://graph.facebook.com/me?fields=id,name,email&access_token=${encodeURIComponent(tokens.access_token)}`,
    );
    if (!res.ok) throw new Error('อ่านโปรไฟล์ Facebook ไม่สำเร็จ');
    const d = await res.json();
    return { providerUid: d.id, email: d.email || null, name: d.name };
  }
  const res = await fetch('https://api.line.me/v2/profile', {
    headers: { Authorization: `Bearer ${tokens.access_token}` },
  });
  if (!res.ok) throw new Error('อ่านโปรไฟล์ LINE ไม่สำเร็จ');
  const d = await res.json();
  return { providerUid: d.userId, email: null, name: d.displayName };
}

export function registerOauthRoutes(app) {
  app.get('/v1/auth/providers', (req, res) => {
    const status = socialProviderStatus();
    res.json({
      providers: Object.keys(PROVIDERS).map((name) => ({
        provider: name,
        enabled: status[name] === true,
        start_url: `${publicBaseUrl(req)}/v1/auth/oauth/${name}/start`,
      })),
    });
  });

  app.get('/v1/auth/oauth/:provider/start', (req, res, next) => {
    try {
      const provider = String(req.params.provider || '').toLowerCase();
      const cfg = PROVIDERS[provider];
      if (!cfg) return res.status(404).json({ error: 'ผู้ให้บริการไม่รองรับ' });
      if (!socialProviderStatus()[provider]) {
        const back = new URL(safeAppRedirect(req, req.query.redirect));
        back.searchParams.set(
          'auth_error',
          `ยังไม่ได้ตั้งค่า ${cfg.idEnv} / ${cfg.secretEnv} บนเซิร์ฟเวอร์`,
        );
        return res.redirect(back.toString());
      }
      const state = crypto.randomBytes(16).toString('hex');
      rememberState(state, {
        provider,
        appRedirect: safeAppRedirect(req, req.query.redirect),
      });
      const params = new URLSearchParams({
        client_id: process.env[cfg.idEnv],
        redirect_uri: redirectUri(req, provider),
        response_type: 'code',
        scope: cfg.scope,
        state,
      });
      res.redirect(`${cfg.authUrl}?${params.toString()}`);
    } catch (e) {
      next(e);
    }
  });

  app.get('/v1/auth/oauth/:provider/callback', async (req, res, next) => {
    const provider = String(req.params.provider || '').toLowerCase();
    const cfg = PROVIDERS[provider];
    const entry = takeState(String(req.query.state || ''));
    const appRedirect = entry?.appRedirect || `${publicBaseUrl(req)}/`;
    const fail = (message) => {
      const url = new URL(appRedirect);
      url.searchParams.set('auth_error', message);
      res.redirect(url.toString());
    };
    try {
      if (!cfg) return fail('ผู้ให้บริการไม่รองรับ');
      if (!entry || entry.provider !== provider) return fail('เซสชันหมดอายุ กรุณาลองใหม่');
      if (req.query.error) return fail(String(req.query.error_description || req.query.error));
      const code = String(req.query.code || '');
      if (!code) return fail('ไม่ได้รับรหัสยืนยันจากผู้ให้บริการ');

      const tokens = await exchangeCode(provider, cfg, code, redirectUri(req, provider));
      const profile = await fetchProfile(provider, tokens);
      const session = await upsertSocialUser({ provider, ...profile });

      const url = new URL(appRedirect);
      url.searchParams.set('auth_token', session.token);
      res.redirect(url.toString());
    } catch (e) {
      console.error('[oauth]', e);
      fail(e.message || 'เข้าสู่ระบบไม่สำเร็จ');
    }
  });
}
