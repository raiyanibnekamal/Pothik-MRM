# Protect main: only OWNER can push/merge to main. Collaborators use feature branches + PR.
# Requires: gh CLI logged in as repo owner (gh auth login)
# Usage:   .\scripts\setup-branch-protection.ps1

$ErrorActionPreference = "Stop"
$Owner = "raiyanibnekamal"
$Repo = "Pothik-MRM"
$Branch = "main"

gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "GitHub CLI not logged in. Run: gh auth login" -ForegroundColor Yellow
  exit 1
}

$jsonPath = Join-Path $PSScriptRoot "branch-protection-main.json"
gh api -X PUT "repos/$Owner/$Repo/branches/$Branch/protection" --input $jsonPath

if ($LASTEXITCODE -eq 0) {
  Write-Host "Branch protection enabled on $Branch." -ForegroundColor Green
  Write-Host "Only @$Owner can push/merge to main. Collaborators: feature branch + PR." -ForegroundColor Green
} else {
  Write-Host "Failed to set branch protection." -ForegroundColor Red
  exit 1
}
