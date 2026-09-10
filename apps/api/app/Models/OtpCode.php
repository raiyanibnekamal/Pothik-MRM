<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OtpCode extends Model
{
    protected $fillable = ['phone', 'code_hash', 'attempts', 'purpose', 'expires_at'];

    protected $casts = ['expires_at' => 'datetime'];
}
