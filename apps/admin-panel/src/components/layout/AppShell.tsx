import { NavLink, Outlet, useNavigate } from "react-router-dom"
import {
  LayoutDashboard,
  Map,
  ShieldAlert,
  Car,
  Route,
  Users,
  Wallet,
  Tags,
  Settings,
} from "lucide-react"
import { useT } from "../../i18n/LocaleProvider"
import { api, envName, store } from "../../api/client"
import { SosBanner } from "../sos/SosBanner"

const links = [
  { to: "/", key: "dashboard" as const, icon: LayoutDashboard },
  { to: "/map", key: "liveMap" as const, icon: Map },
  { to: "/sos", key: "sos" as const, icon: ShieldAlert },
  { to: "/drivers", key: "drivers" as const, icon: Car },
  { to: "/rides", key: "rides" as const, icon: Route },
  { to: "/users", key: "users" as const, icon: Users },
  { to: "/finance", key: "finance" as const, icon: Wallet },
  { to: "/pricing", key: "pricing" as const, icon: Tags },
  { to: "/settings", key: "settings" as const, icon: Settings },
]

export function AppShell() {
  const { t, locale, setLocale } = useT()
  const nav = useNavigate()
  const sosCount = store.sos.length

  async function logout() {
    await api("/auth/logout", { method: "POST" })
    nav("/login")
  }

  return (
    <div className="flex min-h-svh">
      <aside className="flex w-[240px] shrink-0 flex-col bg-[var(--interactive-primary)] text-[var(--text-on-primary)]">
        <div className="px-[16px] py-[24px] text-[18px] font-medium">{t.brand}</div>
        <nav className="flex flex-1 flex-col gap-[4px] px-[8px]">
          {links.map((l) => (
            <NavLink
              key={l.to}
              to={l.to}
              end={l.to === "/"}
              className={({ isActive }) =>
                `flex min-h-[44px] items-center gap-[12px] rounded-[8px] px-[12px] text-[16px] ${
                  isActive
                    ? "border-l-4 border-[var(--interactive-accent)] bg-[var(--navy-800)]"
                    : "border-l-4 border-transparent"
                }`
              }
            >
              <l.icon size={18} />
              <span>{t[l.key]}</span>
              {l.to === "/sos" && sosCount > 0 ? (
                <span className="ml-auto h-[8px] w-[8px] rounded-full bg-[var(--danger)]" />
              ) : null}
            </NavLink>
          ))}
        </nav>
      </aside>
      <div className="flex min-w-0 flex-1 flex-col">
        <SosBanner />
        <header className="flex h-[56px] items-center justify-between border-b border-[var(--border-default)] bg-[var(--surface)] px-[24px]">
          <span className="rounded-[8px] bg-[var(--warning-bg)] px-[8px] py-[4px] text-[12px] font-medium text-[var(--warning)]">
            {envName()}
          </span>
          <div className="flex items-center gap-[16px]">
            <button
              type="button"
              className="min-h-[44px] text-[14px] font-medium"
              onClick={() => setLocale(locale === "bn" ? "en" : "bn")}
            >
              {locale === "bn" ? "English" : "বাংলা"}
            </button>
            <button type="button" className="min-h-[44px] text-[14px]" onClick={() => void logout()}>
              {t.logout}
            </button>
          </div>
        </header>
        <main className="flex-1 overflow-auto p-[24px]">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
