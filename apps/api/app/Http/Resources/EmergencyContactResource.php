<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Emergency contact shape. Strips user_id (internal ownership column);
 * never leaks the parent user UUID.
 */
class EmergencyContactResource extends JsonResource
{
    // NOTE: parent `JsonResource::toArray($request)` is untyped in
    // this Laravel version; narrowing either the parameter or the
    // return type triggers an LSP fatal at autoload time.
    public function toArray($request)
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'is_verified' => (bool) $this->is_verified,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
