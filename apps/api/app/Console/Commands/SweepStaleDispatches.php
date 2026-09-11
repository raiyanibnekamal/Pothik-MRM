<?php

namespace App\Console\Commands;

use App\Models\RideDispatchAttempt;
use App\Services\DispatchService;
use Illuminate\Console\Command;

/**
 * Periodic safety-net for orphaned dispatch attempts.
 *
 * Each individual ride offer schedules its own DispatchTimeoutJob, but if the
 * queue worker restarts mid-flight (or the job is lost on Redis flush) the
 * attempt can stay `pending` forever and block the next-driver rotation.
 * This sweep finds those attempts and treats them as timeouts.
 */
class SweepStaleDispatches extends Command
{
    protected $signature = "pothik:sweep-stale-dispatches
        {--max-age=120 : Attempts older than this many seconds are considered stale}";

    protected $description = "Reap dispatch attempts stuck in pending past their offer window.";

    public function handle(DispatchService $service): int
    {
        $maxAge = (int) $this->option("max-age");
        $cutoff = now()->subSeconds($maxAge);

        $stale = RideDispatchAttempt::where("result", "pending")
            ->where("offered_at", "<=", $cutoff)
            ->orderBy("offered_at")
            ->limit(100)
            ->get();

        $count = 0;
        foreach ($stale as $attempt) {
            $service->handleTimeout($attempt->id);
            $count++;
        }

        $this->info("Reaped {$count} stale dispatch attempts older than {$maxAge}s.");

        return self::SUCCESS;
    }
}