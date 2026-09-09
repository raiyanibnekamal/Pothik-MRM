# Main branch protection — enable now (2 min)

## What you get

- Collaborators **cannot** push or merge to `main`
- They use: `feature/xyz` branch → Pull Request → you approve → you merge
- CI must pass (4 checks)

---

## Option A — GitHub UI (fastest, no token)

1. Open: https://github.com/raiyanibnekamal/Pothik-MRM/settings/branches
2. **Add branch ruleset** or **Add classic rule** → branch name: `main`
3. Enable:
   - **Require a pull request before merging**
   - **Require approvals** → 1
   - **Require review from Code Owners**
   - **Require status checks** → select: `Laravel API`, `Admin panel`, `Flutter analyze`, `Admin E2E smoke`
   - **Require conversation resolution**
   - **Restrict who can push** → add only: `raiyanibnekamal`
   - **Do not allow bypassing** (optional)
   - Block force pushes / deletions
4. **Save**

---

## Option B — GitHub Actions (one-time)

1. Create PAT: https://github.com/settings/tokens/new  
   Scope: **repo** (full) or fine-grained **Administration: Read and write** on this repo
2. Repo → **Settings → Secrets and variables → Actions → New secret**  
   Name: `GH_ADMIN_TOKEN`  
   Value: your PAT
3. **Actions → Enable Main Branch Protection → Run workflow**

---

## Option C — Local script (owner)

```powershell
gh auth login
.\scripts\setup-branch-protection.ps1
```

Device login: https://github.com/login/device

---

## Verify

Collaborator test:

```bash
git push origin main
# → remote: GH006 Protected branch update failed
```
