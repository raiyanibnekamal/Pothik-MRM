<?php

namespace App\Services;

use App\Constants\ErrorCodes;
use App\Exceptions\ApiException;
use App\Models\OtpCode;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;

class OtpService
{
    private const OTP_LENGTH = 6;
    private const OTP_TTL_MINUTES = 5;
    private const MAX_ATTEMPTS = 5;
    private const SEND_LIMIT = 3;
    private const SEND_WINDOW_MINUTES = 10;

    public function requestOtp(string $phone, string $purpose = 'login'): void
    {
        $this->validatePhone($phone);

        $rateKey = 'otp:' . $phone . ':' . request()->ip();
        if (RateLimiter::tooManyAttempts($rateKey, self::SEND_LIMIT)) {
            throw new ApiException(
                ErrorCodes::OTP_RATE_LIMIT,
                'Try again in a moment.',
                429
            );
        }

        RateLimiter::hit($rateKey, self::SEND_WINDOW_MINUTES * 60);

        $code = str_pad((string) random_int(0, 999999), self::OTP_LENGTH, '0', STR_PAD_LEFT);

        OtpCode::where('phone', $phone)
            ->where('purpose', $purpose)
            ->delete();

        OtpCode::create([
            'phone' => $phone,
            'code_hash' => Hash::make($code),
            'purpose' => $purpose,
            'expires_at' => now()->addMinutes(self::OTP_TTL_MINUTES),
        ]);

        if (app()->environment('local', 'testing')) {
            Log::info('OTP generated', ['phone' => $this->maskPhone($phone), 'code' => $code]);
        } else {
            app(SmsService::class)->sendOtp($phone, $code);
        }
    }

    public function verifyOtp(string $phone, string $code, string $purpose = 'login'): void
    {
        $this->validatePhone($phone);

        $otp = OtpCode::where('phone', $phone)
            ->where('purpose', $purpose)
            ->latest()
            ->first();

        if (!$otp) {
            throw new ApiException(ErrorCodes::OTP_EXPIRED, 'OTP expired. Please request a new one.', 400);
        }

        if ($otp->expires_at->isPast()) {
            $otp->delete();
            throw new ApiException(ErrorCodes::OTP_EXPIRED, 'OTP expired. Please request a new one.', 400);
        }

        if ($otp->attempts >= self::MAX_ATTEMPTS) {
            throw new ApiException(ErrorCodes::OTP_MAX_ATTEMPTS, 'OTP attempt limit reached.', 429);
        }

        if (!Hash::check($code, $otp->code_hash)) {
            $otp->increment('attempts');
            $remaining = self::MAX_ATTEMPTS - $otp->attempts;
            throw new ApiException(
                ErrorCodes::OTP_INVALID,
                trans('Wrong OTP. :remaining attempts remaining.', ['remaining' => $remaining]),
                400
            );
        }

        $otp->delete();
    }

    public function validatePhone(string $phone): void
    {
        if (!preg_match('/^\+8801[3-9]\d{8}$/', $phone)) {
            throw new ApiException(
                ErrorCodes::INVALID_PHONE,
                'Please enter a valid Bangladeshi mobile number.',
                422
            );
        }
    }

    private function maskPhone(string $phone): string
    {
        return substr($phone, 0, 7) . '****' . substr($phone, -2);
    }
}
