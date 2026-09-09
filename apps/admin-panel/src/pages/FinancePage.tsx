import { useEffect, useState } from "react"
import { api, type HoldingRow } from "../api/client"
import { Kpi } from "../components/ui/Ui"
import { useT } from "../i18n/LocaleProvider"

export function FinancePage() {
  const { t } = useT()
  const [rows, setRows] = useState<HoldingRow[]>([])
  useEffect(() => {
    void api<HoldingRow[]>("/admin/holding").then(setRows)
  }, [])
  const total = rows.reduce((a, r) => a + r.amount, 0)

  return (
    <div>
      <h1 className="mb-[16px] text-[22px] font-semibold">{t.finance}</h1>
      <div className="mb-[16px] max-w-sm">
        <Kpi label={t.holding} value={`৳${total.toLocaleString("en-US")}`} />
      </div>
      <div className="overflow-x-auto rounded-[12px] border border-[var(--border-default)] bg-[var(--surface)]">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-[var(--border-default)]">
              <th className="px-[16px] py-[12px]">{t.drivers}</th>
              <th className="px-[16px] py-[12px]">{t.fare}</th>
              <th className="px-[16px] py-[12px]">{t.holdHours}</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id} className="h-[48px] border-b border-[var(--border-default)]">
                <td className="px-[16px]">{r.driver}</td>
                <td className="font-num px-[16px]">৳{r.amount}</td>
                <td className="font-num px-[16px]">{r.hoursLeft}h</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
