# Money Manager — Technical Specification

## 1. Overview

Money Manager adalah aplikasi personal finance yang memungkinkan pengguna melacak pemasukan dan pengeluaran berdasarkan kategori, menetapkan anggaran bulanan, dan menganalisis pola keuangan melalui laporan visual.

**Tujuan Utama:**
- Pencatatan transaksi income/expense dengan kategori
- Deteksi pola pengeluaran berlebih (budget alert)
- Analisis tren keuangan bulanan dan tahunan
- Transaksi berulang otomatis (gaji, tagihan rutin)

---

## 2. Tech Stack

### Backend
| Komponen        | Teknologi                    |
|----------------|-------------------------------|
| Language        | Go 1.22+                     |
| HTTP Framework  | `net/http` (stdlib)           |
| Database        | PostgreSQL 15+                |
| DB Driver       | `github.com/jackc/pgx/v5`    |
| Auth            | JWT (`golang-jwt/jwt/v5`)    |
| Password Hash   | `bcrypt`                      |
| UUID            | `github.com/google/uuid`     |
| Env Config      | `github.com/joho/godotenv`   |

### CMS
| Komponen        | Teknologi                      |
|----------------|--------------------------------|
| Framework       | React 19 + TypeScript          |
| Build Tool      | Vite                           |
| Styling         | Tailwind CSS                   |
| Component Lib   | shadcn/ui (Radix UI)           |
| HTTP Client     | Axios                          |
| Charts          | Recharts                       |
| Icons           | Lucide React                   |
| Notifications   | Sonner (toast)                 |

### Mobile
| Komponen        | Teknologi                      |
|----------------|--------------------------------|
| Framework       | Flutter 3.44.2                 |
| State Management| `provider ^6.1.2`             |
| HTTP Client     | `dio ^5.7.0`                  |
| Charts          | `fl_chart ^0.69.0`            |
| Secure Storage  | `flutter_secure_storage ^9.2.0`|
| Date Formatting | `intl ^0.19.0`                |
| Local Prefs     | `shared_preferences ^2.3.0`   |

---

## 3. Features

### 3.1 Core Features
| # | Fitur | Deskripsi |
|---|-------|-----------|
| F01 | Autentikasi | Register, Login, JWT refresh token |
| F02 | Manajemen Kategori | CRUD kategori income/expense dengan ikon & warna; server-side search & pagination |
| F03 | Input Transaksi | Catat income/expense/transfer dengan kategori, rekening, nominal, deskripsi, tanggal |
| F04 | Riwayat Transaksi | List transaksi dengan filter tanggal, kategori, rekening, tipe; full-text search |
| F05 | Dashboard | Ringkasan saldo, income vs expense bulan ini, top expenses, budget alerts |
| F06 | Manajemen Rekening | CRUD rekening (bank/cash/e-wallet/investasi); saldo otomatis dari transaksi |
| F07 | Transfer Antar Rekening | Transaksi tipe transfer yang menggerakkan saldo dua rekening sekaligus |

### 3.2 Advanced Features
| # | Fitur | Deskripsi |
|---|-------|-----------|
| F08 | Budget Planning | Tetapkan anggaran per kategori per bulan, alert 80%+ terpakai, salin dari bulan lalu |
| F09 | Laporan Analitik | Pie chart per kategori, bar chart tren bulanan, perbandingan multi-bulan, breakdown mingguan |
| F10 | Smart Insights | Top kategori terbesar, month-over-month change, savings rate |
| F11 | Ekspor CSV | Export transaksi ke file CSV per rentang tanggal |
| F12 | Input Massal | Form collapsible bulk entry — banyak transaksi dalam satu submit |
| F13 | Import CSV | Wizard 4-langkah: upload → mapping kolom → preview → import |
| F14 | Kalender Transaksi | Heatmap per hari, filter per rekening, statistik mingguan |
| F15 | Transaksi Berulang | Template recurring transaction (daily/weekly/monthly/yearly) |

---

## 4. Architecture

### Backend Architecture

```
cmd/server/main.go          → Entry point, router setup, server start
internal/
  config/config.go          → Load & validate env config
  middleware/
    auth.go                 → JWT validation middleware
    cors.go                 → CORS headers
  auth/                     → Register, Login, Refresh, Logout
  category/                 → CRUD category
  transaction/              → CRUD transaction + search + CSV export
  budget/                   → CRUD budget + usage calculation
  report/                   → Analytics queries + dashboard
pkg/
  database/postgres.go      → pgx connection pool
  response/response.go      → Standardized JSON response
  jwt/jwt.go                → Token generation & validation
migrations/                 → SQL migration files
```

### CMS Architecture (React Admin Panel)

```
cms/src/
  api/                        → Typed axios wrappers per resource
    client.ts                 → Axios instance + auth interceptor (auto-refresh)
    auth.ts / accounts.ts / categories.ts / transactions.ts / budgets.ts / reports.ts
  components/
    ui/                       → shadcn/ui component library
    shared/
      TransactionFormFields.tsx → Reusable form used by single + bulk dialogs
      DateInput.tsx
  pages/
    auth/LoginPage.tsx
    dashboard/DashboardPage.tsx
    accounts/AccountsPage.tsx
    categories/CategoriesPage.tsx
    transactions/
      TransactionsPage.tsx    → List + filter + single add/edit dialog
      BulkTransactionDialog.tsx → Collapsible card stack for bulk entry
    budgets/BudgetsPage.tsx   → Progress bars + copy-from-last-month
    reports/ReportsPage.tsx   → Monthly comparison + weekly breakdown
    calendar/CalendarPage.tsx → Heatmap + per-day transaction list
  lib/utils.ts
```

### Mobile Architecture (Feature-based Clean Architecture)

```
lib/
  main.dart                 → App entry, providers, routes, MainShell (BottomNav)
  core/
    constants/              → API URLs, colors, theme
    network/api_client.dart → Dio singleton + auto-refresh interceptor
    storage/                → Secure token storage
    utils/                  → Currency formatter, date utils (id_ID locale)
  features/
    auth/                   → Login, Register screens + AuthProvider
    dashboard/              → Home screen + DashboardProvider
    transaction/            → List, Add/Edit screens + TransactionProvider
    budget/                 → Budget setting + alerts + BudgetProvider
    report/                 → Bar chart + pie chart + ReportProvider
  shared/widgets/           → GradientCard, AppCard, CategoryIconWidget, StatusBadge
```

---

## 5. Design System

Warna utama (bisa dikustomisasi di `lib/core/constants/app_colors.dart`):

| Token | Default | Fungsi |
|-------|---------|--------|
| `primary` | `#6C5CE7` | Aksen utama, gradien header |
| `secondary` | `#00B4D8` | Gradien sekunder |
| `income` | `#00C49A` | Semua elemen terkait pemasukan |
| `expense` | `#FF6B6B` | Semua elemen terkait pengeluaran |
| `warning` | `#FFB300` | Budget 60-80% terpakai |
| `danger` | `#FF6B6B` | Budget 80-100% terpakai |
| `exceeded` | `#D63031` | Budget > 100% terpakai |
| `background` | `#F8F9FE` | Background halaman |

Font: **Nunito** (extrabold untuk angka, bold untuk heading, semibold untuk body)

---

## 6. API Design

Base URL: `http://localhost:8080/api/v1`

Semua endpoint kecuali `/auth/register`, `/auth/login`, `/auth/refresh` membutuhkan:
```
Authorization: Bearer <access_token>
```

Lihat `api-spec.md` untuk dokumentasi lengkap setiap endpoint.

---

## 7. Security

- Password di-hash dengan bcrypt (cost=12)
- Access token JWT expire 15 menit
- Refresh token expire 7 hari, disimpan di DB (whitelist)
- Token di-refresh otomatis di Flutter via Dio interceptor
- Semua data difilter per `user_id` di database layer
- CORS dikonfigurasi untuk semua origin (bisa di-restrict di production)

---

## 8. Development Setup

### Database (Docker)
```bash
docker run -d \
  --name money-manager-db \
  -e POSTGRES_USER=moneyuser \
  -e POSTGRES_PASSWORD=moneypass \
  -e POSTGRES_DB=moneymanager \
  -p 5432:5432 \
  postgres:15
```

### Backend
```bash
cd money-manager/backend
cp .env.example .env
# Edit .env: set JWT_SECRET dan DB credentials
go mod tidy
psql "host=localhost user=moneyuser password=moneypass dbname=moneymanager sslmode=disable" \
  -f migrations/001_init.sql \
  -f migrations/002_seed.sql \
  -f migrations/003_accounts.sql \
  -f migrations/004_transfer.sql
go run ./cmd/server
# Server running on :8080
```

### Mobile
```bash
cd money-manager/mobile
flutter pub get
# Edit lib/core/constants/api_constants.dart → baseUrl
flutter run
```

---

## 9. Kustomisasi

Untuk mengubah tampilan, edit file berikut:
- **Warna & gradien**: `lib/core/constants/app_colors.dart`
- **Typography & komponen**: `lib/core/constants/app_theme.dart`
- **URL backend**: `lib/core/constants/api_constants.dart`
- **Kategori default**: `backend/migrations/002_seed.sql`
