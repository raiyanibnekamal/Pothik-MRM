<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ServiceZone extends Model
{
    protected $fillable = ['name', 'polygon', 'is_active'];

    protected $casts = [
        'polygon' => 'array',
        'is_active' => 'boolean',
    ];
}
