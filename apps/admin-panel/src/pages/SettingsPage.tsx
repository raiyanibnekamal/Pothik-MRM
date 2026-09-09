import { useEffect, useState } from "react"
import { api } from "../api/client"
import { Field, PrimaryButton } from "../components/ui/Ui"
import { useT } from "../i18n/LocaleProvider"

type Config = { minVersion: string; maintenance: boolean }

export function SettingsPage() {
  const { t } = useT()
  const [c, setC] = useState<Config>({ minVersion: "1.0.0", maintenance: false })

  useEffect(() => {
    void api<Config>("/admin/config").then((d) =>
      setC({ minVersion: d.minVersion, maintenance: d.maintenance }),
    )
  }, [])

  return (
    <div className="max-w-xl">
      <h1 className="mb-[16px] text-[22px] font-semibold">{t.settings}</h1>
      <div className="flex flex-col gap-[16px]">
        <Field
          label={t.minVersion}
          value={c.minVersion}
          onChange={(e) => setC({ ...c, minVersion: e.target.value })}
        />
        <label className="flex min-h-[44px] items-center gap-[12px]">
          <input
            type="checkbox"
            checked={c.maintenance}
            onChange={(e) => setC({ ...c, maintenance: e.target.checked })}
          />
          {t.maintenance}
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
