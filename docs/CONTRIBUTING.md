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
