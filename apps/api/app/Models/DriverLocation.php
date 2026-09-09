<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DriverLocation extends Model
{
    protected $fillable = [
        'driver_id', 'ride_id', 'lat', 'lng', 'speed_kmh', 'speed_jump_flag',
    ];

    protected $casts = ['speed_jump_flag' => 'boolean'];

    public function driver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'driver_id');
    }
}
