<?php

namespace App\Jobs;

use App\Services\DispatchService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class DispatchTimeoutJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public int $attemptId) {}

    public function handle(DispatchService $dispatchService): void
    {
        $dispatchService->handleTimeout($this->attemptId);
    }
}
