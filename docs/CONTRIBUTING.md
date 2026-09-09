# Contributing — BD Ride Share

## Branch rules (main is protected)

| Who | Clone | Feature branch | Push to `main` | Merge to `main` |
|-----|-------|----------------|----------------|-----------------|
| **Owner** (`raiyanibnekamal`) | ✅ | ✅ | ✅ | ✅ |
| **Collaborators** | ✅ | ✅ | ❌ | ❌ (owner merges PR) |

## Workflow for collaborators

```bash
git clone https://github.com/raiyanibnekamal/Pothik-MRM.git
cd Pothik-MRM
git checkout -b feature/your-task

# work, commit
git push -u origin feature/your-task
```

Open a **Pull Request** → `main`. Wait for CI (4 checks) → owner review → owner merges.

Direct push to `main` will fail:

```
remote: error: GH006: Protected branch update failed
```

## CI must pass before merge

- Laravel API
- Admin panel
- Flutter analyze
- Admin E2E smoke

## Setup protection (owner once)

```powershell
gh auth login
.\scripts\setup-branch-protection.ps1
```

Until this runs, collaborators with **Write** access can still push to `main` directly.

## Local setup

Windows: `.\scripts\setup.ps1`  
Linux/macOS: `./scripts/setup.sh`

## Real API (admin)

Copy `apps/admin-panel/.env.example` → `.env`:

```
VITE_API_URL=http://localhost:8000/api/v1
VITE_USE_MOCK=false
```
