# Money Manager — API Specification

Base URL: `http://localhost:8080/api/v1`

Semua request yang membutuhkan autentikasi harus menyertakan header:
```
Authorization: Bearer <access_token>
```

Semua response dalam format JSON:
```json
{ "success": true, "data": {}, "message": "" }
{ "success": false, "error": "pesan error", "code": "ERROR_CODE" }
```

---

## Auth

### POST /auth/register
Daftarkan akun baru.

**Request Body:**
```json
{
  "name": "Budi Santoso",
  "email": "budi@example.com",
  "password": "Password123!",
  "currency": "IDR"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "user": { "id": "uuid", "name": "Budi Santoso", "email": "budi@example.com", "currency": "IDR" },
    "access_token": "eyJ...",
    "refresh_token": "eyJ..."
  }
}
```

**Errors:** `400` invalid input | `409` email sudah terdaftar

---

### POST /auth/login
Login dan dapatkan token.

**Request Body:**
```json
{ "email": "budi@example.com", "password": "Password123!" }
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "user": { "id": "uuid", "name": "Budi Santoso", "email": "budi@example.com", "currency": "IDR" },
    "access_token": "eyJ...",
    "refresh_token": "eyJ..."
  }
}
```

**Errors:** `400` | `401` email/password salah

---

### POST /auth/refresh
Perbarui access token menggunakan refresh token.

**Request Body:**
```json
{ "refresh_token": "eyJ..." }
```

**Response 200:**
```json
{
  "success": true,
  "data": { "access_token": "eyJ...", "refresh_token": "eyJ..." }
}
```

---

### POST /auth/logout
Invalidasi refresh token. Membutuhkan autentikasi.

**Request Body:**
```json
{ "refresh_token": "eyJ..." }
```

**Response 200:**
```json
{ "success": true, "message": "Logged out successfully" }
```

---

## Dashboard

### GET /dashboard
Ringkasan lengkap untuk halaman utama. Membutuhkan autentikasi.

**Query Params:**
- `month` (int, optional, default: bulan ini)
- `year` (int, optional, default: tahun ini)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "balance": 5250000,
    "income": 8000000,
    "expense": 2750000,
    "recent_transactions": [
      {
        "id": "uuid",
        "type": "expense",
        "amount": 85000,
        "description": "Makan siang",
        "date": "2026-06-28",
        "category": { "id": "uuid", "name": "Makanan", "icon": "restaurant", "color": "#EF4444" }
      }
    ],
    "budget_alerts": [
      {
        "category_name": "Belanja",
        "budget_amount": 500000,
        "spent": 430000,
        "percentage": 86.0
      }
    ],
    "top_expenses": [
      { "category_name": "Makanan", "amount": 1200000, "percentage": 43.6 }
    ]
  }
}
```

---

## Categories

### GET /categories
List semua kategori (global default + milik user).

**Query Params:**
- `type` (string, optional): `income` | `expense`

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "name": "Makanan",
      "type": "expense",
      "icon": "restaurant",
      "color": "#EF4444",
      "is_default": true
    }
  ]
}
```

---

### POST /categories
Buat kategori custom.

**Request Body:**
```json
{
  "name": "Hobi Gaming",
  "type": "expense",
  "icon": "sports_esports",
  "color": "#7C3AED"
}
```

**Response 201:**
```json
{ "success": true, "data": { "id": "uuid", "name": "Hobi Gaming", ... } }
```

**Errors:** `400` | `409` nama sudah ada

---

### PUT /categories/:id
Update kategori. Hanya kategori milik user (bukan default).

**Request Body:**
```json
{ "name": "Gaming", "icon": "gamepad", "color": "#8B5CF6" }
```

**Response 200:** data kategori terbaru

---

### DELETE /categories/:id
Hapus kategori. Hanya kategori milik user yang tidak memiliki transaksi.

**Response 200:**
```json
{ "success": true, "message": "Category deleted" }
```

**Errors:** `400` kategori punya transaksi | `403` kategori default tidak bisa dihapus

---

## Transactions

### GET /transactions
List transaksi dengan pagination dan filter.

**Query Params:**
| Param | Type | Default | Keterangan |
|-------|------|---------|------------|
| page | int | 1 | Halaman |
| limit | int | 20 | Per halaman (max 100) |
| type | string | - | `income` \| `expense` |
| category_id | uuid | - | Filter kategori |
| start_date | date | - | Format: YYYY-MM-DD |
| end_date | date | - | Format: YYYY-MM-DD |
| search | string | - | Cari di deskripsi |
| sort | string | date_desc | `date_asc` \| `date_desc` \| `amount_asc` \| `amount_desc` |

**Response 200:**
```json
{
  "success": true,
  "data": {
    "transactions": [
      {
        "id": "uuid",
        "type": "expense",
        "amount": 85000,
        "description": "Makan siang padang",
        "date": "2026-06-28",
        "category": { "id": "uuid", "name": "Makanan", "icon": "restaurant", "color": "#EF4444" },
        "created_at": "2026-06-28T10:30:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 125,
      "total_pages": 7
    },
    "summary": {
      "total_income": 8000000,
      "total_expense": 2750000
    }
  }
}
```

---

### POST /transactions
Catat transaksi baru.

**Request Body:**
```json
{
  "category_id": "uuid",
  "type": "expense",
  "amount": 85000,
  "description": "Makan siang padang",
  "date": "2026-06-28"
}
```

**Response 201:** data transaksi lengkap

**Errors:** `400` | `404` category tidak ditemukan

---

### GET /transactions/:id
Detail satu transaksi.

**Response 200:** data transaksi lengkap

---

### PUT /transactions/:id
Update transaksi.

**Request Body:** sama dengan POST (semua field optional)

**Response 200:** data transaksi terbaru

---

### DELETE /transactions/:id
Hapus transaksi.

**Response 200:**
```json
{ "success": true, "message": "Transaction deleted" }
```

---

### GET /transactions/export
Export transaksi ke CSV.

**Query Params:**
- `start_date` (required): YYYY-MM-DD
- `end_date` (required): YYYY-MM-DD
- `type` (optional): `income` | `expense`

**Response 200:**
- Content-Type: `text/csv`
- Content-Disposition: `attachment; filename="transactions_2026-06.csv"`

**CSV Format:**
```
Date,Type,Category,Amount,Description
2026-06-28,expense,Makanan,85000,Makan siang padang
```

---

## Budgets

### GET /budgets
List budget beserta status pemakaian bulan ini.

**Query Params:**
- `month` (int, default: bulan ini)
- `year` (int, default: tahun ini)

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "category": { "id": "uuid", "name": "Makanan", "icon": "restaurant", "color": "#EF4444" },
      "budget_amount": 1500000,
      "spent": 1200000,
      "remaining": 300000,
      "percentage": 80.0,
      "status": "warning",
      "month": 6,
      "year": 2026
    }
  ]
}
```

Status: `safe` (<60%) | `warning` (60-80%) | `danger` (>80%) | `exceeded` (>100%)

---

### POST /budgets
Set budget untuk kategori di bulan tertentu.

**Request Body:**
```json
{
  "category_id": "uuid",
  "amount": 1500000,
  "month": 6,
  "year": 2026
}
```

**Response 201:** data budget

---

### PUT /budgets/:id
Update nominal budget.

**Request Body:**
```json
{ "amount": 2000000 }
```

**Response 200:** data budget terbaru

---

### DELETE /budgets/:id
Hapus budget.

**Response 200:**
```json
{ "success": true, "message": "Budget deleted" }
```

---

## Reports

### GET /reports/summary
Total income, expense, dan balance untuk periode tertentu.

**Query Params:**
- `month` (int, required)
- `year` (int, required)

**Response 200:**
```json
{
  "success": true,
  "data": {
    "month": 6,
    "year": 2026,
    "income": 8000000,
    "expense": 2750000,
    "balance": 5250000,
    "transaction_count": 45,
    "avg_daily_expense": 91666.67
  }
}
```

---

### GET /reports/monthly
Tren income dan expense 6 bulan terakhir.

**Response 200:**
```json
{
  "success": true,
  "data": [
    { "month": "2026-01", "income": 7500000, "expense": 3200000 },
    { "month": "2026-02", "income": 7500000, "expense": 2800000 },
    { "month": "2026-03", "income": 8000000, "expense": 3100000 },
    { "month": "2026-04", "income": 7500000, "expense": 2950000 },
    { "month": "2026-05", "income": 8000000, "expense": 2600000 },
    { "month": "2026-06", "income": 8000000, "expense": 2750000 }
  ]
}
```

---

### GET /reports/by-category
Breakdown pengeluaran/pemasukan per kategori dalam satu bulan.

**Query Params:**
- `month` (int, required)
- `year` (int, required)
- `type` (string, required): `income` | `expense`

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "category": { "id": "uuid", "name": "Makanan", "icon": "restaurant", "color": "#EF4444" },
      "amount": 1200000,
      "count": 18,
      "percentage": 43.6
    }
  ]
}
```

---

### GET /reports/insights
Smart insights: deteksi pola dan anomali pengeluaran.

**Response 200:**
```json
{
  "success": true,
  "data": {
    "top_expense_category": {
      "category_name": "Makanan",
      "amount": 1200000,
      "percentage": 43.6
    },
    "biggest_single_expense": {
      "amount": 850000,
      "description": "Belanja bulanan",
      "date": "2026-06-15",
      "category_name": "Belanja"
    },
    "month_over_month": {
      "expense_change_percent": -5.5,
      "income_change_percent": 6.7,
      "trend": "improving"
    },
    "budget_exceeded_categories": ["Belanja", "Hiburan"],
    "savings_rate": 65.6
  }
}
```

---

## Recurring Transactions

### GET /recurring
List semua transaksi berulang.

**Response 200:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "category": { "name": "Gaji", "icon": "work", "color": "#22C55E" },
      "type": "income",
      "amount": 8000000,
      "description": "Gaji bulanan",
      "frequency": "monthly",
      "next_date": "2026-07-01",
      "is_active": true
    }
  ]
}
```

---

### POST /recurring
Buat transaksi berulang.

**Request Body:**
```json
{
  "category_id": "uuid",
  "type": "income",
  "amount": 8000000,
  "description": "Gaji bulanan",
  "frequency": "monthly",
  "next_date": "2026-07-01"
}
```

**Response 201:** data recurring transaction

---

### PUT /recurring/:id
Update atau pause/resume recurring transaction.

**Request Body:**
```json
{
  "amount": 9000000,
  "is_active": false
}
```

---

### DELETE /recurring/:id
Hapus template recurring.

**Response 200:**
```json
{ "success": true, "message": "Recurring transaction deleted" }
```

### POST /recurring/:id/execute
Eksekusi manual (generate transaksi sekarang dan update next_date).

**Response 201:** data transaksi yang dibuat
