import { useEffect, useState } from "react"
import { MapContainer, TileLayer, CircleMarker, Popup } from "react-leaflet"
import { api, store, type SosRow } from "../api/client"
import { DangerButton, PrimaryButton } from "../components/ui/Ui"
import { colors } from "../styles/colors"
import { useT } from "../i18n/LocaleProvider"
import "leaflet/dist/leaflet.css"

export function SosPage() {
  const { t } = useT()
  const [rows, setRows] = useState<SosRow[]>([])

  async function refresh() {
    const data = await api<SosRow[]>("/admin/sos")
    setRows(data)
    store.sos = data
  }

  useEffect(() => {
    void refresh()
  }, [])

  return (
    <div className="flex h-[calc(100svh-8rem)] flex-col gap-[16px]">
      <h1 className="text-[22px] font-semibold">{t.sos}</h1>
      {rows.length === 0 ? (
        <p className="text-[16px] text-[var(--text-secondary)]">{t.noSos}</p>
      ) : (
        <div className="grid min-h-0 flex-1 grid-cols-2 gap-[16px]">
          <div className="overflow-auto">
            {rows.map((s) => (
              <div
                key={s.id}
                className="mb-[12px] rounded-[12px] border border-[var(--danger)] bg-[var(--danger-bg)] p-[16px]"
              >
                <p className="font-semibold">{s.rider}</p>
                <p className="text-[14px]">
                  {s.driver} · {s.plate}
                </p>
                <p className="font-num text-[12px]">{s.createdAt}</p>
                <div className="mt-[12px] flex gap-[8px]">
                  <a href={`tel:999`}>
                    <PrimaryButton type="button">{t.call} 999</PrimaryButton>
                  </a>
                  <DangerButton
                    type="button"
                    onClick={() =>
                      void api(`/admin/sos/${s.id}/resolve`, { method: "PUT" }).then(refresh)
                    }
                  >
                    {t.resolve}
                  </DangerButton>
                </div>
              </div>
            ))}
          </div>
          <div className="overflow-hidden rounded-[12px] border border-[var(--border-default)]">
            <MapContainer center={[23.81, 90.41]} zoom={12} className="h-full w-full">
              <TileLayer url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png" />
              {rows.map((s) => (
                <CircleMarker
                  key={s.id}
                  center={[s.lat, s.lng]}
                  radius={10}
                  pathOptions={{
                    color: colors.danger,
                    fillColor: colors.danger,
                    fillOpacity: 1,
                  }}
                >
                  <Popup>{s.rider}</Popup>
                </CircleMarker>
              ))}
            </MapContainer>
          </div>
        </div>
      )}
    </div>
  )
}
