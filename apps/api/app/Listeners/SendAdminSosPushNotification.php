<?php

namespace App\Listeners;

use App\Events\AdminSosAlert;
use App\Models\User;
use App\Services\Fcm\FcmService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Support\Facades\Log;

/**
 * Hooked onto AdminSosAlert so on-call admins receive an OS-level push
 * even when the admin panel tab is closed.
 *
 * Looks up every admin user and pushes to each — admin counts are small
 * (handful), so fan-out per-alert is cheap. If the team grows, switch
 * to a role-based topic.
 *
 * Safe to register with FCM_DEFAULT_PROVIDER=null (logs and returns true).
 */
class SendAdminSosPushNotification implements ShouldQueue
{
    public function __construct(private FcmService $fcm) {}

    public function handle(AdminSosAlert $event): void
    {
        // Schema note: users.role is an enum (super_admin, sub_admin_*,
        // support_agent). users.is_active does not exist — only is_blocked.
        $admins = User::query()
            ->whereIn('role', [
                'super_admin', 'sub_admin_finance', 'sub_admin_support',
                'sub_admin_dispatch', 'support_agent',
            ])
            ->where('is_blocked', false)
            ->pluck('id');

        foreach ($admins as $adminId) {
            $ok = $this->fcm->sendToUser(
                (string) $adminId,
                'SOS triggered',
                sprintf('User #%s triggered SOS (ride #%s)', $event->alert->user_id, $event->alert->ride_id ?? '—'),
                [
                    'alert_id' => (string) $event->alert->id,
                    'type' => 'admin_sos',
                ]
            );

            if (! $ok) {
                Log::warning('fcm.admin_sos_failed', [
                    'admin_id' => $adminId,
                    'alert_id' => $event->alert->id,
                ]);
            }
        }
    }
}
