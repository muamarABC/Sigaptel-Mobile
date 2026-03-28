# SIGAPTEL Flutter App

[![Flutter Analyze](https://github.com/muamarABC/Sigaptel-Mobile/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/muamarABC/Sigaptel-Mobile/actions/workflows/flutter-ci.yml)
[![Branch](https://img.shields.io/badge/branch-main%20%7C%20develop-1f6feb)](https://github.com/muamarABC/Sigaptel-Mobile/branches)

Aplikasi mobile SIGAPTEL untuk login, pemetaan tower, dan pengelolaan data survei lapangan.
Proyek ini disiapkan dengan proteksi konfigurasi runtime agar endpoint API dan kode akses tidak terekspos saat repository dibagikan.

Project ini sudah disiapkan agar aman di-upload ke GitHub.
Orang yang clone project tidak bisa menjalankan aplikasi sebelum meminta:

- URL API valid (`SIGAPTEL_API_BASE_URL`)
- kode akses aplikasi (`SIGAPTEL_APP_ACCESS_CODE`)

Jika dua parameter itu belum diisi, aplikasi otomatis berhenti di halaman konfigurasi.

## 1. Cara Upload ke GitHub

Jalankan di root project:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/USERNAME/NAMA_REPO.git
git push -u origin main
```

## 2. Menjalankan Project (Wajib Isi Secret)

Project ini memakai `--dart-define-from-file`.
File contoh tersedia di `env/example.json`.

Langkah:

1. Buat file baru `env/local.json` (jangan di-commit).
2. Isi nilainya dari admin/pemilik project.
3. Jalankan aplikasi dengan file tersebut.

Contoh isi `env/local.json`:

```json
{
	"SIGAPTEL_API_BASE_URL": "https://tower.baritotimurkab.go.id",
	"SIGAPTEL_APP_ACCESS_CODE": "KODE_DARI_ADMIN"
}
```

Jalankan:

```bash
flutter pub get
flutter run --dart-define-from-file=env/local.json
```

Catatan untuk development lokal:

- Saat mode debug, aplikasi bisa memakai fallback lokal otomatis
	(`http://10.0.2.2:8000` dan `DEV-LOCAL`) jika dart-define belum diisi.
- Saat mode release/profile, parameter tetap wajib diisi.

Untuk build release:

```bash
flutter build apk --dart-define-from-file=env/local.json
```

## 2.1 Menjalankan dari Tombol Run VS Code

Konfigurasi VS Code sudah disediakan di folder `.vscode`.

- Pilih profile: `SIGAPTEL Auto Run (local.json optional)`
- Tekan tombol Run/Debug

Perilaku otomatis:

- Jika `env/local.json` ada, file itu dipakai sebagai dart-define.
- Jika tidak ada, VS Code membuat define kosong dan aplikasi memakai fallback debug lokal.

## 3. Kenapa Orang Lain Tidak Bisa Langsung Menjalankan

Semua endpoint API sudah dipindah dari hardcoded URL ke konfigurasi runtime.
Aplikasi hanya berjalan jika dua parameter berikut ada:

- `SIGAPTEL_API_BASE_URL`
- `SIGAPTEL_APP_ACCESS_CODE`

Selain itu, setiap request API membawa header:

- `X-App-Code: <SIGAPTEL_APP_ACCESS_CODE>`

Supaya efektif, backend harus memvalidasi header `X-App-Code` ini.

## 4. Catatan Keamanan Penting

- Jangan commit file rahasia seperti `env/local.json`.
- `.gitignore` sudah diatur untuk mengabaikan `env/*.json` kecuali `env/example.json`.
- Kunci keamanan utama tetap di backend (validasi token/app code, rate limit, dan pembatasan origin jika perlu).

## 5. Workflow Git Dasar

- Branch `main`: branch produksi, stabil, hanya menerima perubahan dari Pull Request.
- Branch `develop`: branch integrasi pengembangan harian.
- Branch fitur: buat dari `develop` dengan pola nama `feature/nama-fitur`.

Alur singkat:

1. Buat branch fitur dari `develop`.
2. Kerjakan perubahan lalu push branch fitur.
3. Buat Pull Request ke `develop`.
4. Setelah lolos review dan CI, merge ke `develop`.
5. Saat siap rilis, buat Pull Request `develop` ke `main`.
