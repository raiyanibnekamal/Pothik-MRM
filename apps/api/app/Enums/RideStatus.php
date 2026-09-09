<?php

namespace App\Enums;

class RideStatus
{
    public const REQUESTED = 'requested';
    public const ACCEPTED = 'accepted';
    public const DRIVER_ARRIVING = 'driver_arriving';
    public const DRIVER_ARRIVED = 'driver_arrived';
    public const IN_PROGRESS = 'in_progress';
    public const COMPLETED = 'completed';
    public const CANCELLED = 'cancelled';
    public const NO_SHOW = 'no_show';
    public const NO_DRIVER_AVAILABLE = 'no_driver_available';

    public static function transitions(): array
    {
        return [
            self::REQUESTED => [self::ACCEPTED, self::CANCELLED, self::NO_DRIVER_AVAILABLE],
            self::ACCEPTED => [self::DRIVER_ARRIVING, self::CANCELLED],
            self::DRIVER_ARRIVING => [self::DRIVER_ARRIVED, self::CANCELLED],
            self::DRIVER_ARRIVED => [self::IN_PROGRESS, self::CANCELLED, self::NO_SHOW],
            self::IN_PROGRESS => [self::COMPLETED, self::CANCELLED],
            self::COMPLETED => [],
            self::CANCELLED => [],
            self::NO_SHOW => [],
            self::NO_DRIVER_AVAILABLE => [],
        ];
    }

    public static function canTransition(string $from, string $to): bool
    {
        return in_array($to, self::transitions()[$from] ?? [], true);
    }

    public static function activeStatuses(): array
    {
        return [
            self::REQUESTED,
            self::ACCEPTED,
            self::DRIVER_ARRIVING,
            self::DRIVER_ARRIVED,
            self::IN_PROGRESS,
        ];
    }
}
