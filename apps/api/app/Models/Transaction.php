<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    use HasUuids;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'ride_id', 'user_id', 'type', 'amount', 'status',
        'idempotency_key', 'release_at', 'released_at', 'meta',
    ];

    protected $casts = [
        'release_at' => 'datetime',
        'released_at' => 'datetime',
        'meta' => 'array',
    ];

    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
