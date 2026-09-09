<?php

namespace App\Exceptions;

use App\Constants\ErrorCodes;
use App\Support\ApiResponse;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;
use Throwable;
use Tymon\JWTAuth\Exceptions\JWTException;
use Tymon\JWTAuth\Exceptions\TokenExpiredException;
use Tymon\JWTAuth\Exceptions\TokenInvalidException;

class Handler extends ExceptionHandler
{
    protected $dontReport = [];

    protected $dontFlash = [
        'current_password',
        'password',
        'password_confirmation',
    ];

    public function register()
    {
        $this->reportable(function (Throwable $e) {
            //
        });
    }

    public function render($request, Throwable $e)
    {
        if ($request->is('api/*') || $request->expectsJson()) {
            if ($e instanceof ApiException) {
                return $e->render();
            }

            if ($e instanceof ValidationException) {
                return ApiResponse::error(
                    ErrorCodes::VALIDATION_ERROR,
                    'Validation failed',
                    422,
                    $e->errors()
                );
            }

            if ($e instanceof AuthenticationException || $e instanceof TokenExpiredException || $e instanceof TokenInvalidException || $e instanceof JWTException) {
                return ApiResponse::error(ErrorCodes::UNAUTHORIZED, 'Unauthorized', 401);
            }
        }

        return parent::render($request, $e);
    }
}
