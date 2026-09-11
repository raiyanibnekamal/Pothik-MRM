<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

/**
 * User shape returned to other users (passenger ↔ driver).
 * NEVER exposes password hashes, internal IDs, or notification/sensitive tokens.
 */
class PublicUserResource extends JsonResource
{
    // NOTE: parent signature in this Laravel version is
    // `public function toArray($request)` without a typed
    // parameter or return type -- narrowing either triggers a
    // LSP fatal. Keep the untyped signature here.
    public function toArray($request)
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'email' => $this->email,
            'photo_url' => $this->photo_url,
            'role' => $this->role,
            'language' => $this->language,
            'rating_avg' => (float) $this->rating_avg,
            'rating_count' => (int) $this->rating_count,
            'is_blocked' => (bool) $this->is_blocked,
        ];
    }
}
