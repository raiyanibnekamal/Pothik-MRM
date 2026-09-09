<?php

namespace Database\Seeders;

use App\Enums\UserRole;
use App\Models\PlatformConfig;
use App\Models\ServiceZone;
use App\Models\User;
use App\Models\VehicleType;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        VehicleType::insert([
            [
                'slug' => 'bike',
                'name_en' => 'Bike',
                'name_bn' => 'বাইক',
                'icon' => 'bike',
                'seats' => 1,
                'base_fare' => 30,
                'per_km_rate' => 12,
                'per_min_rate' => 1,
                'min_fare' => 50,
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'slug' => 'car',
                'name_en' => 'Car',
                'name_bn' => 'গাড়ি',
                'icon' => 'car',
                'seats' => 4,
                'base_fare' => 60,
                'per_km_rate' => 25,
                'per_min_rate' => 2,
                'min_fare' => 120,
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        PlatformConfig::set('commission_rate', ['rate' => 20]);
        PlatformConfig::set('debt_cap', ['amount' => 5000]);
        PlatformConfig::set('holding_hours', ['hours' => 24]);
        PlatformConfig::set('min_app_version', ['passenger' => '1.0.0', 'driver' => '1.0.0']);
        PlatformConfig::set('maintenance_mode', ['enabled' => false]);

        ServiceZone::create([
            'name' => 'Dhaka Metro',
            'polygon' => [
                ['lat' => 23.95, 'lng' => 90.25],
                ['lat' => 23.95, 'lng' => 90.55],
                ['lat' => 23.65, 'lng' => 90.55],
                ['lat' => 23.65, 'lng' => 90.25],
            ],
            'is_active' => true,
        ]);

        User::create([
            'id' => (string) Str::uuid(),
            'email' => 'admin@bdride.share',
            'password' => Hash::make('Admin@12345'),
            'name' => 'Super Admin',
            'role' => UserRole::SUPER_ADMIN,
            'language' => 'bn',
        ]);

        User::create([
            'id' => (string) Str::uuid(),
            'phone' => '+8801712345678',
            'name' => 'Test Passenger',
            'role' => UserRole::PASSENGER,
            'language' => 'bn',
        ]);

        $driver = User::create([
            'id' => (string) Str::uuid(),
            'phone' => '+8801812345678',
            'name' => 'Test Driver',
            'role' => UserRole::DRIVER,
            'language' => 'bn',
        ]);

        \App\Models\DriverProfile::create([
            'id' => (string) Str::uuid(),
            'user_id' => $driver->id,
            'vehicle_type_id' => 1,
            'vehicle_make' => 'Honda',
            'vehicle_model' => 'CB150',
            'vehicle_year' => 2020,
            'vehicle_color' => 'Red',
            'plate_no' => 'DHAKA-GA-11-1234',
            'kyc_status' => 'approved',
            'grace_period_expires_at' => now()->addDays(30),
            'current_lat' => 23.8103,
            'current_lng' => 90.4125,
            'location_updated_at' => now(),
        ]);
    }
}
