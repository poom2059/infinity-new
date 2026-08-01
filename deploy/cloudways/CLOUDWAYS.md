# Deploy Infinity บน Cloudways (แผนฟรี: PHP / Custom App)

แผนฟรีของ Cloudways **ไม่มี Node.js** — มีแค่ **PHP** หรือ **Custom App**  
ทั้งสองแบบใช้โฟลเดอร์ `public_html` เสิร์ฟไฟล์เว็บได้ → วิธีที่ใช่คืออัป **Flutter Web (static)**

API แบบ Node (`server/`) **รันบน Cloudways ฟรีไม่ได้**  
ตอนนี้เลยมี 2 ทาง:

| ทาง | เหมาะกับ | วิธี |
|-----|----------|------|
| **A แนะนำ** | ทดลอง/โชว์แอป | อัปเว็บอย่างเดียว โหมด demo (`USE_API=false`) |
| **B** | ต้องการ API จริง | อัปเว็บบน Cloudways + วาง API ที่โฮสต์ Node ฟรีอื่น แล้วชี้ `API_BASE` |

---

## ทาง A — อัปแค่หน้าเว็บ (PHP หรือ Custom App)

### 1) สร้างแอปบน Cloudways

1. **Add Application**
2. เลือก **PHP** หรือ **Custom App** (อันไหนก็ได้สำหรับ static)
3. จด URL เช่น `https://phpstack-xxxxx.cloudwaysapps.com`
4. เปิด **SSL** (Let's Encrypt)

### 2) Build บนเครื่องคุณ

```powershell
.\deploy\cloudways\build-and-pack.ps1 -Mode static -Demo
```

ได้โฟลเดอร์ `deploy/cloudways/dist/static-...`

### 3) อัปเข้า `public_html`

1. Application → **Master Credentials** / SFTP
2. ลบหรือสำรองไฟล์เดิมใน `public_html` (เช่น `index.php` ของ PHP ว่างๆ)
3. อัป **ทุกไฟล์** จากโฟลเดอร์ `static-...` เข้า `public_html`  
   ให้มี `index.html` และ `.htaccess` อยู่ที่ราก `public_html`
4. เปิด URL แอปในเบราว์เซอร์

`.htaccess` ทำให้ Flutter routing ทำงานบน Apache (Cloudways PHP ใช้ Apache/Nginx stack ที่มี rewrite)

ถ้าหน้าในลึกๆ รีเฟรชแล้ว 404 ให้ไปที่ **Application Settings → Varnish / Nginx** แล้วใส่ custom:

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

### โหมด Demo คืออะไร

- ไม่ต้องมีเซิร์ฟเวอร์ API
- แอปใช้ข้อมูลในเครื่อง (offline/demo) ตามที่โค้ดรองรับอยู่แล้ว
- พอพร้อมมี API จริง ค่อย build ใหม่แบบทาง B

---

## ทาง B — เว็บบน Cloudways + API ที่อื่น

1. รัน Node API ที่โฮสต์ที่รองรับ Node (เช่น Render / Railway / Fly.io / VPS)
2. ได้ URL API เช่น `https://infinity-api.onrender.com`
3. Build ชี้ API:

```powershell
.\deploy\cloudways\build-and-pack.ps1 -Mode static -ApiBase https://infinity-api.onrender.com
```

4. อัป `static-...` เข้า `public_html` เหมือนทาง A
5. บนเซิร์ฟเวอร์ API ตั้ง `CORS_ORIGIN=https://โดเมน-cloudways-ของคุณ`

---

## คำสั่ง build เอง

```powershell
# Demo — ไม่ใช้ API (แนะนำแผนฟรี)
flutter build web --release --dart-define=USE_API=false

# มี API ภายนอก
flutter build web --release --dart-define=USE_API=true --dart-define=API_BASE=https://api.example.com
```

แล้วคัดลอก `build/web/*` + `web/.htaccess` เข้า `public_html`

---

## Checklist

- [ ] แอปเป็น **PHP** หรือ **Custom App** (ไม่ต้องรอ Node)
- [ ] ไฟล์อยู่ใน `public_html` และมี `index.html` + `.htaccess`
- [ ] เปิดผ่าน `https://`
- [ ] จำกัด Google Maps API key ตามโดเมน Cloudways (HTTP referrer)

---

## โครงสร้างแพ็ก Static

```text
static-YYYYMMDD-HHMMSS/
  index.html
  main.dart.js
  flutter_bootstrap.js
  assets/
  icons/
  .htaccess          ← สำคัญ อย่าลืมอัป
  ...
```

อัปทั้งโฟลเดอร์นี้เข้า `public_html` เท่านั้น — **ไม่ต้อง** `npm install` และไม่ต้องอัปโฟลเดอร์ `server/`
