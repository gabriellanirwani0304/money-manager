import { useRef, useState, useCallback } from 'react'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import { batchCreateTransactions } from '@/api/transactions'
import { type Category } from '@/api/categories'
import { type Account } from '@/api/accounts'
import {
  Upload, CheckCircle2, XCircle, AlertCircle, ChevronRight,
  ChevronLeft, FileText, Download,
} from 'lucide-react'
import { toast } from 'sonner'

// ── CSV parsing ─────────────────────────────────────────────────────────────

function detectDelimiter(text: string): string {
  const line = text.split('\n')[0] ?? ''
  const counts = { ',': 0, ';': 0, '\t': 0 }
  for (const ch of line) if (ch in counts) counts[ch as keyof typeof counts]++
  return Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0]
}

function parseCSV(text: string): { headers: string[]; rows: string[][] } {
  const delim = detectDelimiter(text)
  const lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n').filter(l => l.trim())
  if (lines.length === 0) return { headers: [], rows: [] }

  const parseLine = (line: string): string[] => {
    const fields: string[] = []
    let cur = '', inQ = false
    for (let i = 0; i < line.length; i++) {
      const ch = line[i]
      if (ch === '"') {
        if (inQ && line[i + 1] === '"') { cur += '"'; i++ }
        else inQ = !inQ
      } else if (ch === delim && !inQ) {
        fields.push(cur.trim()); cur = ''
      } else cur += ch
    }
    fields.push(cur.trim())
    return fields
  }

  const headers = parseLine(lines[0]).map(h => h.replace(/^"|"$/g, ''))
  const rows = lines.slice(1).map(parseLine)
  return { headers, rows }
}

// ── Date parsing ─────────────────────────────────────────────────────────────

function parseDate(val: string): string | null {
  if (!val) return null
  const s = val.trim()

  // YYYY-MM-DD
  if (/^\d{4}-\d{1,2}-\d{1,2}$/.test(s)) {
    const [y, m, d] = s.split('-').map(Number)
    return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`
  }
  // DD/MM/YYYY or DD-MM-YYYY
  if (/^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}$/.test(s)) {
    const parts = s.split(/[\/\-]/).map(Number)
    return `${parts[2]}-${String(parts[1]).padStart(2, '0')}-${String(parts[0]).padStart(2, '0')}`
  }
  // MM/DD/YYYY
  if (/^\d{1,2}\/\d{1,2}\/\d{4}$/.test(s)) {
    const [m, d, y] = s.split('/').map(Number)
    if (m <= 12) return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`
  }
  // ISO datetime
  const dt = new Date(s)
  if (!isNaN(dt.getTime())) {
    return dt.toISOString().slice(0, 10)
  }
  return null
}

// ── Amount parsing ───────────────────────────────────────────────────────────

function parseAmount(val: string): number | null {
  if (!val) return null
  // strip currency symbols, spaces, "Rp", "IDR"
  let s = val.replace(/[RrIiDd pP]+/g, '').replace(/\s/g, '').trim()
  const negative = s.startsWith('-')
  s = s.replace(/^[-+]/, '')
  // handle 1.000.000 (dot as thousand sep) vs 1,000,000
  // if last separator is ',' and length after it ≤ 2 → decimal comma (European)
  const lastComma = s.lastIndexOf(',')
  const lastDot = s.lastIndexOf('.')
  if (lastComma > lastDot) {
    // comma is decimal separator
    s = s.replace(/\./g, '').replace(',', '.')
  } else {
    // dot is decimal separator (or thousands)
    s = s.replace(/,/g, '')
  }
  const n = parseFloat(s)
  if (isNaN(n) || n < 0) return null
  return negative ? -n : n
}

// ── Type normalization ───────────────────────────────────────────────────────

function normalizeType(val: string): 'income' | 'expense' | 'transfer' | null {
  const v = val.toLowerCase().trim()
  if (['income', 'pemasukan', 'masuk', 'kredit', 'credit', 'in'].includes(v)) return 'income'
  if (['expense', 'pengeluaran', 'keluar', 'debit', 'out'].includes(v)) return 'expense'
  if (['transfer'].includes(v)) return 'transfer'
  return null
}

// ── Column field keys ────────────────────────────────────────────────────────

const FIELD_OPTIONS = [
  { value: 'date',         label: 'Tanggal' },
  { value: 'type',         label: 'Tipe' },
  { value: 'amount',       label: 'Jumlah' },
  { value: 'category',     label: 'Kategori (nama)' },
  { value: 'account',      label: 'Rekening (nama)' },
  { value: 'to_account',   label: 'Ke Rekening (nama)' },
  { value: 'description',  label: 'Catatan' },
  { value: '__skip',       label: '— Lewati —' },
]

function autoDetectMapping(headers: string[]): Record<string, string> {
  const map: Record<string, string> = {}
  const rules: [string[], string][] = [
    [['date', 'tanggal', 'tgl', 'waktu', 'time'], 'date'],
    [['type', 'tipe', 'jenis', 'kind'], 'type'],
    [['amount', 'jumlah', 'nominal', 'nilai', 'harga', 'total'], 'amount'],
    [['category', 'kategori', 'kat', 'cat'], 'category'],
    [['account', 'rekening', 'rek', 'akun', 'from_account', 'dari', 'from'], 'account'],
    [['to_account', 'to account', 'ke_rekening', 'ke rekening', 'tujuan', 'to'], 'to_account'],
    [['description', 'catatan', 'keterangan', 'desc', 'note', 'memo'], 'description'],
  ]
  for (const header of headers) {
    const h = header.toLowerCase().replace(/[^a-z0-9_]/g, ' ').trim()
    for (const [keywords, field] of rules) {
      if (keywords.some(k => h === k || h.includes(k))) {
        if (!Object.values(map).includes(field)) map[header] = field
        break
      }
    }
    if (!map[header]) map[header] = '__skip'
  }
  return map
}

// ── Row parsing & validation ─────────────────────────────────────────────────

interface ParsedRow {
  index: number
  raw: string[]
  date: string
  type: 'income' | 'expense' | 'transfer' | ''
  amount: number
  categoryId: string
  categoryName: string
  accountId: string
  accountName: string
  toAccountId: string
  toAccountName: string
  description: string
  errors: string[]
  warnings: string[]
  status: 'valid' | 'warning' | 'error'
}

function parseRows(
  rows: string[][],
  headers: string[],
  mapping: Record<string, string>,
  categories: Category[],
  accounts: Account[],
): ParsedRow[] {
  return rows.map((row, i) => {
    const get = (field: string): string => {
      const header = Object.entries(mapping).find(([, f]) => f === field)?.[0]
      if (!header) return ''
      const idx = headers.indexOf(header)
      return idx >= 0 ? (row[idx] ?? '').trim() : ''
    }

    const errors: string[] = []
    const warnings: string[] = []

    // Date
    const rawDate = get('date')
    const date = rawDate ? parseDate(rawDate) : ''
    if (!date) errors.push(`Tanggal tidak valid: "${rawDate}"`)

    // Type
    const rawType = get('type')
    let type: 'income' | 'expense' | 'transfer' | '' = normalizeType(rawType) ?? ''
    const rawAmountStr = get('amount')
    const rawAmount = parseAmount(rawAmountStr)

    // Infer type from amount sign if no type column
    if (!type && rawAmount !== null) {
      type = rawAmount < 0 ? 'expense' : 'income'
    }
    if (!type) errors.push(`Tipe tidak dikenali: "${rawType}"`)

    // Amount
    const amount = rawAmount !== null ? Math.abs(rawAmount) : 0
    if (rawAmount === null) errors.push(`Jumlah tidak valid: "${rawAmountStr}"`)
    else if (amount <= 0) errors.push('Jumlah harus lebih dari 0')

    // Category
    const rawCat = get('category')
    let categoryId = ''
    let categoryName = rawCat
    if (type !== 'transfer') {
      if (!rawCat) {
        errors.push('Kolom Kategori kosong')
      } else {
        const cat = categories.find(c => c.name.toLowerCase() === rawCat.toLowerCase())
        if (cat) categoryId = cat.id
        else warnings.push(`Kategori "${rawCat}" tidak ditemukan — akan dilewati`)
      }
    }

    // Account
    const rawAcc = get('account')
    let accountId = ''
    let accountName = rawAcc
    if (rawAcc) {
      const acc = accounts.find(a => a.name.toLowerCase() === rawAcc.toLowerCase())
      if (acc) accountId = acc.id
      else warnings.push(`Rekening "${rawAcc}" tidak ditemukan`)
    }

    // To Account (transfer)
    const rawToAcc = get('to_account')
    let toAccountId = ''
    let toAccountName = rawToAcc
    if (type === 'transfer' && rawToAcc) {
      const acc = accounts.find(a => a.name.toLowerCase() === rawToAcc.toLowerCase())
      if (acc) toAccountId = acc.id
      else warnings.push(`Rekening tujuan "${rawToAcc}" tidak ditemukan`)
    }

    const description = get('description')

    const status: ParsedRow['status'] = errors.length > 0
      ? 'error'
      : warnings.length > 0 ? 'warning' : 'valid'

    return {
      index: i,
      raw: row,
      date: date ?? '',
      type,
      amount,
      categoryId,
      categoryName,
      accountId,
      accountName,
      toAccountId,
      toAccountName,
      description,
      errors,
      warnings,
      status,
    }
  })
}

// ── Component ─────────────────────────────────────────────────────────────────

interface Props {
  open: boolean
  onClose: () => void
  categories: Category[]
  accounts: Account[]
  onImported: () => void
}

type Step = 'upload' | 'map' | 'preview' | 'result'

interface ImportResult { imported: number; failed: number; errors: { index: number; message: string }[] }

const rp = (n: number) =>
  new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(n)

export default function ImportDialog({ open, onClose, categories, accounts, onImported }: Props) {
  const [step, setStep] = useState<Step>('upload')
  const [fileName, setFileName] = useState('')
  const [headers, setHeaders] = useState<string[]>([])
  const [rawRows, setRawRows] = useState<string[][]>([])
  const [mapping, setMapping] = useState<Record<string, string>>({})
  const [parsedRows, setParsedRows] = useState<ParsedRow[]>([])
  const [importing, setImporting] = useState(false)
  const [progress, setProgress] = useState(0)
  const [result, setResult] = useState<ImportResult | null>(null)
  const [dragOver, setDragOver] = useState(false)
  const [expandError, setExpandError] = useState<number | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  const reset = () => {
    setStep('upload'); setFileName(''); setHeaders([]); setRawRows([])
    setMapping({}); setParsedRows([]); setImporting(false); setProgress(0)
    setResult(null); setExpandError(null)
  }

  const handleClose = () => { reset(); onClose() }

  const loadFile = useCallback((file: File) => {
    if (!file.name.match(/\.(csv|tsv|txt)$/i)) {
      toast.error('Format file tidak didukung. Gunakan .csv atau .tsv'); return
    }
    const reader = new FileReader()
    reader.onload = e => {
      const text = e.target?.result as string
      const { headers: h, rows } = parseCSV(text)
      if (h.length === 0) { toast.error('File kosong atau format tidak dikenali'); return }
      setFileName(file.name)
      setHeaders(h)
      setRawRows(rows)
      setMapping(autoDetectMapping(h))
      setStep('map')
    }
    reader.readAsText(file, 'UTF-8')
  }, [])

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault(); setDragOver(false)
    const file = e.dataTransfer.files[0]
    if (file) loadFile(file)
  }, [loadFile])

  const toPreview = () => {
    const parsed = parseRows(rawRows, headers, mapping, categories, accounts)
    setParsedRows(parsed)
    setStep('preview')
  }

  const handleImport = async () => {
    const valid = parsedRows.filter(r => r.status !== 'error')
    if (valid.length === 0) { toast.error('Tidak ada baris yang valid untuk diimpor'); return }

    setImporting(true)
    setProgress(0)

    const txs = valid.map(r => ({
      date: r.date,
      type: r.type as 'income' | 'expense' | 'transfer',
      amount: r.amount,
      category_id: r.categoryId,
      account_id: r.accountId,
      to_account_id: r.toAccountId,
      description: r.description,
    }))

    // Simulate progress during upload
    const progressInterval = setInterval(() => setProgress(p => Math.min(p + 5, 90)), 200)

    try {
      const res = await batchCreateTransactions(txs)
      clearInterval(progressInterval)
      setProgress(100)
      setResult(res.data.data)
      setStep('result')
      onImported()
    } catch {
      clearInterval(progressInterval)
      toast.error('Gagal mengimpor transaksi')
    } finally {
      setImporting(false)
    }
  }

  const downloadErrors = () => {
    if (!result) return
    const errorRows = result.errors.map(e => {
      const parsed = parsedRows[e.index]
      return [String(e.index + 1), parsed?.date ?? '', String(parsed?.amount ?? ''), e.message].join(',')
    })
    const csv = ['Index,Date,Amount,Error', ...errorRows].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url; a.download = 'import_errors.csv'; a.click()
    URL.revokeObjectURL(url)
  }

  const validCount = parsedRows.filter(r => r.status !== 'error').length
  const errorCount = parsedRows.filter(r => r.status === 'error').length
  const warnCount = parsedRows.filter(r => r.status === 'warning').length

  const STEPS: Step[] = ['upload', 'map', 'preview', 'result']
  const stepLabel: Record<Step, string> = { upload: 'Upload', map: 'Pemetaan', preview: 'Preview', result: 'Selesai' }

  return (
    <Dialog open={open} onOpenChange={v => !v && handleClose()}>
      <DialogContent className="max-w-4xl max-h-[90vh] flex flex-col">
        <DialogHeader>
          <DialogTitle>Import Transaksi dari CSV</DialogTitle>
        </DialogHeader>

        {/* Step indicator */}
        <div className="flex items-center gap-1 text-xs">
          {STEPS.map((s, i) => (
            <span key={s} className="flex items-center gap-1">
              <span className={`px-2 py-0.5 rounded-full ${step === s ? 'bg-primary text-primary-foreground' : STEPS.indexOf(step) > i ? 'bg-primary/20 text-primary' : 'bg-muted text-muted-foreground'}`}>
                {stepLabel[s]}
              </span>
              {i < STEPS.length - 1 && <ChevronRight size={12} className="text-muted-foreground" />}
            </span>
          ))}
          {fileName && <span className="ml-auto text-muted-foreground truncate max-w-[200px]">{fileName}</span>}
        </div>

        <div className="flex-1 overflow-y-auto min-h-0">

          {/* ── Step 1: Upload ───────────────────────────────────────────── */}
          {step === 'upload' && (
            <div className="space-y-4">
              <div
                className={`border-2 border-dashed rounded-xl p-12 flex flex-col items-center gap-3 cursor-pointer transition-colors ${dragOver ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50'}`}
                onDragOver={e => { e.preventDefault(); setDragOver(true) }}
                onDragLeave={() => setDragOver(false)}
                onDrop={handleDrop}
                onClick={() => fileRef.current?.click()}
              >
                <Upload size={36} className={dragOver ? 'text-primary' : 'text-muted-foreground'} />
                <div className="text-center">
                  <p className="font-medium">{dragOver ? 'Lepaskan file di sini' : 'Drag & drop file CSV'}</p>
                  <p className="text-sm text-muted-foreground mt-1">atau klik untuk pilih file</p>
                </div>
                <Button size="sm" variant="outline" type="button">Pilih File</Button>
                <input ref={fileRef} type="file" accept=".csv,.tsv,.txt" className="hidden"
                  onChange={e => e.target.files?.[0] && loadFile(e.target.files[0])} />
              </div>

              <div className="rounded-lg border bg-muted/30 p-4 space-y-2">
                <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">Format yang didukung</p>
                <div className="text-xs text-muted-foreground space-y-1">
                  <p>• Delimiter: koma (,) · titik koma (;) · tab — auto-detect</p>
                  <p>• Format tanggal: YYYY-MM-DD · DD/MM/YYYY · DD-MM-YYYY</p>
                  <p>• Jumlah: angka biasa, prefix Rp/IDR, titik ribuan (1.000.000 atau 1,000,000)</p>
                  <p>• Tipe: income/pemasukan · expense/pengeluaran · transfer</p>
                  <p>• Jumlah negatif otomatis dianggap pengeluaran jika kolom tipe tidak ada</p>
                </div>
                <div className="mt-3 pt-3 border-t text-xs">
                  <p className="font-medium mb-1">Contoh format CSV:</p>
                  <pre className="bg-muted rounded p-2 text-[11px] leading-relaxed overflow-x-auto">
{`Date,Type,Category,Account,Amount,Description
2026-06-01,expense,Makanan,BCA,15000,Makan siang
2026-06-02,income,Gaji,,5000000,Gaji Juni
2026-06-03,transfer,,BCA,GoPay,100000,Top up`}
                  </pre>
                </div>
              </div>
            </div>
          )}

          {/* ── Step 2: Map columns ──────────────────────────────────────── */}
          {step === 'map' && (
            <div className="space-y-4">
              <p className="text-sm text-muted-foreground">
                Cocokkan kolom CSV ke field transaksi. Sistem sudah mendeteksi otomatis berdasarkan nama kolom.
              </p>
              <div className="rounded-lg border overflow-hidden">
                <table className="w-full text-sm">
                  <thead className="bg-muted/50">
                    <tr>
                      <th className="text-left p-3 font-medium w-1/3">Kolom CSV</th>
                      <th className="text-left p-3 font-medium w-1/4">Contoh data</th>
                      <th className="text-left p-3 font-medium">Field transaksi</th>
                    </tr>
                  </thead>
                  <tbody>
                    {headers.map((h, i) => (
                      <tr key={h} className="border-t">
                        <td className="p-3 font-mono text-xs font-medium">{h}</td>
                        <td className="p-3 text-xs text-muted-foreground truncate max-w-[120px]">
                          {rawRows.slice(0, 3).map(r => r[i]).filter(Boolean).join(' / ') || '—'}
                        </td>
                        <td className="p-3">
                          <Select value={mapping[h] ?? '__skip'} onValueChange={v => setMapping(m => ({ ...m, [h]: v ?? '__skip' }))}>
                            <SelectTrigger className="h-8 text-xs">
                              <SelectValue>{FIELD_OPTIONS.find(o => o.value === (mapping[h] ?? '__skip'))?.label}</SelectValue>
                            </SelectTrigger>
                            <SelectContent>
                              {FIELD_OPTIONS.map(o => (
                                <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p className="text-xs text-muted-foreground">
                {rawRows.length} baris data ditemukan · {Object.values(mapping).filter(v => v !== '__skip').length} kolom dipetakan
              </p>
            </div>
          )}

          {/* ── Step 3: Preview ──────────────────────────────────────────── */}
          {step === 'preview' && (
            <div className="space-y-3">
              {/* Summary chips */}
              <div className="flex gap-2 flex-wrap">
                <Badge variant="default" className="gap-1">
                  <CheckCircle2 size={12} /> {validCount} valid
                </Badge>
                {warnCount > 0 && (
                  <Badge variant="outline" className="gap-1 border-yellow-400 text-yellow-600">
                    <AlertCircle size={12} /> {warnCount} peringatan
                  </Badge>
                )}
                {errorCount > 0 && (
                  <Badge variant="destructive" className="gap-1">
                    <XCircle size={12} /> {errorCount} error (dilewati)
                  </Badge>
                )}
                <span className="text-xs text-muted-foreground ml-1 self-center">
                  Total {parsedRows.length} baris
                </span>
              </div>

              {/* Preview table */}
              <div className="rounded-lg border overflow-auto max-h-[380px]">
                <table className="w-full text-xs min-w-[700px]">
                  <thead className="bg-muted/50 sticky top-0">
                    <tr>
                      <th className="text-left p-2 font-medium w-8">#</th>
                      <th className="text-left p-2 font-medium">Tanggal</th>
                      <th className="text-left p-2 font-medium">Tipe</th>
                      <th className="text-left p-2 font-medium">Jumlah</th>
                      <th className="text-left p-2 font-medium">Kategori</th>
                      <th className="text-left p-2 font-medium">Rekening</th>
                      <th className="text-left p-2 font-medium">Catatan</th>
                      <th className="text-left p-2 font-medium">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {parsedRows.map(r => (
                      <tr key={r.index}
                        className={`border-t cursor-pointer ${r.status === 'error' ? 'bg-red-50 dark:bg-red-950/20' : r.status === 'warning' ? 'bg-yellow-50 dark:bg-yellow-950/10' : ''}`}
                        onClick={() => setExpandError(expandError === r.index ? null : r.index)}
                      >
                        <td className="p-2 text-muted-foreground">{r.index + 1}</td>
                        <td className="p-2">{r.date || <span className="text-red-500">—</span>}</td>
                        <td className="p-2">
                          {r.type
                            ? <Badge variant={r.type === 'income' ? 'default' : r.type === 'transfer' ? 'outline' : 'secondary'} className="text-[10px] py-0">
                                {r.type === 'income' ? 'Masuk' : r.type === 'expense' ? 'Keluar' : 'Transfer'}
                              </Badge>
                            : <span className="text-red-500">—</span>}
                        </td>
                        <td className={`p-2 tabular-nums ${r.type === 'income' ? 'text-green-600' : r.type === 'transfer' ? 'text-blue-600' : 'text-red-600'}`}>
                          {r.amount > 0 ? rp(r.amount) : <span className="text-red-500">—</span>}
                        </td>
                        <td className="p-2">
                          {r.categoryId
                            ? <span className="text-green-600">{r.categoryName}</span>
                            : r.categoryName
                              ? <span className="text-yellow-600">{r.categoryName}?</span>
                              : r.type !== 'transfer' ? <span className="text-muted-foreground">—</span> : null}
                        </td>
                        <td className="p-2">
                          {r.accountId
                            ? <span>{r.accountName}</span>
                            : r.accountName
                              ? <span className="text-yellow-600">{r.accountName}?</span>
                              : <span className="text-muted-foreground">—</span>}
                        </td>
                        <td className="p-2 max-w-[120px] truncate text-muted-foreground">{r.description || '—'}</td>
                        <td className="p-2">
                          {r.status === 'valid' && <CheckCircle2 size={14} className="text-green-500" />}
                          {r.status === 'warning' && <AlertCircle size={14} className="text-yellow-500" />}
                          {r.status === 'error' && <XCircle size={14} className="text-red-500" />}
                        </td>
                      </tr>
                    ))}
                    {parsedRows.length === 0 && (
                      <tr><td colSpan={8} className="p-4 text-center text-muted-foreground">Tidak ada data</td></tr>
                    )}
                  </tbody>
                </table>
              </div>

              {/* Expanded error detail */}
              {expandError !== null && parsedRows[expandError] && (
                <div className={`rounded-lg p-3 text-xs space-y-1 ${parsedRows[expandError].status === 'error' ? 'bg-red-50 dark:bg-red-950/20 border border-red-200 dark:border-red-800' : 'bg-yellow-50 dark:bg-yellow-950/20 border border-yellow-200 dark:border-yellow-800'}`}>
                  <p className="font-medium">Baris {expandError + 1}:</p>
                  {parsedRows[expandError].errors.map((e, i) => (
                    <p key={i} className="text-red-600 flex items-start gap-1"><XCircle size={11} className="mt-0.5 shrink-0" /> {e}</p>
                  ))}
                  {parsedRows[expandError].warnings.map((w, i) => (
                    <p key={i} className="text-yellow-600 flex items-start gap-1"><AlertCircle size={11} className="mt-0.5 shrink-0" /> {w}</p>
                  ))}
                </div>
              )}
              <p className="text-xs text-muted-foreground">Klik baris untuk lihat detail · Baris error tidak akan diimpor</p>
            </div>
          )}

          {/* ── Step 4: Result ───────────────────────────────────────────── */}
          {step === 'result' && result && (
            <div className="space-y-4 py-4">
              {importing ? (
                <div className="space-y-3">
                  <p className="text-sm text-center text-muted-foreground">Mengimpor transaksi...</p>
                  <div className="w-full bg-muted rounded-full h-2">
                    <div className="bg-primary h-2 rounded-full transition-all duration-200" style={{ width: `${progress}%` }} />
                  </div>
                  <p className="text-xs text-center text-muted-foreground">{progress}%</p>
                </div>
              ) : (
                <>
                  <div className="flex flex-col items-center gap-2 py-4">
                    <CheckCircle2 size={48} className="text-green-500" />
                    <h3 className="text-lg font-semibold">Import Selesai</h3>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div className="rounded-xl border bg-green-50 dark:bg-green-950/20 p-4 text-center">
                      <p className="text-2xl font-bold text-green-600">{result.imported}</p>
                      <p className="text-sm text-muted-foreground mt-1">Berhasil diimpor</p>
                    </div>
                    <div className={`rounded-xl border p-4 text-center ${result.failed > 0 ? 'bg-red-50 dark:bg-red-950/20' : 'bg-muted/30'}`}>
                      <p className={`text-2xl font-bold ${result.failed > 0 ? 'text-red-500' : 'text-muted-foreground'}`}>{result.failed}</p>
                      <p className="text-sm text-muted-foreground mt-1">Gagal</p>
                    </div>
                  </div>
                  {result.failed > 0 && (
                    <div className="space-y-2">
                      <div className="rounded-lg border bg-red-50 dark:bg-red-950/20 p-3 max-h-[150px] overflow-y-auto space-y-1">
                        {result.errors.map((e, i) => (
                          <p key={i} className="text-xs text-red-600">Baris {e.index + 1}: {e.message}</p>
                        ))}
                      </div>
                      <Button size="sm" variant="outline" onClick={downloadErrors} className="gap-1">
                        <Download size={14} /> Download error report
                      </Button>
                    </div>
                  )}
                </>
              )}
            </div>
          )}

        </div>

        {/* ── Footer ───────────────────────────────────────────────────── */}
        <DialogFooter className="border-t pt-3 mt-0">
          {step === 'upload' && (
            <Button variant="outline" onClick={handleClose}>Batal</Button>
          )}
          {step === 'map' && (
            <>
              <Button variant="outline" onClick={() => setStep('upload')}><ChevronLeft size={14} className="mr-1" /> Kembali</Button>
              <Button onClick={toPreview} disabled={!Object.values(mapping).some(v => v !== '__skip')}>
                Preview <ChevronRight size={14} className="ml-1" />
              </Button>
            </>
          )}
          {step === 'preview' && (
            <>
              <Button variant="outline" onClick={() => setStep('map')}><ChevronLeft size={14} className="mr-1" /> Kembali</Button>
              <div className="flex items-center gap-2">
                {importing && (
                  <div className="flex items-center gap-2 mr-2">
                    <div className="w-24 bg-muted rounded-full h-1.5">
                      <div className="bg-primary h-1.5 rounded-full transition-all" style={{ width: `${progress}%` }} />
                    </div>
                    <span className="text-xs text-muted-foreground">{progress}%</span>
                  </div>
                )}
                <Button onClick={handleImport} disabled={importing || validCount === 0} className="gap-1">
                  <FileText size={14} />
                  {importing ? 'Mengimpor...' : `Import ${validCount} Transaksi`}
                </Button>
              </div>
            </>
          )}
          {step === 'result' && (
            <>
              <Button variant="outline" onClick={handleClose}>Tutup</Button>
              {result && result.failed > 0 && (
                <Button variant="outline" onClick={() => { reset() }}>Import Lagi</Button>
              )}
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
