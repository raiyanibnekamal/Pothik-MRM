import { useEffect, useState } from "react"
import { MapContainer, TileLayer, CircleMarker, Popup } from "react-leaflet"
import { api, type Driver, type RideRow, store } from "../api/client"
import { colors } from "../styles/colors"
import { useT } from "../i18n/LocaleProvider"
import "leaflet/dist/leaflet.css"

export function LiveMapPage() {
  const { t } = useT()
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [rides, setRides] = useState<RideRow[]>([])

  useEffect(() => {
    void api<Driver[]>("/admin/drivers").then(setDrivers)
    void api<RideRow[]>("/admin/rides").then(setRides)
  }, [])

  return (
    <div className="flex h-[calc(100svh-8rem)] flex-col">
      <h1 className="mb-[16px] text-[22px] font-semibold">{t.liveMap}</h1>
      <div className="min-h-0 flex-1 overflow-hidden rounded-[12px] border border-[var(--border-default)]">
        <MapContainer
          center={[23.8103, 90.4125]}
          zoom={12}
          className="h-full w-full"
          scrollWheelZoom
        >
          <TileLayer
            attribution='&copy; OpenStreetMap &copy; CARTO'
            url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
          />
          {drivers.filter((d) => d.online).map((d) => (
            <CircleMarker
              key={d.id}
              center={[d.lat, d.lng]}
              radius={8}
              pathOptions={{
                color: colors.navy900,
                fillColor: colors.navy900,
                fillOpacity: 1,
              }}
            >
              <Popup>
                {d.name}
                <br />
                {d.plate}
              </Popup>
            </CircleMarker>
          ))}
          {store.sos.map((s) => (
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
              <Popup>SOS {s.rider}</Popup>
            </CircleMarker>
          ))}
        </MapContainer>
      </div>
      <p className="mt-8 text-[12px] text-[var(--text-secondary)]">
        {rides.filter((r) => r.status === "in_progress").length} {t.liveTrips}
      </p>
    </div>
  )
}
