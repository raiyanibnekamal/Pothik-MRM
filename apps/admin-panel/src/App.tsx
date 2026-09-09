import type { ReactNode } from "react"
import { Navigate, Route, Routes } from "react-router-dom"
import { getToken } from "./api/client"
import { AppShell } from "./components/layout/AppShell"
import { LoginPage } from "./pages/LoginPage"
import { DashboardPage } from "./pages/DashboardPage"
import { LiveMapPage } from "./pages/LiveMapPage"
import { DriversPage } from "./pages/DriversPage"
import { DriverDetailPage } from "./pages/DriverDetailPage"
import { UsersPage } from "./pages/UsersPage"
import { RidesPage } from "./pages/RidesPage"
import { SosPage } from "./pages/SosPage"
import { FinancePage } from "./pages/FinancePage"
import { PricingPage } from "./pages/PricingPage"
import { SettingsPage } from "./pages/SettingsPage"
import { PublicTrackPage } from "./pages/PublicTrackPage"

function Private({ children }: { children: ReactNode }) {
  if (!getToken()) return <Navigate to="/login" replace />
  return children
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/track/:token" element={<PublicTrackPage />} />
      <Route
        element={
          <Private>
            <AppShell />
          </Private>
        }
      >
        <Route path="/" element={<DashboardPage />} />
        <Route path="/map" element={<LiveMapPage />} />
        <Route path="/drivers" element={<DriversPage />} />
        <Route path="/drivers/:id" element={<DriverDetailPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/rides" element={<RidesPage />} />
        <Route path="/sos" element={<SosPage />} />
        <Route path="/finance" element={<FinancePage />} />
        <Route path="/pricing" element={<PricingPage />} />
        <Route path="/settings" element={<SettingsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
