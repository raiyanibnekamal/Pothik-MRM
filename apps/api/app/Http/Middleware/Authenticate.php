<?php

namespace App\Http\Middleware;

use Illuminate\Auth\Middleware\Authenticate as Middleware;

class Authenticate extends Middleware
{
    /**
     * API requests never get redirected — they receive a JSON 401.
     * Previously this returned `route('login')` and caused Laravel to
     * emit an HTML debug page when the named route was missing.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return string|null
     */
    protected function redirectTo($request)
    {
        return null;
    }
}
