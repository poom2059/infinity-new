# Deploy production บน Render

โดเมนปัจจุบัน: `https://infinity-new.onrender.com`

## สิ่งที่ได้
- Flutter Web + Express API โดเมนเดียวกัน
- OTP: มี Twilio = SMS จริง / ยังไม่มี = ได้รหัสชั่วคราวในแอป
- ชำระเงิน: มี Omise = PromptPay จริง / ยังไม่มี = โหมดจำลองในแอป
- ปุ่มโซเชียล: แสดงเฉพาะรายที่ตั้งค่า OAuth ครบ

## Environment บน Render (Web Service)

ตั้งใน Dashboard → Environment (หรือ sync จาก `render.yaml`):

| ตัวแปร | ค่าแนะนำตอนนี้ |
|--------|----------------|
| `SERVE_WEB` | `true` |
| `NODE_VERSION` | `20` |
| `PUBLIC_BASE_URL` | `https://infinity-new.onrender.com` |
| `CORS_ORIGIN` | `https://infinity-new.onrender.com` |
| `ALLOW_DEV_OTP` | `true` (จนกว่าจะมี Twilio) |
| `OMISE_ALLOW_SIMULATE` | `true` (จนกว่าจะมี Omise) |
| `ADMIN_PHONES` | เบอร์แอดมิน เช่น `0810000000,0888888888` |
| `DATABASE_URL` | Internal URL ของ Render Postgres (ถ้ามี) |

คีย์จริงเมื่อพร้อม: `TWILIO_*`, `OMISE_*`, `FIREBASE_SERVICE_ACCOUNT`, `GOOGLE_MAPS_SERVER_KEY`,  
`GOOGLE_OAUTH_CLIENT_ID/SECRET`, `FACEBOOK_APP_ID/SECRET`, `LINE_CHANNEL_ID/SECRET`

OAuth redirect URI:

```
https://infinity-new.onrender.com/v1/auth/oauth/google/callback
https://infinity-new.onrender.com/v1/auth/oauth/facebook/callback
https://infinity-new.onrender.com/v1/auth/oauth/line/callback
```

## Redeploy

หลัง push ไป `main` Render จะ deploy อัตโนมัติ  
หรือที่ Dashboard → Manual Deploy → **Deploy latest commit**

อัปเดตเว็บจากเครื่อง:

```powershell
.\deploy\render\build-for-render.ps1
git add -A
git commit -m "Rebuild web for Render"
git push
```

## เทสหลัง deploy
1. `https://infinity-new.onrender.com/health` → `{"ok":true,...}`
2. Hard refresh หน้าเว็บ (`Ctrl+Shift+R`)
3. ขอ OTP → ได้รหัสชั่วคราวใน snackbar → ยืนยัน → เข้าแอป

## หมายเหตุแผนฟรี
- cold start 30–60 วินาทีหลัง sleep
- ไม่มี `DATABASE_URL` = ใช้ SQLite (ข้อมูลอาจหายตอน redeploy)
