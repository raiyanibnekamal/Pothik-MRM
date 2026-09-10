<?php

namespace App\Models;

use App\Enums\UserRole;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Tymon\JWTAuth\Contracts\JWTSubject;

class User extends Authenticatable implements JWTSubject
{
    use HasFactory, HasUuids, Notifiable, SoftDeletes;

    protected $keyType = 'string';
    public $incrementing = false;

    protected $fillable = [
        'phone', 'email', 'password', 'name', 'photo_url',
        'role', 'language', 'is_blocked', 'rating_avg', 'rating_count',
    ];

    protected $hidden = ['password'];

    protected $casts = [
        'is_blocked' => 'boolean',
        'rating_avg' => 'float',
    ];

    public function getJWTIdentifier(): mixed
    {
        return $this->getKey();
    }

    public function getJWTCustomClaims(): array
    {
        return [
            'role' => $this->role,
            'jti' => (string) str()->uuid(),
        ];
    }

    public function driverProfile(): HasOne
    {
        return $this->hasOne(DriverProfile::class);
    }

    public function emergencyContacts(): HasMany
    {
        return $this->hasMany(EmergencyContact::class);
    }

    public function deviceTokens(): HasMany
    {
        return $this->hasMany(DeviceToken::class);
    }

    public function isPassenger(): bool
    {
        return $this->role === UserRole::PASSENGER;
    }

    public function isDriver(): bool
    {
        return $this->role === UserRole::DRIVER;
    }

    public function isAdmin(): bool
    {
        return UserRole::isAdmin($this->role);
    }
}
