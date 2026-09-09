import {
  createContext,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react"
import { bn, en, type Messages } from "./messages"

type Locale = "bn" | "en"

const LocaleContext = createContext<{
  locale: Locale
  t: Messages
  setLocale: (l: Locale) => void
} | null>(null)

export function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocale] = useState<Locale>("bn")
  const value = useMemo(
    () => ({ locale, t: locale === "bn" ? bn : en, setLocale }),
    [locale],
  )
  return (
    <LocaleContext.Provider value={value}>{children}</LocaleContext.Provider>
  )
}

export function useT() {
  const ctx = useContext(LocaleContext)
  if (!ctx) throw new Error("LocaleProvider missing")
  return ctx
}
