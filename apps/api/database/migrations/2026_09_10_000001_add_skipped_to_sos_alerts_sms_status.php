<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $driver = Schema::getConnection()->getDriverName();

        if ($driver === 'mysql') {
            DB::statement(
                "ALTER TABLE sos_alerts MODIFY sms_status ENUM('pending', 'sent', 'failed', 'skipped') NOT NULL DEFAULT 'pending'"
            );

            return;
        }

        if ($driver === 'sqlite') {
            DB::statement('PRAGMA foreign_keys=off');

            Schema::create('sos_alerts_new', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('user_id');
                $table->uuid('ride_id')->nullable();
                $table->enum('status', ['active', 'resolved', 'cancelled'])->default('active');
                $table->enum('sms_status', ['pending', 'sent', 'failed', 'skipped'])->default('pending');
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

            DB::statement('INSERT INTO sos_alerts_new SELECT * FROM sos_alerts');
            Schema::drop('sos_alerts');
            Schema::rename('sos_alerts_new', 'sos_alerts');

            DB::statement('PRAGMA foreign_keys=on');
        }
    }

    public function down(): void
    {
        $driver = Schema::getConnection()->getDriverName();

        if ($driver === 'mysql') {
            DB::statement(
                "ALTER TABLE sos_alerts MODIFY sms_status ENUM('pending', 'sent', 'failed') NOT NULL DEFAULT 'pending'"
            );

            return;
        }

        if ($driver === 'sqlite') {
            DB::statement('PRAGMA foreign_keys=off');

            Schema::create('sos_alerts_old', function (Blueprint $table) {
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

            DB::statement(
                "INSERT INTO sos_alerts_old SELECT * FROM sos_alerts WHERE sms_status IN ('pending', 'sent', 'failed')"
            );
            Schema::drop('sos_alerts');
            Schema::rename('sos_alerts_old', 'sos_alerts');

            DB::statement('PRAGMA foreign_keys=on');
        }
    }
};
