<?php

namespace App\Services\Sms;

/**
 * Contract for an SMS gateway provider.
 *
 * Every gateway implementation returns true on accepted-by-the-provider and
 * false on any failure mode (network, 4xx/5xx, missing config). Callers use
 * the boolean to decide whether to mark the related row (e.g. sos_alerts)
 * as sent or failed.
 */
interface SmsGateway
{
    /**
     * Send a plain text SMS.
     *
     * @param  string  $phone   E.164 international format (e.g. +8801XXXXXXXXX)
     * @param  string  $message UTF-8 message body
     * @return bool             true if the provider acknowledged the send
     */
    public function send(string $phone, string $message): bool;

    /**
     * Stable identifier for this driver — used by the gateway manager to
     * resolve it from config and by tests to fake it.
     */
    public function name(): string;
}
