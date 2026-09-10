import { useCallback, useEffect, useState } from "react"
import { api, store, type SosRow } from "../api/client"

const POLL_MS = 5000
const ALERT_PREFIX = "🚨 "

let baseTitle =
  typeof document !== "undefined"
    ? document.title.replace(/^🚨\s*/, "")
    : "BD Ride Share Admin"

let knownIds = new Set<string>()
let subscriberCount = 0
let intervalId: number | undefined
let fetchGeneration = 0
const listeners = new Set<() => void>()

function notify() {
  listeners.forEach((listener) => listener())
}

function applyNewAlertTitle(data: SosRow[]) {
  const hasNew =
    knownIds.size > 0 && data.some((row) => !knownIds.has(row.id))
  if (hasNew) {
    document.title = ALERT_PREFIX + baseTitle
  }
  knownIds = new Set(data.map((row) => row.id))
}

export function clearSosAlertTitle() {
  if (typeof document !== "undefined") {
    document.title = baseTitle
  }
}

async function fetchActiveSos(): Promise<SosRow[] | null> {
  const generation = ++fetchGeneration
  try {
    const data = await api<SosRow[]>("/admin/sos/active")
    if (generation !== fetchGeneration) return null
    applyNewAlertTitle(data)
    store.sos = data
    notify()
    return data
  } catch {
    if (generation !== fetchGeneration) return null
    return null
  }
}

function startPolling() {
  subscriberCount += 1
  if (subscriberCount === 1) {
    void fetchActiveSos()
    intervalId = window.setInterval(() => void fetchActiveSos(), POLL_MS)
  }
}

function stopPolling() {
  subscriberCount -= 1
  if (subscriberCount <= 0) {
    subscriberCount = 0
    if (intervalId !== undefined) {
      window.clearInterval(intervalId)
      intervalId = undefined
    }
  }
}

export function useSosPolling() {
  const [, setTick] = useState(0)

  useEffect(() => {
    const onUpdate = () => setTick((tick) => tick + 1)
    listeners.add(onUpdate)
    startPolling()
    return () => {
      listeners.delete(onUpdate)
      stopPolling()
    }
  }, [])

  const refresh = useCallback(async () => {
    await fetchActiveSos()
  }, [])

  return {
    sos: store.sos,
    refresh,
  }
}
