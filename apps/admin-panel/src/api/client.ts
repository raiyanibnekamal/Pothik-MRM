import { mapPath, transformResponse } from "./realApi"

const env = import.meta.env.VITE_APP_ENV ?? "local"
const useMock = import.meta.env.VITE_USE_MOCK !== "false"
const apiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:8000/api/v1"

export type Driver = {
  id: string
  name: string
  phone: string
  plate: string
  kyc: "pending" | "verified" | "rejected"
  online: boolean
  lat: number
  lng: number
  nid: string
  rating: number
}

export type RideRow = {
  id: string
  rider: string
  driver: string
  status: string
  fare: number
  pickup: string
  drop: string
}

export type UserRow = {
  id: string
  name: string
  phone: string
  role: string
  blocked: boolean
}

export type SosRow = {
  id: string
  rider: string
  driver: string
  plate: string
  lat: number
  lng: number
  createdAt: string
}

export type HoldingRow = {
  id: string
  driver: string
  amount: number
  hoursLeft: number
}

type Store = {
  token: string | null
  loginFails: number
  drivers: Driver[]
  users: UserRow[]
  rides: RideRow[]
  sos: SosRow[]
  holding: HoldingRow[]
  stats: {
    rides: number
    gmv: number
    drivers: number
    cancel: number
    ar: number
    sos: number
  }
  config: {
    minVersion: string
    maintenance: boolean
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
}

const store: Store = {
  token: localStorage.getItem("admin_token"),
  loginFails: 0,
  drivers: [
    {
      id: "d0",
      name: "মনিরুজ্জামান",
      phone: "0152170004",
      plate: "DHAKA METRO-GA 15-2170",
      kyc: "verified",
      online: true,
      lat: 23.7925,
      lng: 90.4078,
      nid: "1990123456789",
      rating: 5,
    },
    {
      id: "d1",
      name: "রহিম উদ্দিন",
      phone: "+8801711000000",
      plate: "DHAKA METRO-GA 12-3456",
      kyc: "pending",
      online: true,
      lat: 23.7925,
      lng: 90.4078,
      nid: "1990123456789",
      rating: 4.9,
    },
    {
      id: "d2",
      name: "সালমা খাতুন",
      phone: "+8801711222333",
      plate: "DHAKA METRO-CHA 98-2211",
      kyc: "verified",
      online: true,
      lat: 23.7806,
      lng: 90.4193,
      nid: "1988123456789",
      rating: 4.8,
    },
    {
      id: "d3",
      name: "করিম মিয়া",
      phone: "+8801811999888",
      plate: "DHAKA METRO-GA 44-1100",
      kyc: "rejected",
      online: false,
      lat: 23.7465,
      lng: 90.376,
      nid: "1978123456789",
      rating: 4.2,
    },
  ],
  users: [
    {
      id: "u0",
      name: "মনিরুজ্জামান",
      phone: "0152170004",
      role: "super_admin",
      blocked: false,
    },
    {
      id: "u1",
      name: "নুসরাত জাহান",
      phone: "+8801712345678",
      role: "passenger",
      blocked: false,
    },
    {
      id: "u2",
      name: "রহিম উদ্দিন",
      phone: "+8801711000000",
      role: "driver",
      blocked: false,
    },
  ],
  rides: [
    {
      id: "R90001",
      rider: "মনিরুজ্জামান",
      driver: "রহিম উদ্দিন",
      status: "completed",
      fare: 250,
      pickup: "Gulshan 2",
      drop: "Banani",
    },
    {
      id: "R10241",
      rider: "নুসরাত জাহান",
      driver: "রহিম উদ্দিন",
      status: "in_progress",
      fare: 250,
      pickup: "Gulshan 2",
      drop: "Banani",
    },
    {
      id: "R10240",
      rider: "আরিফ",
      driver: "সালমা খাতুন",
      status: "completed",
      fare: 85,
      pickup: "Dhanmondi",
      drop: "Farmgate",
    },
  ],
  sos: [
    {
      id: "sos_1",
      rider: "নুসরাত জাহান",
      driver: "রহিম উদ্দিন",
      plate: "DHAKA METRO-GA 12-3456",
      lat: 23.7925,
      lng: 90.4078,
      createdAt: new Date().toISOString(),
    },
  ],
  holding: [
    { id: "h1", driver: "সালমা খাতুন", amount: 1480, hoursLeft: 18 },
    { id: "h2", driver: "রহিম উদ্দিন", amount: 370, hoursLeft: 36 },
  ],
  stats: {
    rides: 1284,
    gmv: 312500,
    drivers: 86,
    cancel: 7.2,
    ar: 91,
    sos: 1,
  },
  config: {
    minVersion: "1.0.0",
    maintenance: false,
    commission: 20,
    debtCap: 5000,
    cancelFee: 20,
    noShowFee: 40,
    holdHours: 24,
    bikeBase: 25,
    carBase: 50,
    bikeActive: true,
    carActive: true,
  },
}

function envelope<T>(data: T) {
  return { success: true as const, data, message: "ok" }
}

function digits(raw: string) {
  return raw.replace(/\D/g, "")
}

function isQaLogin(email: string) {
  let d = digits(email)
  if (d.startsWith("880")) d = d.slice(3)
  return d === "0152170004" || d === "152170004"
}

export async function api<T>(
  path: string,
  init: RequestInit & { json?: unknown } = {},
): Promise<T> {
  if (useMock) return mock(path, init.json, init.method ?? "GET") as Promise<T>

  const method = init.method ?? "GET"
  const mapped = mapPath(path, method, init.json)
  const headers = new Headers(init.headers)
  headers.set("Content-Type", "application/json")
  if (store.token) headers.set("Authorization", `Bearer ${store.token}`)

  const payload = mapped.body ?? init.json
  const res = await fetch(`${apiUrl}${mapped.url}`, {
    ...init,
    method: mapped.method,
    headers,
    body: payload !== undefined ? JSON.stringify(payload) : init.body,
  })
  const body = await res.json()
  if (!res.ok) {
    throw new Error(body?.error?.message ?? "Request failed")
  }

  if (path === "/auth/login" && body.data?.access_token) {
    store.token = body.data.access_token as string
    localStorage.setItem("admin_token", store.token)
  }

  return transformResponse<T>(path, body.data)
}

async function mock(path: string, json: unknown, method: string) {
  await new Promise((r) => setTimeout(r, 200))
  if (path === "/auth/login" && method === "POST") {
    const body = json as { email: string; password: string }
    if (store.loginFails >= 6) {
      throw new Error("কিছুক্ষণ পর আবার চেষ্টা করুন।")
    }
    if (
      (body.email === "ops@bdrideshare.com" && body.password === "Admin@1234") ||
      (isQaLogin(body.email) && body.password === "123456") ||
      (body.email === "qa@bdrideshare.com" && body.password === "123456")
    ) {
      store.loginFails = 0
      store.token = "admin_local_token"
      localStorage.setItem("admin_token", store.token)
      return envelope({
        accessToken: store.token,
        role: "super_admin",
        env,
      }).data
    }
    store.loginFails += 1
    throw new Error("login")
  }
  if (path === "/auth/logout") {
    store.token = null
    localStorage.removeItem("admin_token")
    return envelope(null).data
  }
  if (path === "/admin/dashboard-stats") return envelope(store.stats).data
  if (path === "/admin/drivers") return envelope(store.drivers).data
  if (path.startsWith("/admin/drivers/") && method === "GET") {
    const id = path.split("/").pop()
    return envelope(store.drivers.find((d) => d.id === id)).data
  }
  if (path.includes("/approve")) {
    const id = path.split("/")[3]
    const d = store.drivers.find((x) => x.id === id)
    if (d) d.kyc = "verified"
    return envelope(d).data
  }
  if (path.includes("/reject")) {
    const id = path.split("/")[3]
    const d = store.drivers.find((x) => x.id === id)
    if (d) d.kyc = "rejected"
    return envelope(d).data
  }
  if (path === "/admin/users") return envelope(store.users).data
  if (path.includes("/block")) {
    const id = path.split("/")[3]
    const u = store.users.find((x) => x.id === id)
    if (u) u.blocked = !u.blocked
    return envelope(u).data
  }
  if (path === "/admin/rides") return envelope(store.rides).data
  if (path === "/admin/sos/active") return envelope(store.sos).data
  if (path.includes("/sos/") && path.endsWith("/resolve")) {
    const id = path.split("/")[3]
    store.sos = store.sos.filter((s) => s.id !== id)
    store.stats.sos = store.sos.length
    return envelope(null).data
  }
  if (path === "/admin/holding") return envelope(store.holding).data
  if (path === "/admin/config" && method === "GET") return envelope(store.config).data
  if (path === "/admin/config" && method === "PUT") {
    Object.assign(store.config, json)
    return envelope(store.config).data
  }
  throw new Error(`Unmocked ${method} ${path}`)
}

export function getToken() {
  return store.token
}

export function envName() {
  return env.toUpperCase()
}

export async function refreshSosStore() {
  if (useMock) return
  try {
    store.sos = await api<SosRow[]>("/admin/sos/active")
  } catch {
    /* ignore poll errors */
  }
}

export { store }
