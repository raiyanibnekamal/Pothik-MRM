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

$payload = @{
  required_status_checks = @{
    strict = $true
    contexts = @(
      "Laravel API",
      "Admin panel",
      "Flutter analyze",
      "Admin E2E smoke"
    )
  }
  enforce_admins = $false
  required_pull_request_reviews = @{
    dismiss_stale_reviews = $true
    require_code_owner_reviews = $true
    required_approving_review_count = 1
  }
  restrictions = @{
    users = @($Owner)
    teams = @()
    apps = @()
  }
  required_linear_history = $false
  allow_force_pushes = $false
  allow_deletions = $false
  block_creations = $false
  required_conversation_resolution = $true
} | ConvertTo-Json -Depth 6

$payload | gh api -X PUT "repos/$Owner/$Repo/branches/$Branch/protection" --input -

if ($LASTEXITCODE -eq 0) {
  Write-Host "Branch protection enabled on $Branch." -ForegroundColor Green
  Write-Host "Only @$Owner can push/merge to main. Collaborators: feature branch + PR." -ForegroundColor Green
} else {
  Write-Host "Failed to set branch protection." -ForegroundColor Red
  exit 1
}
