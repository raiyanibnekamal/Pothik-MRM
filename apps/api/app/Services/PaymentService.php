<?php

namespace App\Services;

use App\Constants\ErrorCodes;
use App\Enums\RideStatus;
use App\Exceptions\ApiException;
use App\Models\DriverCommissionDebt;
use App\Models\PlatformConfig;
use App\Models\Ride;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class PaymentService
{
    public function confirmCash(Ride $ride, User $driver, float $amountCollected, ?string $idempotencyKey = null): array
    {
        if ($ride->driver_id !== $driver->id) {
            throw new ApiException(ErrorCodes::FORBIDDEN, 'Forbidden', 403);
        }

        if ($ride->status !== RideStatus::IN_PROGRESS && $ride->status !== RideStatus::COMPLETED) {
            throw new ApiException(ErrorCodes::INVALID_TRANSITION, 'Invalid ride status', 409);
        }

        if ($idempotencyKey) {
            $existing = Transaction::where('idempotency_key', $idempotencyKey)->first();
            if ($existing) {
                return ['transaction' => $existing, 'already_processed' => true];
            }
        }

        $existingPayment = Transaction::where('ride_id', $ride->id)
            ->where('type', 'ride_payment')
            ->whereIn('status', ['held', 'released', 'completed'])
            ->first();

        if ($existingPayment) {
            throw new ApiException(ErrorCodes::ALREADY_PAID, 'পেমেন্ট ইতিমধ্যে নিশ্চিত।', 409);
        }

        $lockedFare = (float) $ride->locked_fare;
        if (abs($amountCollected - $lockedFare) > 0.01) {
            throw new ApiException(
                ErrorCodes::VALIDATION_ERROR,
                "Amount must equal locked fare ৳{$lockedFare}",
                422
            );
        }

        $holdHours = (int) (PlatformConfig::get('holding_hours', ['hours' => 24])['hours'] ?? 24);
        $commissionRate = app(FareService::class)->getCommissionRate();
        $commission = round($lockedFare * ($commissionRate / 100), 2);

        return DB::transaction(function () use ($ride, $driver, $lockedFare, $idempotencyKey, $holdHours, $commissionRate, $commission) {
            $txn = Transaction::create([
                'ride_id' => $ride->id,
                'user_id' => $ride->passenger_id,
                'type' => 'ride_payment',
                'amount' => $lockedFare,
                'status' => 'held',
                'idempotency_key' => $idempotencyKey,
                'release_at' => now()->addHours($holdHours),
                'meta' => ['payment_method' => 'cash'],
            ]);

            DriverCommissionDebt::create([
                'driver_id' => $driver->id,
                'ride_id' => $ride->id,
                'transaction_id' => $txn->id,
                'amount' => $commission,
                'commission_rate' => $commissionRate,
            ]);

            if ($ride->status !== RideStatus::COMPLETED) {
                $ride->update([
                    'status' => RideStatus::COMPLETED,
                    'final_fare' => $lockedFare,
                    'completed_at' => now(),
                ]);
            }

            return ['transaction' => $txn, 'commission_debt' => $commission, 'already_processed' => false];
        });
    }

    public function releaseHeldTransactions(): int
    {
        $count = 0;
        Transaction::where('status', 'held')
            ->where('release_at', '<=', now())
            ->chunkById(100, function ($transactions) use (&$count) {
                foreach ($transactions as $txn) {
                    $txn->update(['status' => 'released', 'released_at' => now()]);
                    $count++;
                }
            });

        return $count;
    }
}
