<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RideDispatchAttempt extends Model
{
    protected $fillable = ['ride_id', 'driver_id', 'result', 'offered_at', 'responded_at'];

    protected $casts = [
        'offered_at' => 'datetime',
        'responded_at' => 'datetime',
    ];

    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }

    public function driver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'driver_id');
    }
}
