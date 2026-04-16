<#
.COPYRIGHT
  Copyright (c) 2026 maiml (maimingliang [at] gmail.com).
  Licensed under the MIT License. See LICENSE file in the project root.

.SYNOPSIS
  Triggers a Jenkins parameterised build via REST API.

.DESCRIPTION
  Reads configuration from a JSON file (default: config.json in the skill root)
  and/or command-line parameters. Supports securely reading Jenkins credentials from
  Windows Credential Manager, macOS Keychain, or environment variables.

.EXAMPLE
  # Use defaults from config.json
  .\trigger_jenkins_build.ps1

.EXAMPLE
  # Override branch and credential target
  .\trigger_jenkins_build.ps1 -Branch "main" -CredentialTarget "my-jenkins"

.EXAMPLE
  # Pass credentials directly (not recommended for automation)
  .\trigger_jenkins_build.ps1 -Username "admin" -ApiToken "abc123"
#>

param(
  [string]$ConfigFile,
  [string]$TargetEnv,
  [string]$JenkinsBaseUrl,
  [string]$JobName,
  [string]$Username,
  [string]$ApiToken,
  [string]$CredentialTarget,
  [string]$Branch,
  [string]$BranchParamName
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Load configuration from JSON file
# ---------------------------------------------------------------------------
function Load-Config([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    $Path = Join-Path $PSScriptRoot "..\config.json"
  }

  if (-not (Test-Path $Path)) {
    Write-Warning "Config file not found at '$Path'. Using command-line parameters only."
    return @{}
  }

  try {
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
  }
  catch {
    Write-Warning "Failed to parse config file: $($_.Exception.Message)"
    return @{}
  }
}

# ---------------------------------------------------------------------------
# Resolve a parameter: CLI arg > config file > fallback default
# ---------------------------------------------------------------------------
function Resolve-Param([string]$CliValue, $ConfigValue, [string]$Default) {
  if (-not [string]::IsNullOrWhiteSpace($CliValue)) { return $CliValue }
  if ($null -ne $ConfigValue -and -not [string]::IsNullOrWhiteSpace("$ConfigValue")) { return "$ConfigValue" }
  return $Default
}

# ---------------------------------------------------------------------------
# Credential Manager helpers
# ---------------------------------------------------------------------------
function Ensure-CredentialManagerModule() {
  if (Get-Module -ListAvailable -Name CredentialManager) {
    Import-Module CredentialManager -ErrorAction Stop | Out-Null
    return
  }

  Write-Host "CredentialManager module not found. Installing..."

  try {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
      Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
    }
  }
  catch {
    throw "Failed to install NuGet provider automatically: $($_.Exception.Message)"
  }

  try {
    $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($null -ne $repo -and $repo.InstallationPolicy -ne "Trusted") {
      Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
  }
  catch {
    Write-Warning "Failed to mark PSGallery as Trusted. Continuing anyway. Error: $($_.Exception.Message)"
  }

  try {
    Install-Module CredentialManager -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    Import-Module CredentialManager -ErrorAction Stop | Out-Null
  }
  catch {
    throw "Failed to install CredentialManager automatically: $($_.Exception.Message)"
  }
}

function Convert-SecureStringToPlainText([securestring]$SecureString) {
  if ($null -eq $SecureString) { return $null }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Resolve-JenkinsCredential([string]$Target, [string]$InputUsername, [string]$InputToken) {
  $resolvedUsername = $InputUsername
  $resolvedToken    = $InputToken

  if (-not [string]::IsNullOrWhiteSpace($resolvedUsername) -and -not [string]::IsNullOrWhiteSpace($resolvedToken)) {
    return @{ Username = $resolvedUsername; ApiToken = $resolvedToken }
  }

  $isWin = $true
  $isMac = $false
  if ($null -ne $IsWindows) { $isWin = [bool]$IsWindows }
  if ($null -ne $IsMacOS) { $isMac = [bool]$IsMacOS }
  # If we are definitively not Windows, and the OS looks like Mac
  if (-not $isWin -and ($env:OSTYPE -match "darwin" -or $env:TERM_PROGRAM -eq "Apple_Terminal")) { $isMac = $true }

  try {
    if ($isWin) {
      Ensure-CredentialManagerModule

      $stored = Get-StoredCredential -Target $Target
      if ($null -ne $stored) {
         if ([string]::IsNullOrWhiteSpace($resolvedUsername)) { $resolvedUsername = $stored.UserName }
         if ([string]::IsNullOrWhiteSpace($resolvedToken)) { $resolvedToken = Convert-SecureStringToPlainText -SecureString $stored.Password }
      }
    } 
    elseif ($isMac) {
      $macToken = (security find-generic-password -s $Target -w 2>$null)
      $macAccountDump = (security find-generic-password -s $Target 2>$null | Out-String)
      $macUsername = $null
      if ($macAccountDump -match '"acct"\s*<blob>="([^"]+)"') {
        $macUsername = $matches[1]
      } else {
        Write-Warning "macOS Keychain: Could not parse username for '$Target'. Falling back to JENKINS_USERNAME env var."
      }

      if (-not [string]::IsNullOrWhiteSpace($macToken)) {
        if ([string]::IsNullOrWhiteSpace($resolvedToken)) { $resolvedToken = $macToken }
        if ([string]::IsNullOrWhiteSpace($resolvedUsername) -and $null -ne $macUsername) { $resolvedUsername = $macUsername }
      }
    }

    # Fallback to Environment Variables
    if ([string]::IsNullOrWhiteSpace($resolvedUsername)) { $resolvedUsername = $env:JENKINS_USERNAME }
    if ([string]::IsNullOrWhiteSpace($resolvedToken)) { $resolvedToken = $env:JENKINS_API_TOKEN }

    if ([string]::IsNullOrWhiteSpace($resolvedUsername) -or [string]::IsNullOrWhiteSpace($resolvedToken)) {
      throw "Jenkins credential is incomplete. Set up Windows Credential Manager, macOS Keychain, or use JENKINS_USERNAME & JENKINS_API_TOKEN env vars."
    }

    return @{ Username = $resolvedUsername; ApiToken = $resolvedToken }
  } catch {
    throw "Failed to resolve credentials: $_"
  }
}

# ---------------------------------------------------------------------------
# Jenkins API helpers
# ---------------------------------------------------------------------------
function New-BasicAuthHeader([string]$User, [string]$Token) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes("${User}:$Token")
  $b64 = [Convert]::ToBase64String($bytes)
  return @{ Authorization = "Basic $b64" }
}

function Get-JenkinsCrumb([string]$BaseUrl, [hashtable]$AuthHeaders) {
  $crumbUrl = "$BaseUrl/crumbIssuer/api/json"
  try {
    $resp = Invoke-RestMethod -Method Get -Uri $crumbUrl -Headers $AuthHeaders -TimeoutSec 20
    if ($null -eq $resp -or
      [string]::IsNullOrWhiteSpace($resp.crumbRequestField) -or
      [string]::IsNullOrWhiteSpace($resp.crumb)) {
      return @{}
    }
    return @{ $resp.crumbRequestField = $resp.crumb }
  }
  catch {
    return @{}
  }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
$config = Load-Config -Path $ConfigFile

# Environment override logic
if (-not [string]::IsNullOrWhiteSpace($TargetEnv) -and $null -ne $config.environments -and $null -ne $config.environments.$TargetEnv) {
  Write-Host "Applying environment overrides for: $TargetEnv"
  $envConfig = $config.environments.$TargetEnv
  foreach ($prop in $envConfig.psobject.properties) {
    if ($null -ne $config) {
      if (Get-Member -InputObject $config -Name $prop.Name) {
        $config.($prop.Name) = $prop.Value
      }
      else {
        $config | Add-Member -Name $prop.Name -Value $prop.Value -MemberType NoteProperty
      }
    }
    else {
      # if config is empty hashtable, build custom object
      $config = New-Object PSObject
      $config | Add-Member -Name $prop.Name -Value $prop.Value -MemberType NoteProperty
    }
  }
}

$resolvedJenkinsBaseUrl = Resolve-Param $JenkinsBaseUrl  $config.jenkinsBaseUrl  ""
$resolvedJobName = Resolve-Param $JobName         $config.jobName         ""
$resolvedCredTarget = Resolve-Param $CredentialTarget $config.credentialTarget ""
$resolvedBranch = Resolve-Param $Branch          $config.branch          "dev"
$resolvedBranchParamName = Resolve-Param $BranchParamName $config.branchParamName "BRANCH"

# Validate required parameters
if ([string]::IsNullOrWhiteSpace($resolvedJenkinsBaseUrl)) {
  throw "JenkinsBaseUrl is required. Set it in config.json or pass -JenkinsBaseUrl."
}
if ([string]::IsNullOrWhiteSpace($resolvedJobName)) {
  throw "JobName is required. Set it in config.json or pass -JobName."
}
if ([string]::IsNullOrWhiteSpace($resolvedCredTarget)) {
  throw "CredentialTarget is required. Set it in config.json or pass -CredentialTarget."
}

$credential = Resolve-JenkinsCredential -Target $resolvedCredTarget -InputUsername $Username -InputToken $ApiToken
$auth = New-BasicAuthHeader -User $credential.Username -Token $credential.ApiToken
$crumb = Get-JenkinsCrumb -BaseUrl $resolvedJenkinsBaseUrl -AuthHeaders $auth

$headers = @{}
$headers += $auth
$headers += $crumb

$buildWithParamsUrl = "$resolvedJenkinsBaseUrl/job/$resolvedJobName/buildWithParameters"
$buildUrl = "$resolvedJenkinsBaseUrl/job/$resolvedJobName/build"

Write-Host "Trigger Jenkins build: $resolvedJenkinsBaseUrl / job=$resolvedJobName / $resolvedBranchParamName=$resolvedBranch / user=$($credential.Username)"

try {
  $body = @{}
  $body[$resolvedBranchParamName] = $resolvedBranch

  Invoke-WebRequest -Method Post -Uri $buildWithParamsUrl -Headers $headers -Body $body -TimeoutSec 30 | Out-Null
  Write-Host "Triggered buildWithParameters successfully."
  exit 0
}
catch {
  Write-Warning "buildWithParameters failed, falling back to build. Error: $($_.Exception.Message)"
}

Invoke-WebRequest -Method Post -Uri $buildUrl -Headers $headers -TimeoutSec 30 | Out-Null
Write-Host "Triggered build successfully."
