import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '@/hooks/useAuth'
import { Separator } from '@/components/ui/separator'
import { Button } from '@/components/ui/button'
import {
  LayoutDashboard,
  ArrowLeftRight,
  Tag,
  PiggyBank,
  Wallet,
  BarChart2,
  CalendarDays,
  LogOut,
} from 'lucide-react'
import { useTheme } from '@/context/ThemeContext'
import { THEMES } from '@/lib/themes'

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/transactions', label: 'Transaksi', icon: ArrowLeftRight },
  { to: '/calendar', label: 'Kalender', icon: CalendarDays },
  { to: '/categories', label: 'Kategori', icon: Tag },
  { to: '/budgets', label: 'Anggaran', icon: PiggyBank },
  { to: '/accounts', label: 'Rekening', icon: Wallet },
  { to: '/reports', label: 'Laporan', icon: BarChart2 },
]

export default function Sidebar() {
  const { logout } = useAuth()
  const navigate = useNavigate()
  const { theme, setTheme } = useTheme()

  const handleLogout = async () => {
    await logout()
    navigate('/login')
  }

  return (
    <aside className="flex h-screen w-56 flex-col border-r bg-card px-3 py-4">
      <div className="mb-4 px-2">
        <h1 className="text-lg font-bold">MoneyMate CMS</h1>
        <p className="text-xs text-muted-foreground">Admin Panel</p>
      </div>
      <Separator className="mb-3" />
      <nav className="flex flex-1 flex-col gap-1">
        {navItems.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            className={({ isActive }) =>
              `flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors ${
                isActive
                  ? 'bg-primary text-primary-foreground'
                  : 'text-muted-foreground hover:bg-muted hover:text-foreground'
              }`
            }
          >
            <Icon size={16} />
            {label}
          </NavLink>
        ))}
      </nav>
      <Separator className="my-3" />
      <div className="px-2 mb-3">
        <p className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground mb-2">Tema</p>
        <div className="flex gap-2 flex-wrap">
          {THEMES.map(t => (
            <button
              key={t.id}
              title={`${t.emoji} ${t.label}`}
              onClick={() => setTheme(t.id)}
              className={`w-6 h-6 rounded-full transition-all hover:scale-110 ${
                theme === t.id
                  ? 'ring-2 ring-offset-2 ring-foreground scale-110'
                  : 'opacity-70 hover:opacity-100'
              }`}
              style={{ background: t.preview }}
            />
          ))}
        </div>
        <p className="text-[10px] text-muted-foreground mt-1.5">
          {THEMES.find(t => t.id === theme)?.emoji} {THEMES.find(t => t.id === theme)?.label}
        </p>
      </div>
      <Separator className="mb-3" />
      <Button variant="ghost" size="sm" className="justify-start gap-2" onClick={handleLogout}>
        <LogOut size={16} />
        Keluar
      </Button>
    </aside>
  )
}
