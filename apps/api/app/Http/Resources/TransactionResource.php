<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Transaction (payment ledger) shape returned via API. Strips internal
 * gateway references — caller should resolve provider_payment_id only
 * via admin endpoints.
 */
class TransactionResource extends JsonResource
{
    // NOTE: parent `JsonResource::toArray($request)` is untyped in
    // this Laravel version; narrowing either the parameter or the
    // return type triggers an LSP fatal at autoload time.
    public function toArray($request)
    {
        $tx = $this->resource;

        return [
            'id' => $tx->id,
            'ride_id' => $tx->ride_id,
            'type' => $tx->type,
            'status' => $tx->status,
            'amount' => (float) $tx->amount,
            'currency' => $tx->currency,
            'held_until' => $tx->held_until?->toIso8601String(),
            'created_at' => $tx->created_at?->toIso8601String(),
            'released_at' => $tx->released_at?->toIso8601String(),
        ];
    }
}
