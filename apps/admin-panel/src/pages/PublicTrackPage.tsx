import { useParams } from "react-router-dom"
import { MapContainer, TileLayer, CircleMarker } from "react-leaflet"
import { colors } from "../styles/colors"
import "leaflet/dist/leaflet.css"

export function PublicTrackPage() {
  const { token } = useParams()
  return (
    <div className="flex h-svh flex-col bg-[var(--bg)]">
      <header className="bg-[var(--interactive-primary)] px-[16px] py-[16px] text-[var(--text-on-primary)]">
        বিডি রাইড শেয়ার · Live
      </header>
      <div className="min-h-0 flex-1">
        <MapContainer center={[23.7925, 90.4078]} zoom={14} className="h-full w-full">
          <TileLayer url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png" />
          <CircleMarker
            center={[23.7925, 90.4078]}
            radius={10}
            pathOptions={{ color: colors.danger, fillColor: colors.danger, fillOpacity: 1 }}
          />
        </MapContainer>
      </div>
      <p className="p-[16px] text-[12px] text-[var(--text-secondary)]">token: {token}</p>
    </div>
  )
}
