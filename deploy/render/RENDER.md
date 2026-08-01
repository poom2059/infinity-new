# Deploy production บน Render

โดเมนปัจจุบัน: `https://infinity-new.onrender.com`

## สิ่งที่ได้
- Flutter Web + Express API โดเมนเดียวกัน
- OTP จริงผ่าน **Twilio SMS** หรือ **Firebase Phone Auth** (เมื่อตั้งค่า)
- ชำระเงิน **Omise PromptPay**
- ฐานข้อมูล **Postgres** (แนะนำ) หรือ SQLite ชั่วคราวบน disk ฟรี

## Environment บน Render (Web Service)

| ตัวแปร | ความหมาย |
|--------|----------|
| `SERVE_WEB` | `true` |
| `NODE_VERSION` | `20` |
| `DATABASE_URL` | connection string ของ Render Postgres |
| `ADMIN_PHONES` | เบอร์แอดมินคั่นด้วยจุลภาค เช่น `0810000000,0888888888` |
| `CORS_ORIGIN` | `https://infinity-new.onrender.com` |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` / `TWILIO_FROM_NUMBER` | ส่ง OTP SMS |
| `ALLOW_DEV_OTP` | ถ้ายังไม่มี Twilio: ไม่ต้องตั้ง (ระบบคืน `dev_code` ให้ทดสอบ) — ตั้ง `false` เมื่อมี SMS จริงแล้ว |
| `FIREBASE_SERVICE_ACCOUNT` | JSON service account ทั้งก้อน (verify Firebase idToken + FCM) |
| `OMISE_SECRET_KEY` / `OMISE_PUBLIC_KEY` | คีย์ Omise (เริ่มด้วย test ได้) |
| `OMISE_ALLOW_SIMULATE` | `true` เฉพาะ staging เมื่อยังไม่มี Omise |
| `GOOGLE_MAPS_SERVER_KEY` | geocode/places ฝั่งเซิร์ฟเวอร์ |
| `PUBLIC_BASE_URL` | `https://infinity-new.onrender.com` (ใช้สร้าง redirect URI ของ OAuth) |
| `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_SECRET` | ปุ่ม Google |
| `FACEBOOK_APP_ID` / `FACEBOOK_APP_SECRET` | ปุ่ม Facebook |
| `LINE_CHANNEL_ID` / `LINE_CHANNEL_SECRET` | ปุ่ม LINE |

ปุ่มโซเชียลจะ **แสดงเฉพาะรายที่ตั้งค่าครบ** (แอปเช็คจาก `GET /v1/auth/providers`)

Redirect URI ที่ต้องลงทะเบียนกับแต่ละผู้ให้บริการ:

```
https://infinity-new.onrender.com/v1/auth/oauth/google/callback
https://infinity-new.onrender.com/v1/auth/oauth/facebook/callback
https://infinity-new.onrender.com/v1/auth/oauth/line/callback
```

**อย่า**เปิด `ALLOW_DEV_OTP` หรือ `OMISE_ALLOW_SIMULATE` บน production เมื่อมี Twilio/Omise แล้ว — ตั้ง `ALLOW_DEV_OTP=false`

## Build Flutter เข้า `server/public`

```powershell
$env:GOOGLE_MAPS_BROWSER_KEY = 'YOUR_BROWSER_KEY'   # optional
.\deploy\render\build-for-render.ps1
git add server/public
git commit -m "Rebuild web for Render production"
git push
```

สคริปต์จะ build ด้วย `USE_API=true` และ `API_BASE=.` แล้ว copy ไป `server/public/`

ถ้ามี Firebase ในแอป เพิ่ม dart-define ในสคริปต์/CI:
`--dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_PROJECT_ID=...` ฯลฯ

## Postgres
1. Render Dashboard → **New +** → **PostgreSQL** (Free/Starter)
2. Copy **Internal Database URL** ไปใส่ `DATABASE_URL` ของ Web Service
3. Redeploy — สคีมาจะ migrate อัตโนมัติตอนบูต

## เทสหลัง deploy
1. `https://infinity-new.onrender.com/health` → `{"ok":true,...}`
2. ขอ OTP → ต้องได้รับ SMS จริง (หรือดู log ถ้า `OTP_LOG_CODE=true` บน staging)
3. เติมวอเลต / สั่งอาหารด้วย Omise test key
4. โพสงาน + มัดจำ 50%

## หมายเหตุแผนฟรี
- บริการอาจ sleep หลังไม่ใช้งาน — cold start 30–60 วินาที
- ถ้าไม่มี `DATABASE_URL` ข้อมูล SQLite จะหายตอน redeploy
