<?php

namespace App\Services;

use App\Services\Sms\GatewayManager;

/**
 * Thin façade in front of the SMS gateway layer.
 *
 * The app's existing call sites (OtpService, SosService, future notification
 * paths) all go through this class instead of resolving a gateway directly,
 * which keeps the gateway layer swappable and gives us one place to add
 * cross-cutting concerns (logging, retry, queueing) later.
 *
 * Methods kept deliberately narrow so call sites stay readable:
 *   send()    — plain SMS, e.g. OTP body
 *   sendSos() — emergency guardian notification, currently identical wire
 *               call but separated so future per-message routing (e.g.
 *               short-link tracking, masking overrides) can fork here
 *               without touching the OTP path.
 */
class SmsService
{
    public function __construct(private GatewayManager $gateways) {}

    /**
     * Send a plain SMS.
     *
     * @param  string  $phone   E.164 format (e.g. +8801XXXXXXXXX)
     * @param  string  $message UTF-8 message body
     * @return bool             true if the gateway acknowledged the send
     */
    public function send(string $phone, string $message): bool
    {
        return $this->gateways->driver()->send($phone, $message);
    }

    /**
     * Send an SOS guardian notification.
     *
     * Same wire call as send() today, but kept distinct so we can later
     * route SOS traffic through a dedicated provider or apply different
     * retry/audit rules without disturbing OTP delivery.
     *
     * @param  string  $phone   E.164 format (e.g. +8801XXXXXXXXX)
     * @param  string  $message UTF-8 message body
     * @return bool             true if the gateway acknowledged the send
     */
    public function sendSos(string $phone, string $message): bool
    {
        return $this->gateways->driver()->send($phone, $message);
    }
}
