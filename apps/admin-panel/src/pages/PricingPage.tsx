import { useEffect, useState } from "react"
import { api } from "../api/client"
import { Field, PrimaryButton } from "../components/ui/Ui"
import { useT } from "../i18n/LocaleProvider"

type Config = {
  commission: number
  debtCap: number
  cancelFee: number
  noShowFee: number
  holdHours: number
  bikeBase: number
  carBase: number
  bikeActive: boolean
  carActive: boolean
}

export function PricingPage() {
  const { t } = useT()
  const [c, setC] = useState<Config | null>(null)

  useEffect(() => {
    void api<Config>("/admin/config").then(setC)
  }, [])

  if (!c) return <p>…</p>

  function num(key: keyof Config, v: string) {
    setC((prev) => (prev ? { ...prev, [key]: Number(v) } : prev))
  }

  return (
    <div className="max-w-xl">
      <h1 className="mb-[16px] text-[22px] font-semibold">{t.pricing}</h1>
      <div className="flex flex-col gap-[16px]">
        <Field
          label={t.commission}
          type="number"
          value={c.commission}
          onChange={(e) => num("commission", e.target.value)}
        />
        <Field
          label={t.debtCap}
          type="number"
          value={c.debtCap}
          onChange={(e) => num("debtCap", e.target.value)}
        />
        <Field
          label={t.cancelFee}
          type="number"
          value={c.cancelFee}
          onChange={(e) => num("cancelFee", e.target.value)}
        />
        <Field
          label={t.noShowFee}
          type="number"
          value={c.noShowFee}
          onChange={(e) => num("noShowFee", e.target.value)}
        />
        <Field
          label={t.holdHours}
          type="number"
          value={c.holdHours}
          onChange={(e) => num("holdHours", e.target.value)}
        />
        <label className="flex min-h-[44px] items-center gap-[12px]">
          <input
            type="checkbox"
            checked={c.bikeActive}
            onChange={(e) => setC({ ...c, bikeActive: e.target.checked })}
          />
          {t.bike} · base ৳{c.bikeBase}
        </label>
        <label className="flex min-h-[44px] items-center gap-[12px]">
          <input
            type="checkbox"
            checked={c.carActive}
            onChange={(e) => setC({ ...c, carActive: e.target.checked })}
          />
          {t.car} · base ৳{c.carBase}
        </label>
        <PrimaryButton
          type="button"
          onClick={() => void api("/admin/config", { method: "PUT", json: c })}
        >
          {t.save}
        </PrimaryButton>
      </div>
    </div>
  )
}
