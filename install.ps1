<#
.SYNOPSIS
  Universal installer for jenkins-deploy-skill.
  Clones the repository and helps link it to AI assistants.
#>

$repoUrl = "https://github.com/maimingliang/jenkins-deploy-skill.git"
$installDir = "$HOME/.jenkins-deploy-skill"

Write-Host "--- jenkins-deploy-skill Installer ---" -ForegroundColor Cyan

# 1. Clone or Update repo
if (Test-Path $installDir) {
    Write-Host "Updating existing installation at $installDir..."
    Set-Location $installDir
    git pull origin main
} else {
    Write-Host "Cloning repository to $installDir..."
    git clone $repoUrl $installDir
}

# 2. Setup local config if missing
$configPath = Join-Path $installDir "config.json"
$examplePath = Join-Path $installDir "config.example.json"
if (-not (Test-Path $configPath)) {
    Write-Host "Initializing config.json from template..."
    Copy-Item $examplePath $configPath
}

# 3. Handle Project Linkage
$targetProject = Get-Location
Write-Host "`nDo you want to link this skill to the current project ($targetProject)?" -ForegroundColor Yellow
$choice = Read-Host "[Y] Cursor/Windsurf (.cursorrules) | [C] Claude (.clauderc) | [N] Skip"

$skillContent = Get-Content (Join-Path $installDir "SKILL.md") -Raw
# Strip YAML header if present
$skillContent = $skillContent -replace '(?s)---.*?---', ''

switch ($choice.ToLower()) {
    "y" {
        $rulePath = Join-Path $targetProject ".cursorrules"
        Add-Content -Path $rulePath -Value "`n$skillContent"
        Write-Host "Success: Added instructions to .cursorrules" -ForegroundColor Green
    }
    "c" {
        $rulePath = Join-Path $targetProject ".clauderc"
        Add-Content -Path $rulePath -Value "`n$skillContent"
        Write-Host "Success: Added instructions to .clauderc" -ForegroundColor Green
    }
    Default { Write-Host "Skipping project linkage." }
}

Write-Host "`nInstallation Complete!" -ForegroundColor Cyan
Write-Host "Next steps:"
Write-Host "1. Edit $configPath with your Jenkins details."
Write-Host "2. Set up your credentials (see README.md)."
