<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DriverCommissionDebt extends Model
{
    protected $fillable = [
        'driver_id', 'ride_id', 'transaction_id', 'amount', 'commission_rate', 'is_paid',
    ];

    protected $casts = ['is_paid' => 'boolean'];

    public function driver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }
}
