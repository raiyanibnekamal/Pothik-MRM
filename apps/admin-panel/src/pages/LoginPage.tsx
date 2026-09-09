import { useState, type FormEvent } from "react"
import { Navigate, useNavigate } from "react-router-dom"
import { api, getToken } from "../api/client"
import { PrimaryButton, Field } from "../components/ui/Ui"
import { useT } from "../i18n/LocaleProvider"

export function LoginPage() {
  const { t } = useT()
  const nav = useNavigate()
  const [email, setEmail] = useState("0152170004")
  const [password, setPassword] = useState("123456")
  const [error, setError] = useState("")
  const [loading, setLoading] = useState(false)

  if (getToken()) return <Navigate to="/" replace />

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError("")
    try {
      await api("/auth/login", { method: "POST", json: { email, password } })
      nav("/")
    } catch (err) {
      const msg = err instanceof Error ? err.message : ""
      setError(msg.includes("কিছুক্ষণ") ? t.brute : t.loginError)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex min-h-svh items-center justify-center bg-[var(--bg)] p-[24px]">
      <form
        onSubmit={(e) => void onSubmit(e)}
        className="w-[400px] max-w-full rounded-[12px] border border-[var(--border-default)] bg-[var(--surface)] p-[24px]"
      >
        <h1 className="mb-[8px] text-[22px] font-semibold">{t.brand}</h1>
        <p className="mb-[24px] text-[14px] text-[var(--text-secondary)]">{t.signIn}</p>
        <div className="flex flex-col gap-[16px]">
          <Field
            label={t.email}
            type="text"
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <Field
            label={t.password}
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <p className="text-[14px] text-[var(--text-secondary)]">{t.loginHint}</p>
          {error ? <p className="text-[14px] text-[var(--danger)]">{error}</p> : null}
          <PrimaryButton type="submit" loading={loading} disabled={loading}>
            {t.signIn}
          </PrimaryButton>
        </div>
      </form>
    </div>
  )
}
