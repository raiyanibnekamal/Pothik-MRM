<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     *
     * @param  \Illuminate\Console\Scheduling\Schedule  $schedule
     * @return void
     */
    protected function schedule(Schedule $schedule)
    {
        // Release any transactions that have been in `held` status past the
        // platform-configured holding window — this is the safety net for
        // payment holds that never received an explicit driver payout event.
        $schedule->job(new \App\Jobs\ReleaseHeldPayoutJob())->hourly();

        // Sweep stale dispatch attempts every 5 minutes. Individual ride
        // timeouts are also handled in-line by DispatchTimeoutJob, but a
        // periodic sweep catches orphaned attempts after server restarts.
        $schedule->command('pothik:sweep-stale-dispatches')->everyFiveMinutes();

        // Prune expired OTP rows so the otps table doesn't grow unbounded.
        // OtpService rotates a TTL on every row, so this is a pure reclaim.
        $schedule->command('pothik:prune-otps')->daily();
    }

    /**
     * Register the commands for the application.
     *
     * @return void
     */
    protected function commands()
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}
