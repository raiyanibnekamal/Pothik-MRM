<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('phone', 20)->unique()->nullable();
            $table->string('email')->unique()->nullable();
            $table->string('password')->nullable();
            $table->string('name')->nullable();
            $table->string('photo_url')->nullable();
            $table->enum('role', [
                'passenger', 'driver', 'super_admin', 'sub_admin_finance',
                'sub_admin_support', 'sub_admin_dispatch', 'support_agent',
            ])->default('passenger');
            $table->string('language', 5)->default('bn');
            $table->boolean('is_blocked')->default(false);
            $table->decimal('rating_avg', 3, 2)->default(5.00);
            $table->unsignedInteger('rating_count')->default(0);
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('refresh_tokens', function (Blueprint $table) {
            $table->id();
            $table->uuid('user_id');
            $table->string('token_hash', 64)->unique();
            $table->string('jti', 36)->nullable();
            $table->timestamp('expires_at');
            $table->timestamps();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['user_id', 'expires_at']);
        });

        Schema::create('otp_codes', function (Blueprint $table) {
            $table->id();
            $table->string('phone', 20);
            $table->string('code_hash');
            $table->unsignedTinyInteger('attempts')->default(0);
            $table->string('purpose', 32)->default('login');
            $table->timestamp('expires_at');
            $table->timestamps();
            $table->index(['phone', 'purpose', 'expires_at']);
        });

        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->uuid('user_id');
            $table->string('token', 512);
            $table->string('platform', 16)->nullable();
            $table->timestamps();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['user_id', 'token']);
        });

        Schema::create('vehicle_types', function (Blueprint $table) {
            $table->id();
            $table->string('slug', 32)->unique();
            $table->string('name_en');
            $table->string('name_bn');
            $table->string('icon')->nullable();
            $table->unsignedTinyInteger('seats')->default(1);
            $table->decimal('base_fare', 10, 2);
            $table->decimal('per_km_rate', 10, 2);
            $table->decimal('per_min_rate', 10, 2);
            $table->decimal('min_fare', 10, 2);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('driver_profiles', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id')->unique();
            $table->string('nid', 17)->nullable()->unique();
            $table->date('date_of_birth')->nullable();
            $table->text('address')->nullable();
            $table->foreignId('vehicle_type_id')->nullable()->constrained('vehicle_types');
            $table->string('vehicle_make')->nullable();
            $table->string('vehicle_model')->nullable();
            $table->unsignedSmallInteger('vehicle_year')->nullable();
            $table->string('vehicle_color')->nullable();
            $table->string('plate_no', 20)->nullable()->unique();
            $table->string('vehicle_photo_url')->nullable();
            $table->enum('kyc_status', ['pending', 'approved', 'rejected'])->default('pending');
            $table->text('kyc_rejection_note')->nullable();
            $table->timestamp('grace_period_expires_at')->nullable();
            $table->boolean('is_online')->default(false);
            $table->boolean('is_on_break')->default(false);
            $table->boolean('battery_saver')->default(false);
            $table->decimal('acceptance_rate', 5, 2)->default(100);
            $table->decimal('current_lat', 10, 7)->nullable();
            $table->decimal('current_lng', 10, 7)->nullable();
            $table->timestamp('location_updated_at')->nullable();
            $table->timestamps();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['is_online', 'is_on_break']);
        });

        Schema::create('driver_documents', function (Blueprint $table) {
            $table->id();
            $table->uuid('driver_profile_id');
            $table->enum('doc_type', ['nid', 'license', 'blue_book', 'tax_token', 'fitness', 'profile_photo', 'vehicle_photo']);
            $table->string('file_url');
            $table->enum('status', ['pending', 'verified', 'rejected'])->default('pending');
            $table->text('rejection_note')->nullable();
            $table->timestamps();
            $table->foreign('driver_profile_id')->references('id')->on('driver_profiles')->cascadeOnDelete();
            $table->unique(['driver_profile_id', 'doc_type']);
        });

        Schema::create('emergency_contacts', function (Blueprint $table) {
            $table->id();
            $table->uuid('user_id');
            $table->string('name');
            $table->string('phone', 20);
            $table->boolean('is_verified')->default(false);
            $table->timestamps();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['user_id', 'phone']);
        });

        Schema::create('service_zones', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->json('polygon');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('platform_config', function (Blueprint $table) {
            $table->string('key')->primary();
            $table->json('value');
            $table->timestamps();
        });

        Schema::create('rides', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('passenger_id');
            $table->uuid('driver_id')->nullable();
            $table->foreignId('vehicle_type_id');
            $table->enum('status', [
                'requested', 'accepted', 'driver_arriving', 'driver_arrived',
                'in_progress', 'completed', 'cancelled', 'no_show', 'no_driver_available',
            ])->default('requested');
            $table->enum('payment_method', ['cash', 'bkash', 'nagad', 'wallet', 'card'])->default('cash');
            $table->decimal('pickup_lat', 10, 7);
            $table->decimal('pickup_lng', 10, 7);
            $table->string('pickup_address');
            $table->decimal('drop_lat', 10, 7);
            $table->decimal('drop_lng', 10, 7);
            $table->string('drop_address');
            $table->decimal('estimated_distance_km', 8, 2)->nullable();
            $table->unsignedInteger('estimated_duration_min')->nullable();
            $table->decimal('estimated_fare', 10, 2)->nullable();
            $table->decimal('locked_fare', 10, 2)->nullable();
            $table->decimal('final_fare', 10, 2)->nullable();
            $table->boolean('fare_locked_with_google')->default(false);
            $table->boolean('fare_flagged_for_ops')->default(false);
            $table->string('pin', 4)->nullable();
            $table->string('share_token', 64)->nullable()->unique();
            $table->string('track_token', 64)->nullable()->unique();
            $table->boolean('sos_active')->default(false);
            $table->timestamp('matched_at')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->string('cancel_reason')->nullable();
            $table->uuid('cancelled_by')->nullable();
            $table->timestamps();
            $table->foreign('passenger_id')->references('id')->on('users');
            $table->foreign('driver_id')->references('id')->on('users')->nullOnDelete();
            $table->foreign('vehicle_type_id')->references('id')->on('vehicle_types');
            $table->index(['status', 'passenger_id']);
            $table->index(['status', 'driver_id']);
        });

        Schema::create('ride_dispatch_attempts', function (Blueprint $table) {
            $table->id();
            $table->uuid('ride_id');
            $table->uuid('driver_id');
            $table->enum('result', ['pending', 'accepted', 'declined', 'timeout'])->default('pending');
            $table->timestamp('offered_at');
            $table->timestamp('responded_at')->nullable();
            $table->timestamps();
            $table->foreign('ride_id')->references('id')->on('rides')->cascadeOnDelete();
            $table->foreign('driver_id')->references('id')->on('users');
            $table->index(['ride_id', 'result']);
        });

        Schema::create('driver_locations', function (Blueprint $table) {
            $table->id();
            $table->uuid('driver_id');
            $table->uuid('ride_id')->nullable();
            $table->decimal('lat', 10, 7);
            $table->decimal('lng', 10, 7);
            $table->decimal('speed_kmh', 6, 2)->nullable();
            $table->boolean('speed_jump_flag')->default(false);
            $table->timestamps();
            $table->foreign('driver_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['driver_id', 'created_at']);
        });

        Schema::create('sos_alerts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->uuid('ride_id')->nullable();
            $table->enum('status', ['active', 'resolved', 'cancelled'])->default('active');
            $table->enum('sms_status', ['pending', 'sent', 'failed'])->default('pending');
            $table->enum('trigger_type', [
                'hold', 'shake', 'power', 'ridecheck_deviation', 'ridecheck_stop',
                'checkin_timeout', 'crash', 'admin',
            ])->default('hold');
            $table->decimal('lat', 10, 7)->nullable();
            $table->decimal('lng', 10, 7)->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->uuid('resolved_by')->nullable();
            $table->timestamps();
            $table->foreign('user_id')->references('id')->on('users');
            $table->foreign('ride_id')->references('id')->on('rides')->nullOnDelete();
            $table->index(['status', 'created_at']);
        });

        Schema::create('transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('ride_id')->nullable();
            $table->uuid('user_id');
            $table->enum('type', [
                'ride_payment', 'commission_debt', 'commission_payment',
                'payout', 'refund', 'holding',
            ]);
            $table->decimal('amount', 12, 2);
            $table->enum('status', ['pending', 'held', 'released', 'completed', 'failed'])->default('pending');
            $table->string('idempotency_key', 64)->nullable()->unique();
            $table->timestamp('release_at')->nullable();
            $table->timestamp('released_at')->nullable();
            $table->json('meta')->nullable();
            $table->timestamps();
            $table->foreign('ride_id')->references('id')->on('rides')->nullOnDelete();
            $table->foreign('user_id')->references('id')->on('users');
            $table->index(['user_id', 'type', 'status']);
        });

        Schema::create('driver_commission_debts', function (Blueprint $table) {
            $table->id();
            $table->uuid('driver_id');
            $table->uuid('ride_id');
            $table->uuid('transaction_id')->nullable();
            $table->decimal('amount', 12, 2);
            $table->decimal('commission_rate', 5, 2)->default(20.00);
            $table->boolean('is_paid')->default(false);
            $table->timestamps();
            $table->foreign('driver_id')->references('id')->on('users');
            $table->foreign('ride_id')->references('id')->on('rides');
            $table->unique(['ride_id']);
        });

        Schema::create('ratings', function (Blueprint $table) {
            $table->id();
            $table->uuid('ride_id');
            $table->uuid('rater_id');
            $table->uuid('rated_id');
            $table->unsignedTinyInteger('score');
            $table->json('tags')->nullable();
            $table->text('comment')->nullable();
            $table->timestamps();
            $table->foreign('ride_id')->references('id')->on('rides')->cascadeOnDelete();
            $table->foreign('rater_id')->references('id')->on('users');
            $table->foreign('rated_id')->references('id')->on('users');
            $table->unique(['ride_id', 'rater_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ratings');
        Schema::dropIfExists('driver_commission_debts');
        Schema::dropIfExists('transactions');
        Schema::dropIfExists('sos_alerts');
        Schema::dropIfExists('driver_locations');
        Schema::dropIfExists('ride_dispatch_attempts');
        Schema::dropIfExists('rides');
        Schema::dropIfExists('platform_config');
        Schema::dropIfExists('service_zones');
        Schema::dropIfExists('emergency_contacts');
        Schema::dropIfExists('driver_documents');
        Schema::dropIfExists('driver_profiles');
        Schema::dropIfExists('vehicle_types');
        Schema::dropIfExists('device_tokens');
        Schema::dropIfExists('otp_codes');
        Schema::dropIfExists('refresh_tokens');
        Schema::dropIfExists('users');
    }
};
