import { useEffect, useState } from "react"
import { useNavigate } from "react-router-dom"
import { api, type Driver } from "../api/client"
import { Badge } from "../components/ui/Ui"
import { useT } from "../i18n/LocaleProvider"

export function DriversPage() {
  const { t } = useT()
  const nav = useNavigate()
  const [q, setQ] = useState("")
  const [rows, setRows] = useState<Driver[]>([])

  useEffect(() => {
    void api<Driver[]>("/admin/drivers").then(setRows)
  }, [])

  const needle = q.trim().toLowerCase()
  const filtered = rows.filter(
    (d) =>
      d.name.toLowerCase().includes(needle) ||
      d.phone.toLowerCase().includes(needle) ||
      d.plate.toLowerCase().includes(needle),
  )

  return (
    <div>
      <h1 className="mb-[16px] text-[22px] font-semibold">{t.drivers}</h1>
      <input
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={t.search}
        className="mb-[16px] h-[56px] w-full max-w-md rounded-[12px] border border-[var(--border-strong)] px-[16px]"
      />
      <div className="overflow-x-auto rounded-[12px] border border-[var(--border-default)] bg-[var(--surface)]">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-[var(--border-default)] text-[14px] font-medium">
              <th className="px-[16px] py-[12px]">{t.name}</th>
              <th className="px-[16px] py-[12px]">{t.phone}</th>
              <th className="px-[16px] py-[12px]">{t.plate}</th>
              <th className="px-[16px] py-[12px]">{t.kyc}</th>
              <th className="px-[16px] py-[12px]">{t.status}</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td className="px-[16px] py-[24px] text-[var(--text-secondary)]" colSpan={5}>
                  {t.noResults}
                </td>
              </tr>
            ) : null}
            {filtered.map((d) => (
              <tr
                key={d.id}
                className="h-[48px] cursor-pointer border-b border-[var(--border-default)] last:border-0"
                onClick={() => nav(`/drivers/${d.id}`)}
              >
                <td className="px-[16px]">{d.name}</td>
                <td className="font-num px-[16px]">{d.phone}</td>
                <td className="font-num px-[16px]">{d.plate}</td>
                <td className="px-[16px]">
                  <Badge
                    tone={
                      d.kyc === "verified"
                        ? "success"
                        : d.kyc === "rejected"
                          ? "danger"
                          : "warning"
                    }
                  >
                    {d.kyc === "verified"
                      ? t.verified
                      : d.kyc === "rejected"
                        ? t.rejected
                        : t.pending}
                  </Badge>
                </td>
                <td className="px-[16px]">
                  {d.online ? t.active : t.offline}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
