# Main branch protection

## What it does

- Only **raiyanibnekamal** can push or merge to `main`
- Collaborators: **feature branch + Pull Request** only
- CI must pass (4 checks) before merge
- Code owner review required (see `.github/CODEOWNERS`)

## Enable (pick one)

### A) Automatic (after latest push)

Workflow **Enable Main Branch Protection** runs when the workflow file is pushed.

If it fails with **403**, go to **GitHub → Settings → Actions → General → Workflow permissions** → select **Read and write permissions** → Save, then re-run the workflow.

### B) Manual from GitHub UI

**Actions** → **Enable Main Branch Protection** → **Run workflow**

### C) Local script (owner)

```powershell
gh auth login
.\scripts\setup-branch-protection.ps1
```

## Verify

**Settings → Branches → main** should show a protection rule.

Test as collaborator:

```bash
git push origin main
# → rejected: protected branch
```
