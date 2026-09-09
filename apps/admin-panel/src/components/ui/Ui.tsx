import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from "react"

export function PrimaryButton({
  children,
  loading,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { loading?: boolean }) {
  return (
    <button
      {...props}
      className="inline-flex h-[48px] w-full items-center justify-center rounded-[12px] bg-[var(--interactive-accent)] px-[16px] text-[16px] font-semibold text-[var(--text-on-accent)] disabled:bg-[var(--interactive-disabled-bg)] disabled:text-[var(--interactive-disabled-text)]"
    >
      {loading ? "…" : children}
    </button>
  )
}

export function SecondaryButton({
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      {...props}
      className="inline-flex h-[48px] items-center justify-center rounded-[12px] border border-[var(--interactive-primary)] bg-transparent px-[16px] text-[16px] font-semibold text-[var(--interactive-primary)]"
    >
      {children}
    </button>
  )
}

export function DangerButton({
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      {...props}
      className="inline-flex h-[48px] items-center justify-center rounded-[12px] bg-[var(--danger)] px-[16px] text-[16px] font-semibold text-[var(--text-on-primary)]"
    >
      {children}
    </button>
  )
}

export function Field({
  label,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & { label: string }) {
  return (
    <label className="block">
      <span className="mb-[8px] block text-[14px] font-medium">{label}</span>
      <input
        {...props}
        className="h-[56px] w-full rounded-[12px] border border-[var(--border-strong)] bg-[var(--surface)] px-[16px] text-[16px] text-[var(--text-primary)]"
      />
    </label>
  )
}

export function Card({ children }: { children: ReactNode }) {
  return (
    <div className="rounded-[12px] border border-[var(--border-default)] bg-[var(--surface)] p-[16px]">
      {children}
    </div>
  )
}

export function Badge({
  children,
  tone = "navy",
}: {
  children: ReactNode
  tone?: "navy" | "success" | "danger" | "warning"
}) {
  const map = {
    navy: "bg-[var(--navy-50)] text-[var(--navy-900)]",
    success: "bg-[var(--success-bg)] text-[var(--success)]",
    danger: "bg-[var(--danger-bg)] text-[var(--danger)]",
    warning: "bg-[var(--warning-bg)] text-[var(--warning)]",
  }
  return (
    <span className={`inline-flex rounded-[8px] px-[8px] py-[4px] text-[12px] ${map[tone]}`}>
      {children}
    </span>
  )
}

export function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <p className="text-[12px] text-[var(--text-secondary)]">{label}</p>
      <p className="font-num mt-[8px] text-[32px] font-semibold leading-none">{value}</p>
    </Card>
  )
}

export function Modal({
  title,
  children,
  onClose,
}: {
  title: string
  children: ReactNode
  onClose: () => void
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-[color-mix(in_srgb,var(--navy-950)_40%,transparent)]">
      <div className="w-[480px] max-w-[90vw] rounded-[20px] bg-[var(--surface)] p-[24px] shadow-[var(--shadow-md)]">
        <div className="mb-[16px] flex items-center justify-between">
          <h2 className="text-[22px] font-semibold">{title}</h2>
          <button type="button" onClick={onClose} className="min-h-[44px] min-w-[44px]">
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  )
}
