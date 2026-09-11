<?php

namespace App\Console\Commands;

use App\Models\OtpCode;
use Illuminate\Console\Command;

class PruneOtps extends Command
{
    protected $signature = 'pothik:prune-otps {--chunk=500 : How many rows to delete per query}';
    protected $description = 'Remove OTP rows whose expires_at has passed.';

    public function handle(): int
    {
        $chunk = (int) $this->option('chunk');
        $total = 0;
        do {
            $deleted = OtpCode::where('expires_at', '<', now())->limit($chunk)->delete();
            $total += $deleted;
        } while ($deleted > 0);

        $this->info("Pruned {$total} expired OTP rows.");
        return self::SUCCESS;
    }
}