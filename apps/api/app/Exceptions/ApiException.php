<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;

class ApiException extends Exception
{
    protected string $errorCode;
    protected int $statusCode;
    protected ?array $errors;

    public function __construct(
        string $errorCode,
        string $message,
        int $statusCode = 400,
        ?array $errors = null
    ) {
        parent::__construct($message);
        $this->errorCode = $errorCode;
        $this->statusCode = $statusCode;
        $this->errors = $errors;
    }

    public function render(): JsonResponse
    {
        $payload = [
            'success' => false,
            'error' => [
                'code' => $this->errorCode,
                'message' => $this->getMessage(),
            ],
        ];

        if ($this->errors) {
            $payload['error']['errors'] = $this->errors;
        }

        return response()->json($payload, $this->statusCode);
    }
}
