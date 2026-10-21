# SIGAPTEL Flutter App

[![Flutter Analyze](https://github.com/muamarABC/Sigaptel-Mobile/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/muamarABC/Sigaptel-Mobile/actions/workflows/flutter-ci.yml)
[![Branch](https://img.shields.io/badge/branch-main%20%7C%20develop-1f6feb)](https://github.com/muamarABC/Sigaptel-Mobile/branches)

Aplikasi mobile SIGAPTEL untuk login, pemetaan tower, dan pengelolaan data survei lapangan.
Proyek ini menggunakan endpoint API tetap yang diset di kode sumber.

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

## 2. Menjalankan Project

Jalankan:

```bash
flutter pub get
flutter run
```

Untuk build release:

```bash
flutter build apk
```

## 3. Catatan

- Endpoint API utama tersimpan di `lib/services/tower_service.dart`, `lib/providers/auth_provider.dart`, dan `lib/providers/api_survey_provider.dart`.
- Sesuaikan URL jika backend Anda berbeda.

## 4. Workflow Git Dasar

- Branch `main`: branch produksi, stabil, hanya menerima perubahan dari Pull Request.
- Branch `develop`: branch integrasi pengembangan harian.
- Branch fitur: buat dari `develop` dengan pola nama `feature/nama-fitur`.

Alur singkat:

1. Buat branch fitur dari `develop`.
2. Kerjakan perubahan lalu push branch fitur.
3. Buat Pull Request ke `develop`.
4. Setelah lolos review dan CI, merge ke `develop`.
5. Saat siap rilis, buat Pull Request `develop` ke `main`.
