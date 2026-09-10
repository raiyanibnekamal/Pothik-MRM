import { useEffect, useState } from "react"
import { api, type UserRow } from "../api/client"
import { DangerButton, Modal, SecondaryButton } from "../components/ui/Ui"
import { useT } from "../i18n/LocaleProvider"

export function UsersPage() {
  const { t } = useT()
  const [rows, setRows] = useState<UserRow[]>([])
  const [q, setQ] = useState("")
  const [target, setTarget] = useState<UserRow | null>(null)

  async function refresh() {
    setRows(await api<UserRow[]>("/admin/users"))
  }

  useEffect(() => {
    void refresh()
  }, [])

  const needle = q.trim().toLowerCase()
  const filtered = rows.filter(
    (u) =>
      u.name.toLowerCase().includes(needle) ||
      u.phone.toLowerCase().includes(needle) ||
      u.role.toLowerCase().includes(needle),
  )

  return (
    <div>
      <h1 className="mb-[16px] text-[22px] font-semibold">{t.users}</h1>
      <input
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={t.search}
        className="mb-[16px] h-[56px] w-full max-w-md rounded-[12px] border border-[var(--border-strong)] px-[16px]"
      />
      <div className="overflow-x-auto rounded-[12px] border border-[var(--border-default)] bg-[var(--surface)]">
        <table className="w-full text-left">
          <thead>
            <tr className="border-b border-[var(--border-default)]">
              <th className="px-[16px] py-[12px]">{t.name}</th>
              <th className="px-[16px] py-[12px]">{t.phone}</th>
              <th className="px-[16px] py-[12px]">{t.role}</th>
              <th className="px-[16px] py-[12px]">{t.status}</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td className="px-[16px] py-[24px] text-[var(--text-secondary)]" colSpan={4}>
                  {t.noResults}
                </td>
              </tr>
            ) : (
              filtered.map((u) => (
                <tr
                  key={u.id}
                  className="h-[48px] cursor-pointer border-b border-[var(--border-default)]"
                  onClick={() => setTarget(u)}
                >
                  <td className="px-[16px]">{u.name}</td>
                  <td className="font-num px-[16px]">{u.phone}</td>
                  <td className="px-[16px]">{u.role}</td>
                  <td className="px-[16px]">{u.blocked ? t.blocked : t.active}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
      {target ? (
        <Modal
          title={
            target.role === "super_admin"
              ? t.role
              : target.blocked
                ? t.unblock
                : t.block
          }
          onClose={() => setTarget(null)}
        >
          <p className="mb-[8px]">{target.name}</p>
          <p className="font-num mb-[16px] text-[14px] text-[var(--text-secondary)]">
            {target.phone}
          </p>
          {target.role === "super_admin" ? (
            <>
              <p className="mb-[16px] text-[14px]">{t.cannotBlockAdmin}</p>
              <SecondaryButton type="button" onClick={() => setTarget(null)}>
                {t.cancel}
              </SecondaryButton>
            </>
          ) : (
            <div className="flex gap-[12px]">
              <DangerButton
                type="button"
                onClick={() => {
                  void api(`/admin/users/${target.id}/block`, { method: "PUT" }).then(() => {
                    setTarget(null)
                    void refresh()
                  })
                }}
              >
                {t.confirm}
              </DangerButton>
              <SecondaryButton type="button" onClick={() => setTarget(null)}>
                {t.cancel}
              </SecondaryButton>
            </div>
          )}
        </Modal>
      ) : null}
    </div>
  )
}
