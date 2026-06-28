# 💰 MoneyMate — Money Manager

Aplikasi manajemen keuangan personal dengan Flutter & Go.

## Quick Start

```
money-manager/
├── docs/          → Dokumentasi teknis lengkap
├── backend/       → Go REST API (net/http + pgx + PostgreSQL)
└── mobile/        → Flutter app (Provider + Dio + fl_chart)
```

### 1. Jalankan Database
```bash
docker run -d --name money-db \
  -e POSTGRES_USER=moneyuser -e POSTGRES_PASSWORD=moneypass -e POSTGRES_DB=moneymanager \
  -p 5432:5432 postgres:15
```

### 2. Setup Backend
```bash
cd backend
cp .env.example .env      # Edit JWT_SECRET minimal 32 karakter
go mod tidy
psql "host=localhost user=moneyuser password=moneypass dbname=moneymanager sslmode=disable" -f migrations/001_init.sql
psql "host=localhost user=moneyuser password=moneypass dbname=moneymanager sslmode=disable" -f migrations/002_seed.sql
go run ./cmd/server       # http://localhost:8080
```

### 3. Jalankan Mobile
```bash
cd mobile
flutter pub get
flutter run
```

## Dokumentasi
- `docs/technical-spec.md` — Arsitektur & design system
- `docs/api-spec.md` — REST API endpoints
- `docs/database-schema.md` — Schema database & query utama
