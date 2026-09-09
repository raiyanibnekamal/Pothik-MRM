import { useEffect, useState } from "react"
import { api } from "../api/client"
import { Kpi } from "../components/ui/Ui"
import { useT } from "../i18n/LocaleProvider"

export function DashboardPage() {
  const { t } = useT()
  const [stats, setStats] = useState({
    rides: 0,
    gmv: 0,
    drivers: 0,
    cancel: 0,
    ar: 0,
    sos: 0,
  })

  useEffect(() => {
    void api<typeof stats>("/admin/dashboard-stats").then(setStats)
  }, [])

  return (
    <div>
      <h1 className="mb-[24px] text-[22px] font-semibold">{t.dashboard}</h1>
      <div className="grid grid-cols-2 gap-[16px] xl:grid-cols-3">
        <Kpi label={t.ridesToday} value={String(stats.rides)} />
        <Kpi label={t.gmv} value={`৳${stats.gmv.toLocaleString("en-US")}`} />
        <Kpi label={t.driversOnline} value={String(stats.drivers)} />
        <Kpi label={t.cancelPct} value={`${stats.cancel}%`} />
        <Kpi label={t.acceptRate} value={`${stats.ar}%`} />
        <Kpi label={t.sosOpen} value={String(stats.sos)} />
      </div>
    </div>
  )
}
