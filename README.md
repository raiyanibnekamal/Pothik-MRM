# BD Ride Share — Frontend

Passenger (Flutter), Driver (Flutter), Admin (React). Local mock until NestJS is live.

## Static test user (full access)

| | |
|---|---|
| **Name** | মনিরুজ্জামান |
| **Phone** | `0152170004` |
| **OTP** | `123456` |
| **Passenger** | Profile done, location primed, guardians, trip history — lands on home |
| **Driver** | KYC approved, verified, no commission debt — can go online |
| **Admin** | Same phone as login, password `123456` (super-admin data) |
| **Ride PIN** | `4821` |

Admin also still accepts `ops@bdrideshare.com` / `Admin@1234`.

## Run

**Admin** (http://localhost:5173)

```bash
cd apps/admin-panel
pnpm install
pnpm dev
```

**Passenger / Driver**

```bash
cd apps/passenger-app && flutter run
cd apps/driver-app && flutter run
```

Phone screen is prefilled with `0152170004`. Tap **OTP পান**, enter `123456`.
