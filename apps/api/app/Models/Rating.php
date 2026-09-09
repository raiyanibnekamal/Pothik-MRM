<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Rating extends Model
{
    protected $fillable = ['ride_id', 'rater_id', 'rated_id', 'score', 'tags', 'comment'];

    protected $casts = ['tags' => 'array'];

    public function ride(): BelongsTo
    {
        return $this->belongsTo(Ride::class);
    }
}
