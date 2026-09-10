import type { Driver, HoldingRow, RideRow, SosRow, UserRow } from "./client"

type DashboardStats = {
  rides: number
  gmv: number
  drivers: number
  cancel: number
  ar: number
  sos: number
}

export function mapPath(
  path: string,
  method: string,
  json?: unknown,
): { url: string; method: string; body?: unknown } {
  if (path === "/auth/login" && method === "POST") {
    return { url: "/auth/admin/login", method: "POST", body: json }
  }
  if (path === "/admin/dashboard-stats") return { url: "/admin/dashboard", method: "GET" }
  if (path === "/admin/sos") return { url: "/admin/sos/active", method: "GET" }
  if (path.match(/^\/admin\/drivers\/[^/]+\/approve$/)) {
    const id = path.split("/")[3]
    return { url: `/admin/kyc/${id}/approve`, method: "POST" }
  }
  if (path.match(/^\/admin\/drivers\/[^/]+\/reject$/)) {
    const id = path.split("/")[3]
    return { url: `/admin/kyc/${id}/reject`, method: "POST", body: { note: "Rejected from admin panel" } }
  }
  if (path.match(/^\/admin\/users\/[^/]+\/block$/)) {
    const id = path.split("/")[3]
    return { url: `/admin/users/${id}/block`, method: "POST", body: { blocked: true } }
  }
  if (path.match(/^\/admin\/sos\/[^/]+\/resolve$/)) {
    const id = path.split("/")[3]
    return { url: `/admin/sos/${id}/resolve`, method: "POST" }
  }
  if (path === "/admin/config" && method === "PUT") {
    return { url: "/admin/config", method: "PUT", body: mapConfigBody(json) }
  }
  return { url: path, method, body: json }
}

function mapConfigBody(json: unknown) {
  const c = json as Record<string, unknown>
  const body: Record<string, unknown> = {}
  if (c.minVersion !== undefined) {
    body.min_app_version = { passenger: c.minVersion, driver: c.minVersion }
  }
  if (c.maintenance !== undefined) {
    body.maintenance_mode = { enabled: c.maintenance }
  }
  if (c.commission !== undefined) {
    body.commission_rate = { rate: c.commission }
  }
  if (c.debtCap !== undefined) {
    body.debt_cap = { amount: c.debtCap }
  }
  if (c.holdHours !== undefined) {
    body.holding_hours = { hours: c.holdHours }
  }
  return body
}

export function transformResponse<T>(path: string, data: unknown): T {
  if (path === "/admin/dashboard-stats") {
    const d = data as Record<string, number>
    return {
      rides: d.rides_today ?? 0,
      gmv: d.gmv_today ?? 0,
      drivers: d.online_drivers ?? 0,
      cancel: d.cancel_rate ?? 0,
      ar: 91,
      sos: d.active_sos ?? 0,
    } as T
  }

  if (path === "/admin/drivers") {
    const page = data as { data?: unknown[] } | unknown[]
    const rows = Array.isArray(page) ? page : (page.data ?? [])
    return rows.map(mapDriver) as T
  }

  if (path.startsWith("/admin/drivers/") && !path.includes("approve") && !path.includes("reject")) {
    return mapDriver(data) as T
  }

  if (path === "/admin/users") {
    const page = data as { data?: unknown[] } | unknown[]
    const rows = Array.isArray(page) ? page : (page.data ?? [])
    return rows.map(mapUser) as T
  }

  if (path === "/admin/rides") {
    const page = data as { data?: unknown[] } | unknown[]
    const rows = Array.isArray(page) ? page : (page.data ?? [])
    return rows.map(mapRide) as T
  }

  if (path === "/admin/sos") {
    const rows = data as Record<string, unknown>[]
    return (Array.isArray(rows) ? rows : []).map(mapSos) as T
  }

  if (path === "/admin/holding") {
    const page = data as { data?: unknown[] } | unknown[]
    const rows = Array.isArray(page) ? page : (page.data ?? [])
    return rows.map(mapHolding) as T
  }

  if (path === "/admin/config") {
    const d = data as Record<string, Record<string, unknown>>
    return {
      minVersion: (d.min_app_version?.passenger as string) ?? "1.0.0",
      maintenance: (d.maintenance_mode?.enabled as boolean) ?? false,
      commission: (d.commission_rate?.rate as number) ?? 20,
      debtCap: (d.debt_cap?.amount as number) ?? 5000,
      cancelFee: 20,
      noShowFee: 40,
      holdHours: (d.holding_hours?.hours as number) ?? 24,
      bikeBase: 30,
      carBase: 60,
      bikeActive: true,
      carActive: true,
    } as T
  }

  if (path === "/auth/login") {
    const d = data as { access_token: string; user?: { role?: string } }
    return {
      accessToken: d.access_token,
      role: d.user?.role ?? "super_admin",
    } as T
  }

  return data as T
}

function mapDriver(raw: unknown): Driver {
  const p = raw as Record<string, unknown>
  const user = (p.user as Record<string, unknown>) ?? {}
  return {
    id: (p.id as string) ?? (p.user_id as string),
    name: (user.name as string) ?? "Driver",
    phone: (user.phone as string) ?? "",
    plate: (p.plate_no as string) ?? "",
    kyc: p.kyc_status === "approved" ? "verified" : p.kyc_status === "rejected" ? "rejected" : "pending",
    online: (p.is_online as boolean) ?? false,
    lat: Number(p.current_lat ?? 23.79),
    lng: Number(p.current_lng ?? 90.41),
    nid: (p.nid as string) ?? "",
    rating: Number((user.rating_avg as number) ?? 5),
  }
}

function mapUser(raw: unknown): UserRow {
  const u = raw as Record<string, unknown>
  return {
    id: u.id as string,
    name: (u.name as string) ?? "",
    phone: (u.phone as string) ?? "",
    role: (u.role as string) ?? "passenger",
    blocked: (u.is_blocked as boolean) ?? false,
  }
}

function mapRide(raw: unknown): RideRow {
  const r = raw as Record<string, unknown>
  const passenger = r.passenger as Record<string, unknown> | undefined
  const driver = r.driver as Record<string, unknown> | undefined
  return {
    id: r.id as string,
    rider: (passenger?.name as string) ?? "Rider",
    driver: (driver?.name as string) ?? "—",
    status: (r.status as string) ?? "requested",
    fare: Number(r.estimated_fare ?? r.final_fare ?? 0),
    pickup: (r.pickup_address as string) ?? "",
    drop: (r.drop_address as string) ?? "",
  }
}

function mapSos(raw: unknown): SosRow {
  const s = raw as Record<string, unknown>
  return {
    id: s.id as string,
    rider: (s.user_id as string) ?? "Rider",
    driver: (s.ride_id as string) ?? "—",
    plate: "—",
    lat: Number(s.lat ?? 23.79),
    lng: Number(s.lng ?? 90.41),
    createdAt: (s.created_at as string) ?? new Date().toISOString(),
  }
}

function mapHolding(raw: unknown): HoldingRow {
  const t = raw as Record<string, unknown>
  return {
    id: t.id as string,
    driver: (t.user_id as string) ?? "Driver",
    amount: Number(t.amount ?? 0),
    hoursLeft: 24,
  }
}

export type { DashboardStats }
