import { useEffect, useState } from "react"
import { api, type RideRow } from "../api/client"
import { useT } from "../i18n/LocaleProvider"

export function RidesPage() {
  const { t } = useT()
  const [rows, setRows] = useState<RideRow[]>([])
  const [q, setQ] = useState("")

  useEffect(() => {
    void api<RideRow[]>("/admin/rides").then(setRows)
  }, [])

  const needle = q.trim().toLowerCase()
  const filtered = rows.filter(
    (r) =>
      r.id.toLowerCase().includes(needle) ||
      r.rider.toLowerCase().includes(needle) ||
      r.driver.toLowerCase().includes(needle) ||
      r.pickup.toLowerCase().includes(needle) ||
      r.drop.toLowerCase().includes(needle) ||
      r.status.toLowerCase().includes(needle),
  )

  return (
    <div>
      <h1 className="mb-[16px] text-[22px] font-semibold">{t.rides}</h1>
      <input
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={t.search}
        className="mb-[16px] h-[56px] w-full max-w-md rounded-[12px] border border-[var(--border-strong)] px-[16px]"
      />
      <div className="overflow-x-auto rounded-[12px] border border-[var(--border-default)] bg-[var(--surface)]">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-[var(--border-default)]">
              <th className="px-[16px] py-[12px]">ID</th>
              <th className="px-[16px] py-[12px]">{t.rider}</th>
              <th className="px-[16px] py-[12px]">{t.driver}</th>
              <th className="px-[16px] py-[12px]">{t.status}</th>
              <th className="px-[16px] py-[12px]">{t.fare}</th>
              <th className="px-[16px] py-[12px]">{t.fromTo}</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td className="px-[16px] py-[24px] text-[var(--text-secondary)]" colSpan={6}>
                  {t.noResults}
                </td>
              </tr>
            ) : (
              filtered.map((r) => (
                <tr key={r.id} className="h-[48px] border-b border-[var(--border-default)]">
                  <td className="font-num px-[16px]">{r.id}</td>
                  <td className="px-[16px]">{r.rider}</td>
                  <td className="px-[16px]">{r.driver}</td>
                  <td className="px-[16px]">{r.status}</td>
                  <td className="font-num px-[16px]">৳{r.fare}</td>
                  <td className="px-[16px]">
                    {r.pickup} → {r.drop}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
