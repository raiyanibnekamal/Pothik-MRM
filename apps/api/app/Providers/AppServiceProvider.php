<?php

namespace App\Providers;

use App\Broadcasting\TestBroadcaster;
use App\Services\Fcm\FirebaseFcmService;
use App\Services\Fcm\FcmService;
use App\Services\Fcm\NullFcmService;
use App\Services\Payment\BkashGateway;
use App\Services\Payment\MobileBankingGateway;
use App\Services\Payment\NagadGateway;
use App\Services\Payment\NullGateway as NullPaymentGateway;
use App\Services\Payment\PaymentManager;
use App\Services\Sms\GatewayManager;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Broadcast;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     *
     * @return void
     */
    public function register()
    {
        // Bind the SMS gateway manager as a singleton so the configured
        // provider is resolved once per request and shared between the
        // SmsService injection (used by OTP/SOS paths) and any direct
        // resolution in tests/factories.
        $this->app->singleton(GatewayManager::class, function ($app) {
            return new GatewayManager(config('sms', []));
        });

        // Same shape for the mobile-banking payment gateway. Drivers
        // (Bkash, Nagad, …) are stateless, so the manager itself doesn't
        // need to be a singleton beyond test convenience.
        $this->app->singleton(PaymentManager::class, function ($app) {
            return new PaymentManager(config('payment', []));
        });

        // The FCM gateway is resolved into whichever driver the env picks.
        // We bind the interface to the resolved instance so call sites can
        // type-hint FcmService and ignore the manager.
        $this->app->singleton(FcmService::class, function ($app) {
            $name = config('fcm.default', 'null');

            if ($name === 'firebase') {
                $cfg = config('fcm.providers.firebase', []);
                return new FirebaseFcmService(
                    projectId: (string) ($cfg['project_id'] ?? ''),
                    credentialsPath: (string) ($cfg['credentials_path'] ?? ''),
                    timeout: (int) ($cfg['timeout'] ?? 10),
                );
            }

            return new NullFcmService();
        });

        // Surface the FCM manager constructor bindings too (PaymentManager
        // doesn't have a separate manager class — it is itself the resolver).
        $this->app->bind(MobileBankingGateway::class, function ($app) {
            return $app->make(PaymentManager::class)->driver();
        });
        $this->app->bind(NullPaymentGateway::class, function () {
            return new NullPaymentGateway();
        });
        $this->app->bind(BkashGateway::class, function ($app) {
            $cfg = config('payment.providers.bkash', []);
            return new BkashGateway(
                username: (string) ($cfg['username'] ?? ''),
                password: (string) ($cfg['password'] ?? ''),
                appKey: (string) ($cfg['app_key'] ?? ''),
                appSecret: (string) ($cfg['app_secret'] ?? ''),
                baseUrl: (string) ($cfg['base_url'] ?? 'https://tokenized.pay.bka.sh/v1.2.0-beta'),
                timeout: (int) ($cfg['timeout'] ?? 15),
            );
        });
        $this->app->bind(NagadGateway::class, function ($app) {
            $cfg = config('payment.providers.nagad', []);
            return new NagadGateway(
                merchantId: (string) ($cfg['merchant_id'] ?? ''),
                merchantKey: (string) ($cfg['merchant_key'] ?? ''),
                baseUrl: (string) ($cfg['base_url'] ?? 'https://sandbox.mynagad.com:10080/remote-payment-gateway-1.0'),
                timeout: (int) ($cfg['timeout'] ?? 15),
            );
        });
    }

    /**
     * Bootstrap any application services.
     *
     * @return void
     */
    public function boot()
    {
        $this->registerOtpRateLimiter();
        $this->registerRideRateLimiter();
        $this->registerSosRateLimiter();
        $this->registerDriverLocationRateLimiter();
        $this->registerBroadcastDrivers();
    }

    /**
     * Map our custom `test` driver name to App\Broadcasting\TestBroadcaster
     * so feature tests can exercise the routes/channels.php closures
     * without standing up a real Reverb/Pusher broker.
     */
    protected function registerBroadcastDrivers(): void
    {
        Broadcast::extend('test', function ($app) {
            return new TestBroadcaster();
        });
    }

    /**
     * "otp" limiter used by the OTP routes.
     *
     * Two limits are applied simultaneously:
     *   - phone: phone_per_minute (default 3) — protects a victim whose
     *     number is being abused.
     *   - ip:    ip_per_minute (default 10) — protects against a single
     *     attacker trying every number in the country.
     *
     * The lower of the two counts down first, so a single phone from a
     * single IP triggers the phone limit while many phones from one IP
     * trigger the IP limit.
     */
    protected function registerOtpRateLimiter(): void
    {
        RateLimiter::for('otp', function (Request $request) {
            $config = config('sms.rate_limit', []);

            $phoneLimit = (int) ($config['phone_per_minute'] ?? 3);
            $ipLimit = (int) ($config['ip_per_minute'] ?? 10);

            $phone = (string) $request->input('phone', '');

            $limits = [];

            if ($phone !== '') {
                $limits[] = Limit::perMinute($phoneLimit)
                    ->by('otp:phone:' . $phone);
            }

            $limits[] = Limit::perMinute($ipLimit)
                ->by('otp:ip:' . $request->ip());

            return $limits;
        });
    }

    /**
     * "rides" limiter used by the ride-create endpoint.
     *
     * Passengers can't realistically request more than ~3 rides per
     * minute — anything beyond that is either a misclick, a buggy client,
     * or someone trying to flood the dispatch system. We key by user id
     * (when authenticated) so the same phone from two accounts isn't
     * unfairly blocked together.
     */
    protected function registerRideRateLimiter(): void
    {
        RateLimiter::for('rides', function (Request $request) {
            $userId = optional($request->user())->id;

            return Limit::perMinute(3)->by('rides:user:' . ($userId ?: $request->ip()));
        });
    }

    /**
     * "sos" limiter used by the SOS-trigger endpoint.
     *
     * A genuine SOS is a one-off event. If a user triggers SOS more than
     * once per minute something is wrong — either a client bug or
     * someone hammering the endpoint. We allow a small burst (3) so a
     * double-tap doesn't fail, but anything beyond that is rejected.
     */
    protected function registerSosRateLimiter(): void
    {
        RateLimiter::for('sos', function (Request $request) {
            $userId = optional($request->user())->id;

            return Limit::perMinute(3)->by('sos:user:' . ($userId ?: $request->ip()));
        });
    }

    /**
     * "driver-location" limiter used by the driver heartbeat endpoint.
     *
     * Drivers are expected to ping every ~5 seconds (12 per minute) when
     * online, but we leave a comfortable headroom: 60 per minute per user
     * — that's 1Hz, which a buggy client doing tight-loop uploads would
     * hit but a healthy client never would.
     */
    protected function registerDriverLocationRateLimiter(): void
    {
        RateLimiter::for('driver-location', function (Request $request) {
            $userId = optional($request->user())->id;

            return Limit::perMinute(60)->by('driver-location:user:' . ($userId ?: $request->ip()));
        });
    }
}
