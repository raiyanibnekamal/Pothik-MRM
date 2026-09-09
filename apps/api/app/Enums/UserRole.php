<?php

namespace App\Enums;

class UserRole
{
    public const PASSENGER = 'passenger';
    public const DRIVER = 'driver';
    public const SUPER_ADMIN = 'super_admin';
    public const SUB_ADMIN_FINANCE = 'sub_admin_finance';
    public const SUB_ADMIN_SUPPORT = 'sub_admin_support';
    public const SUB_ADMIN_DISPATCH = 'sub_admin_dispatch';
    public const SUPPORT_AGENT = 'support_agent';

    public static function adminRoles(): array
    {
        return [
            self::SUPER_ADMIN,
            self::SUB_ADMIN_FINANCE,
            self::SUB_ADMIN_SUPPORT,
            self::SUB_ADMIN_DISPATCH,
            self::SUPPORT_AGENT,
        ];
    }

    public static function isAdmin(string $role): bool
    {
        return in_array($role, self::adminRoles(), true);
    }
}
