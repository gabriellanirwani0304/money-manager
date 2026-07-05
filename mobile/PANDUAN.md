# Panduan Menjalankan MoneyMate (Mobile)

## Prasyarat

Pastikan sudah terinstall:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi 3.7+)
- [Android Studio](https://developer.android.com/studio) — untuk Android emulator
- [Xcode](https://developer.apple.com/xcode/) — untuk iOS simulator (Mac only)
- [CocoaPods](https://cocoapods.org/) — `brew install cocoapods`

Cek semua sudah siap dengan:
```bash
flutter doctor
```
Semua item harus centang hijau ✅ sebelum lanjut.

---

## Setup Pertama Kali

### 1. Install dependencies
```bash
cd mobile
flutter pub get
```

### 2. Buat file environment

Salin file contoh dan sesuaikan:

```bash
# Untuk iOS simulator
cp .env.example .env.ios

# Untuk Android emulator
cp .env.example .env.android
# lalu edit .env.android → ganti BASE_URL ke http://10.0.2.2:8080/api/v1

# Untuk device fisik (HP sungguhan)
cp .env.example .env.device
# lalu edit .env.device → ganti IP ke IP laptop kamu (cek dengan `ifconfig | grep inet`)
```

Isi setiap file:

| File | BASE_URL |
|------|----------|
| `.env.ios` | `http://localhost:8080/api/v1` |
| `.env.android` | `http://10.0.2.2:8080/api/v1` |
| `.env.device` | `http://<IP_LAPTOP>:8080/api/v1` |

---

## Menjalankan Backend

Backend harus berjalan sebelum membuka app. Dari root project:
```bash
docker compose up -d
```
Atau langsung dari folder backend:
```bash
cd backend
go run ./cmd/server
```

---

## Menjalankan di iOS Simulator

### Langkah 1 — Buka simulator
```bash
flutter emulators --launch apple_ios_simulator
```

### Langkah 2 — Jalankan app
```bash
cd mobile
flutter run --dart-define-from-file=.env.ios
```

App akan otomatis muncul di simulator. Proses pertama kali ±3 menit karena compile dari awal. Berikutnya lebih cepat.

### Pilih tipe iPhone tertentu
```bash
# Lihat daftar simulator yang tersedia
flutter devices

# Jalankan di device tertentu (gunakan ID dari output di atas)
flutter run -d <DEVICE_ID> --dart-define-from-file=.env.ios
```

---

## Menjalankan di Android Emulator

### Langkah 1 — Buka emulator
Buka Android Studio → Device Manager → klik tombol ▶️ di emulator yang diinginkan.

Atau via terminal:
```bash
flutter emulators --launch <nama_emulator>
```

### Langkah 2 — Jalankan app
```bash
cd mobile
flutter run --dart-define-from-file=.env.android
```

---

## Menjalankan di HP Fisik

### Android
1. Aktifkan **Developer Options** di HP → nyalakan **USB Debugging**
2. Sambungkan HP ke laptop via USB
3. Pastikan HP dan laptop terhubung ke WiFi yang sama
4. Cari IP laptop:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
5. Isi `.env.device` dengan IP tersebut
6. Jalankan:
   ```bash
   flutter run --dart-define-from-file=.env.device
   ```

### iPhone
Butuh Apple Developer Account untuk install ke device fisik. Hubungi developer untuk signing.

---

## Perintah Berguna Saat App Sedang Berjalan

Setelah `flutter run`, tekan tombol ini di terminal:

| Tombol | Fungsi |
|--------|--------|
| `r` | Hot reload — refresh UI tanpa restart (cepat) |
| `R` | Hot restart — restart app dari awal |
| `q` | Keluar / stop app |
| `d` | Detach — biarkan app tetap berjalan, lepas dari terminal |

---

## Build APK (Android) untuk Distribusi

```bash
cd mobile
flutter build apk --release --dart-define-from-file=.env.android
```
File APK tersimpan di: `build/app/outputs/flutter-apk/app-release.apk`

Install ke HP yang terhubung:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Troubleshooting

### Login gagal / tidak bisa connect ke server
- Pastikan backend sudah berjalan
- Pastikan file `.env.*` sudah benar sesuai platform
- Untuk device fisik: pastikan HP dan laptop di WiFi yang sama

### App keluar sendiri saat hot restart
Sudah diperbaiki — app menggunakan `SharedPreferences` yang persist data login.

### `flutter doctor` ada yang merah
- Android SDK tidak ditemukan → buka Android Studio, install SDK via SDK Manager
- CocoaPods tidak ditemukan → `brew install cocoapods`
- Xcode tidak lengkap → `xcode-select --install`

### Port 8080 tidak bisa diakses
```bash
# Cek apakah backend berjalan
curl http://localhost:8080/api/v1/auth/login
# Harusnya dapat response (bukan "connection refused")
```
