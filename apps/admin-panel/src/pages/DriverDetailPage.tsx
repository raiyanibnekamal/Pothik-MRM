import { useEffect, useState } from "react"
import { useNavigate, useParams } from "react-router-dom"
import { api, type Driver } from "../api/client"
import { Badge, DangerButton, PrimaryButton, Modal } from "../components/ui/Ui"
import { useT } from "../i18n/LocaleProvider"

export function DriverDetailPage() {
  const { id } = useParams()
  const { t } = useT()
  const nav = useNavigate()
  const [d, setD] = useState<Driver | null>(null)
  const [confirm, setConfirm] = useState<"approve" | "reject" | null>(null)

  useEffect(() => {
    if (!id) return
    void api<Driver>(`/admin/drivers/${id}`).then(setD)
  }, [id])

  if (!d) return <p>{t.loading}</p>
  const driver = d
  const kycLabel =
    d.kyc === "verified" ? t.verified : d.kyc === "rejected" ? t.rejected : t.pending

  async function act(kind: "approve" | "reject") {
    await api(`/admin/drivers/${driver.id}/${kind}`, { method: "PUT" })
    setConfirm(null)
    nav("/drivers")
  }

  return (
    <div className="max-w-3xl">
      <h1 className="mb-[16px] text-[22px] font-semibold">{d.name}</h1>
      <div className="mb-[16px] flex gap-[8px]">
        <Badge
          tone={d.kyc === "verified" ? "success" : d.kyc === "rejected" ? "danger" : "warning"}
        >
          {kycLabel}
        </Badge>
      </div>
      <div className="rounded-[12px] border border-[var(--border-default)] bg-[var(--surface)] p-[16px]">
        <p className="font-num">{d.phone}</p>
        <p className="font-num mt-[8px]">{d.plate}</p>
        <p className="mt-[16px] text-[14px] text-[var(--text-secondary)]">NID</p>
        <p className="font-num">••••••••{d.nid.slice(-4)}</p>
      </div>
      {d.kyc !== "verified" ? (
      <div className="mt-[24px] flex gap-[12px]">
        <PrimaryButton type="button" onClick={() => setConfirm("approve")}>
          {t.approve}
        </PrimaryButton>
        <DangerButton type="button" onClick={() => setConfirm("reject")}>
          {t.reject}
        </DangerButton>
      </div>
      ) : null}
      {confirm ? (
        <Modal title={confirm === "approve" ? t.approve : t.reject} onClose={() => setConfirm(null)}>
          <p className="mb-[16px] text-[16px]">{d.name}</p>
          {confirm === "reject" ? (
            <DangerButton type="button" onClick={() => void act("reject")}>
              {t.confirm}
            </DangerButton>
          ) : (
            <PrimaryButton type="button" onClick={() => void act("approve")}>
              {t.confirm}
            </PrimaryButton>
          )}
        </Modal>
      ) : null}
    </div>
  )
}
