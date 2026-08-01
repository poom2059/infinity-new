# เทส Login + API จริงบน Render

โปรเจกต์นี้พร้อม deploy เป็น **เว็บ + API โดเมนเดียวกัน** บน Render (ฟรี)

## สิ่งที่ได้
- URL เดียว เช่น `https://infinity-app-xxxx.onrender.com`
- หน้า Flutter Web + `/v1/auth/...` API
- ล็อกอิน OTP: ใส่เบอร์ แล้วใส่รหัส **6 หลักใดก็ได้**
- แอดมินทดสอบ: `0810000000` หรือ `0888888888`

## ขั้นตอน (ครั้งแรก)

### 1) โค้ดอยู่บน GitHub แล้ว
Repo: https://github.com/poom2059/infinity-new

ต้องมีโฟลเดอร์ `server/public/` (Flutter ที่ build แล้วแบบ `USE_API=true` + `API_BASE=.`)

อัปเดต public จากเครื่อง:

```powershell
.\deploy\render\build-for-render.ps1
git add -A
git commit -m "Build web for Render API login test"
git push
```

### 2) สร้างบริการบน Render
1. เปิด https://dashboard.render.com แล้ว Sign up / Login (ใช้ GitHub ได้)
2. **New +** → **Blueprint**  
   หรือ **New +** → **Web Service** แล้วเลือก repo `infinity-new`
3. ถ้าใช้ Web Service เอง ตั้งค่า:
   - **Root Directory:** `server`
   - **Runtime:** Node
   - **Build Command:** `npm install --omit=dev`
   - **Start Command:** `npm start`
   - **Instance type:** Free
4. Environment:
   - `SERVE_WEB` = `true`
   - `NODE_VERSION` = `20`
5. Deploy รอจนสถานะ **Live**

### 3) เทส
1. เปิด URL ที่ Render ให้
2. ตรวจ `https://YOUR-APP.onrender.com/health` ควรได้ `{"ok":true,...}`
3. ในแอป: ขอ OTP → ใส่รหัส 6 หลักใดก็ได้ → เข้าสู่ระบบ

## หมายเหตุแผนฟรี
- ถ้าไม่ใช้สักพัก บริการจะ **sleep** — เปิดครั้งถัดไปอาจรอ 30–60 วินาที
- ไฟล์ SQLite **ไม่ถาวร** หลัง redeploy ข้อมูลอาจหาย (พอสำหรับเทส)
- อย่าใช้เป็น production จริงโดยไม่มี Postgres / disk

## บัญชีทดสอบ
| เบอร์ | บทบาท |
|-------|--------|
| 0810000000 | admin |
| 0888888888 | admin |
| เบอร์อื่น | customer (สร้างอัตโนมัติตอน verify OTP) |
