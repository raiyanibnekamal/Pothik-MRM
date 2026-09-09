<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class SetLocale
{
    public function handle(Request $request, Closure $next)
    {
        $locale = $request->header('Accept-Language', $request->user()?->language ?? 'bn');
        $locale = in_array($locale, ['bn', 'en'], true) ? $locale : 'bn';
        app()->setLocale($locale);

        return $next($request);
    }
}
