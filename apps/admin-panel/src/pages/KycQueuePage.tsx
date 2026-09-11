import { useEffect, useState, type FormEvent } from "react"
import {
  Badge,
  Card,
  DangerButton,
  Modal,
  PrimaryButton,
  SecondaryButton,
} from "../components/ui/Ui"
import { useT } from "../i18n/LocaleProvider"
import { api, type Driver } from "../api/client"

const NOTE_MAX = 500

export function KycQueuePage() {
  const { t } = useT()
  const [rows, setRows] = useState<Driver[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState<Set<string>>(() => new Set())
  const [feedback, setFeedback] = useState<string | null>(null)
  const [rejecting, setRejecting] = useState<Driver | null>(null)
  const [reason, setReason] = useState("")

  function setBusyFor(id: string, on: boolean) {
    setBusy((prev) => {
      const next = new Set(prev)
      if (on) next.add(id)
      else next.delete(id)
      return next
    })
  }

  async function load(aliveCheck: () => boolean) {
    setLoading(true)
    setError(null)
    try {
      const list = await api<Driver[]>("/admin/kyc/pending")
      if (!aliveCheck()) return
      setRows(list.filter((d) => d.kyc === "pending"))
    } catch (e) {
      if (!aliveCheck()) return
      setError(e instanceof Error ? e.message : String(e))
      setRows([])
    } finally {
      if (aliveCheck()) setLoading(false)
    }
  }

  useEffect(() => {
    let alive = true
    void load(() => alive)
    return () => {
      alive = false
    }
  }, [])

  async function approve(d: Driver) {
    setBusyFor(d.id, true)
    setFeedback(null)
    const prev = rows
    setRows((r) => r.filter((x) => x.id !== d.id))
    try {
      await api(`/admin/drivers/${d.id}/approve`, { method: "POST" })
      setFeedback(t.kycApproveSuccess)
    } catch (e) {
      setRows(prev)
      setError(e instanceof Error ? e.message : t.kycActionFailed)
    } finally {
      setBusyFor(d.id, false)
    }
  }

  function openReject(d: Driver) {
    setRejecting(d)
    setReason("")
  }

  function closeReject() {
    setRejecting(null)
    setReason("")
  }

  async function confirmReject(e: FormEvent) {
    e.preventDefault()
    if (!rejecting) return
    const note = reason.trim()
    if (note.length === 0 || note.length > NOTE_MAX) return
    const target = rejecting
    setBusyFor(target.id, true)
    setFeedback(null)
    const prev = rows
    setRows((r) => r.filter((x) => x.id !== target.id))
    try {
      await api(`/admin/drivers/${target.id}/reject`, {
        method: "POST",
        json: { note },
      })
      setFeedback(t.kycRejectSuccess)
      closeReject()
    } catch (err) {
      setRows(prev)
      setError(err instanceof Error ? err.message : t.kycActionFailed)
    } finally {
      setBusyFor(target.id, false)
    }
  }

  const reasonOk =
    rejecting !== null &&
    reason.trim().length > 0 &&
    reason.trim().length <= NOTE_MAX

  return (
    <div>
      <div className="mb-[16px] flex items-center justify-between">
        <h1 className="text-[22px] font-semibold">{t.kycQueue}</h1>
        <SecondaryButton onClick={() => void load(() => true)} disabled={loading}>
          {t.kycRefresh}
        </SecondaryButton>
      </div>

      {feedback ? (
        <Card>
          <p className="text-[14px] text-[var(--success)]">{feedback}</p>
        </Card>
      ) : null}

      {error ? (
        <Card>
          <p className="text-[14px] text-[var(--danger)]">{error}</p>
        </Card>
      ) : null}

      <div className="mt-[16px] overflow-x-auto rounded-[12px] border border-[var(--border-default)] bg-[var(--surface)]">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-[var(--border-default)] text-[14px] font-medium">
              <th className="px-[16px] py-[12px]">{t.name}</th>
              <th className="px-[16px] py-[12px]">{t.phone}</th>
              <th className="px-[16px] py-[12px]">{t.plate}</th>
              <th className="px-[16px] py-[12px]">{t.status}</th>
              <th className="px-[16px] py-[12px] text-right">{"\u00A0"}</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td
                  className="px-[16px] py-[24px] text-[var(--text-secondary)]"
                  colSpan={5}
                >
                  {t.loading}
                </td>
              </tr>
            ) : null}
            {!loading && rows.length === 0 ? (
              <tr>
                <td
                  className="px-[16px] py-[24px] text-[var(--text-secondary)]"
                  colSpan={5}
                >
                  {t.kycEmpty}
                </td>
              </tr>
            ) : null}
            {rows.map((d) => {
              const isBusy = busy.has(d.id)
              return (
                <tr
                  key={d.id}
                  className="border-b border-[var(--border-default)] last:border-0"
                >
                  <td className="px-[16px] py-[12px]">{d.name}</td>
                  <td className="font-num px-[16px] py-[12px]">{d.phone}</td>
                  <td className="font-num px-[16px] py-[12px]">{d.plate}</td>
                  <td className="px-[16px] py-[12px]">
                    <Badge tone="warning">{t.pending}</Badge>
                  </td>
                  <td className="px-[16px] py-[12px]">
                    <div className="flex justify-end gap-[8px]">
                      <SecondaryButton
                        disabled={isBusy}
                        onClick={() => openReject(d)}
                      >
                        {t.reject}
                      </SecondaryButton>
                      <PrimaryButton
                        disabled={isBusy}
                        onClick={() => void approve(d)}
                      >
                        {t.approve}
                      </PrimaryButton>
                    </div>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {rejecting ? (
        <Modal title={t.kycRejectReason} onClose={closeReject}>
          <form onSubmit={(e) => void confirmReject(e)}>
            <label className="block">
              <span className="mb-[8px] block text-[14px] font-medium">
                {t.kycRejectReason}
              </span>
              <textarea
                aria-label={t.kycRejectReason}
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder={t.kycRejectPlaceholder}
                maxLength={NOTE_MAX}
                required
                rows={4}
                className="block w-full rounded-[12px] border border-[var(--border-strong)] bg-[var(--surface)] px-[16px] py-[12px] text-[16px] text-[var(--text-primary)]"
              />
            </label>
            <p className="mt-[8px] text-[12px] text-[var(--text-secondary)]">
              {reason.trim().length} / {NOTE_MAX}
            </p>
            <div className="mt-[16px] flex justify-end gap-[8px]">
              <SecondaryButton type="button" onClick={closeReject}>
                {t.cancel}
              </SecondaryButton>
              <DangerButton type="submit" disabled={!reasonOk}>
                {t.kycConfirmReject}
              </DangerButton>
            </div>
          </form>
        </Modal>
      ) : null}
    </div>
  )
}
