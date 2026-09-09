<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class VehicleType extends Model
{
    protected $fillable = [
        'slug', 'name_en', 'name_bn', 'icon', 'seats',
        'base_fare', 'per_km_rate', 'per_min_rate', 'min_fare', 'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'base_fare' => 'float',
        'per_km_rate' => 'float',
        'per_min_rate' => 'float',
        'min_fare' => 'float',
    ];
}
