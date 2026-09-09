<?php

namespace App\Constants;

class ErrorCodes
{
    public const INVALID_PHONE = 'INVALID_PHONE';
    public const OTP_EXPIRED = 'OTP_EXPIRED';
    public const OTP_INVALID = 'OTP_INVALID';
    public const OTP_RATE_LIMIT = 'OTP_RATE_LIMIT';
    public const OTP_MAX_ATTEMPTS = 'OTP_MAX_ATTEMPTS';
    public const UNAUTHORIZED = 'UNAUTHORIZED';
    public const FORBIDDEN = 'FORBIDDEN';
    public const NOT_FOUND = 'NOT_FOUND';
    public const VALIDATION_ERROR = 'VALIDATION_ERROR';
    public const DUPLICATE_NID = 'DUPLICATE_NID';
    public const DUPLICATE_PLATE = 'DUPLICATE_PLATE';
    public const NO_DRIVERS = 'NO_DRIVERS';
    public const OUT_OF_ZONE = 'OUT_OF_ZONE';
    public const INVALID_TRANSITION = 'INVALID_TRANSITION';
    public const PIN_MISMATCH = 'PIN_MISMATCH';
    public const ALREADY_PAID = 'ALREADY_PAID';
    public const SOS_NOT_ALLOWED = 'SOS_NOT_ALLOWED';
    public const GUARDIAN_CAP = 'GUARDIAN_CAP';
    public const DUPLICATE_GUARDIAN = 'DUPLICATE_GUARDIAN';
    public const DEBT_CAP = 'DEBT_CAP';
    public const GRACE_OVER = 'GRACE_OVER';
    public const SMS_FAILED = 'SMS_FAILED';
    public const ALREADY_RATED = 'ALREADY_RATED';
    public const BLOCKED = 'BLOCKED';
}
