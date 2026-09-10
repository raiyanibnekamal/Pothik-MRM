import { useNavigate } from "react-router-dom"
import { store } from "../../api/client"
import { useT } from "../../i18n/LocaleProvider"

export function SosBanner() {
  const { t } = useT()
  const nav = useNavigate()
  const n = store.sos.length
  if (n === 0) return null
  return (
    <button
      type="button"
      onClick={() => nav("/sos")}
      className="flex w-full items-center justify-center gap-[12px] bg-[var(--danger)] px-[16px] py-[12px] text-[16px] font-semibold text-[var(--text-on-primary)]"
    >
      {t.sos} · {n}
    </button>
  )
}
