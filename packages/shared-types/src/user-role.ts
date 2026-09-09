/** Must match apps/api/app/Enums/UserRole.php */
export const USER_ROLE = {
  PASSENGER: 'passenger',
  DRIVER: 'driver',
  SUPER_ADMIN: 'super_admin',
  SUB_ADMIN_FINANCE: 'sub_admin_finance',
  SUB_ADMIN_SUPPORT: 'sub_admin_support',
  SUB_ADMIN_DISPATCH: 'sub_admin_dispatch',
  SUPPORT_AGENT: 'support_agent',
} as const

export type UserRole = typeof USER_ROLE[keyof typeof USER_ROLE]
