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
  [string]$Project,
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

function ConvertTo-Hashtable($InputObject) {
  if ($null -eq $InputObject) {
    return $null
  }

  if ($InputObject -is [System.Collections.IDictionary]) {
    $result = @{}
    foreach ($key in $InputObject.Keys) {
      $result["$key"] = ConvertTo-Hashtable $InputObject[$key]
    }
    return $result
  }

  if ($InputObject -is [System.Management.Automation.PSCustomObject] -or $InputObject -is [psobject]) {
    $result = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
      $result[$property.Name] = ConvertTo-Hashtable $property.Value
    }
    return $result
  }

  if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
    $items = @()
    foreach ($item in $InputObject) {
      $items += , (ConvertTo-Hashtable $item)
    }
    return $items
  }

  return $InputObject
}

function Remove-JsonComments([string]$Text) {
  if ([string]::IsNullOrEmpty($Text)) {
    return $Text
  }

  $builder = New-Object System.Text.StringBuilder
  $inString = $false
  $escaped = $false
  $inLineComment = $false
  $inBlockComment = $false

  for ($index = 0; $index -lt $Text.Length; $index++) {
    $char = $Text[$index]
    $nextChar = if ($index + 1 -lt $Text.Length) { $Text[$index + 1] } else { [char]0 }

    if ($inLineComment) {
      if ($char -eq "`r" -or $char -eq "`n") {
        [void]$builder.Append($char)
        $inLineComment = $false
      }
      continue
    }

    if ($inBlockComment) {
      if ($char -eq '*' -and $nextChar -eq '/') {
        $inBlockComment = $false
        $index++
        continue
      }

      if ($char -eq "`r" -or $char -eq "`n") {
        [void]$builder.Append($char)
      }
      continue
    }

    if ($inString) {
      [void]$builder.Append($char)

      if ($escaped) {
        $escaped = $false
        continue
      }

      if ($char -eq '\') {
        $escaped = $true
        continue
      }

      if ($char -eq '"') {
        $inString = $false
      }
      continue
    }

    if ($char -eq '/' -and $nextChar -eq '/') {
      $inLineComment = $true
      $index++
      continue
    }

    if ($char -eq '/' -and $nextChar -eq '*') {
      $inBlockComment = $true
      $index++
      continue
    }

    [void]$builder.Append($char)

    if ($char -eq '"') {
      $inString = $true
      $escaped = $false
    }
  }

  return $builder.ToString()
}

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
    $clean = Remove-JsonComments $raw
    return ConvertTo-Hashtable ($clean | ConvertFrom-Json)
  }
  catch {
    Write-Warning "Failed to parse config file: $($_.Exception.Message)"
    return @{}
  }
}

function Resolve-Param([string]$CliValue, $ConfigValue, [string]$Default) {
  if (-not [string]::IsNullOrWhiteSpace($CliValue)) { return $CliValue }
  if ($null -ne $ConfigValue -and -not [string]::IsNullOrWhiteSpace("$ConfigValue")) { return "$ConfigValue" }
  return $Default
}

function Get-ConfigValue([hashtable]$Config, [string]$Key) {
  if ($null -eq $Config) {
    return $null
  }
  if ($Config.ContainsKey($Key)) {
    return $Config[$Key]
  }
  return $null
}

function Get-ConfigMap([hashtable]$Config, [string]$Key) {
  $value = Get-ConfigValue $Config $Key
  if ($value -is [hashtable]) {
    return $value
  }
  return $null
}

function Merge-Hashtable([hashtable]$Base, [hashtable]$Override) {
  $merged = @{}

  if ($null -ne $Base) {
    foreach ($key in $Base.Keys) {
      $merged[$key] = $Base[$key]
    }
  }

  if ($null -ne $Override) {
    foreach ($key in $Override.Keys) {
      $merged[$key] = $Override[$key]
    }
  }

  return $merged
}

function Get-FirstMapKey([hashtable]$Map) {
  if ($null -eq $Map) {
    return $null
  }

  foreach ($key in $Map.Keys) {
    return "$key"
  }

  return $null
}

function Get-ProjectDefaults([hashtable]$ProjectConfig) {
  $resolved = @{}

  foreach ($key in @("jenkinsBaseUrl", "jobName", "credentialTarget", "branch", "branchParamName")) {
    if ($ProjectConfig.ContainsKey($key)) {
      $resolved[$key] = $ProjectConfig[$key]
    }
  }

  $namedDefaults = Get-ConfigMap $ProjectConfig "defaults"
  if ($null -ne $namedDefaults) {
    $resolved = Merge-Hashtable $resolved $namedDefaults
  }

  return $resolved
}

function Select-ProjectName([hashtable]$Config, [string]$RequestedProject) {
  $projects = Get-ConfigMap $Config "projects"
  if ($null -eq $projects -or $projects.Count -eq 0) {
    throw "Multi-project config is missing the 'projects' block."
  }

  if (-not [string]::IsNullOrWhiteSpace($RequestedProject)) {
    if ($projects.ContainsKey($RequestedProject)) {
      return $RequestedProject
    }
    throw "Project '$RequestedProject' was not found in config.json."
  }

  $defaultProject = Resolve-Param $null (Get-ConfigValue $Config "defaultProject") ""
  if (-not [string]::IsNullOrWhiteSpace($defaultProject)) {
    if ($projects.ContainsKey($defaultProject)) {
      return $defaultProject
    }
    throw "defaultProject '$defaultProject' was not found in config.json."
  }

  if ($projects.Count -eq 1) {
    return Get-FirstMapKey $projects
  }

  throw "Project is required for multi-project config. Set defaultProject in config.json or pass -Project."
}

function Select-TargetEnvironmentName([string]$ProjectName, [hashtable]$ProjectConfig, [string]$RequestedTargetEnv) {
  $environments = Get-ConfigMap $ProjectConfig "environments"

  if (-not [string]::IsNullOrWhiteSpace($RequestedTargetEnv)) {
    if ($null -eq $environments -or -not $environments.ContainsKey($RequestedTargetEnv)) {
      throw "Target environment '$RequestedTargetEnv' was not found under project '$ProjectName'."
    }
    return $RequestedTargetEnv
  }

  $defaultEnvironment = Resolve-Param $null (Get-ConfigValue $ProjectConfig "defaultEnvironment") ""
  if (-not [string]::IsNullOrWhiteSpace($defaultEnvironment)) {
    if ($null -ne $environments -and $environments.ContainsKey($defaultEnvironment)) {
      return $defaultEnvironment
    }
    throw "defaultEnvironment '$defaultEnvironment' was not found under project '$ProjectName'."
  }

  if ($null -ne $environments) {
    if ($environments.ContainsKey("dev")) {
      return "dev"
    }
    if ($environments.Count -eq 1) {
      return Get-FirstMapKey $environments
    }
  }

  return $null
}

function Resolve-LegacyConfig([hashtable]$Config, [string]$RequestedTargetEnv) {
  $resolved = Merge-Hashtable @{} $Config
  $environments = Get-ConfigMap $Config "environments"

  if (-not [string]::IsNullOrWhiteSpace($RequestedTargetEnv)) {
    if ($null -eq $environments -or -not $environments.ContainsKey($RequestedTargetEnv)) {
      throw "Target environment '$RequestedTargetEnv' was not found in legacy config."
    }

    Write-Host "Applying environment overrides for: $RequestedTargetEnv"
    $resolved = Merge-Hashtable $resolved (Get-ConfigMap $environments $RequestedTargetEnv)
    $resolved["targetEnv"] = $RequestedTargetEnv
    return $resolved
  }

  $defaultEnvironment = Resolve-Param $null (Get-ConfigValue $Config "defaultEnvironment") ""
  if (-not [string]::IsNullOrWhiteSpace($defaultEnvironment)) {
    if ($null -eq $environments -or -not $environments.ContainsKey($defaultEnvironment)) {
      throw "defaultEnvironment '$defaultEnvironment' was not found in legacy config."
    }

    Write-Host "Applying environment overrides for: $defaultEnvironment"
    $resolved = Merge-Hashtable $resolved (Get-ConfigMap $environments $defaultEnvironment)
    $resolved["targetEnv"] = $defaultEnvironment
    return $resolved
  }

  if ($null -ne $environments) {
    if ($environments.ContainsKey("dev")) {
      Write-Host "Applying environment overrides for: dev"
      $resolved = Merge-Hashtable $resolved (Get-ConfigMap $environments "dev")
      $resolved["targetEnv"] = "dev"
      return $resolved
    }

    if ($environments.Count -eq 1) {
      $onlyEnvironment = Get-FirstMapKey $environments
      Write-Host "Applying environment overrides for: $onlyEnvironment"
      $resolved = Merge-Hashtable $resolved (Get-ConfigMap $environments $onlyEnvironment)
      $resolved["targetEnv"] = $onlyEnvironment
      return $resolved
    }
  }

  return $resolved
}

function Resolve-MultiProjectConfig([hashtable]$Config, [string]$RequestedProject, [string]$RequestedTargetEnv) {
  $projects = Get-ConfigMap $Config "projects"
  $projectName = Select-ProjectName $Config $RequestedProject
  $projectConfig = Get-ConfigMap $projects $projectName

  if ($null -eq $projectConfig) {
    throw "Project '$projectName' was not found in config.json."
  }

  Write-Host "Using project: $projectName"
  $resolved = Get-ProjectDefaults $projectConfig

  $targetEnvironment = Select-TargetEnvironmentName $projectName $projectConfig $RequestedTargetEnv
  if (-not [string]::IsNullOrWhiteSpace($targetEnvironment)) {
    $environments = Get-ConfigMap $projectConfig "environments"
    Write-Host "Applying environment overrides for: $targetEnvironment"
    $resolved = Merge-Hashtable $resolved (Get-ConfigMap $environments $targetEnvironment)
    $resolved["targetEnv"] = $targetEnvironment
  }

  $resolved["projectName"] = $projectName
  return $resolved
}

function Resolve-EffectiveConfig([hashtable]$Config, [string]$RequestedProject, [string]$RequestedTargetEnv) {
  $projects = Get-ConfigMap $Config "projects"
  if ($null -ne $projects -and $projects.Count -gt 0) {
    return Resolve-MultiProjectConfig $Config $RequestedProject $RequestedTargetEnv
  }

  if (-not [string]::IsNullOrWhiteSpace($RequestedProject)) {
    Write-Warning "Project '$RequestedProject' was ignored because config.json is using the legacy single-project format."
  }

  return Resolve-LegacyConfig $Config $RequestedTargetEnv
}

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

$config = Resolve-EffectiveConfig (Load-Config -Path $ConfigFile) $Project $TargetEnv

$resolvedJenkinsBaseUrl = Resolve-Param $JenkinsBaseUrl (Get-ConfigValue $config "jenkinsBaseUrl") ""
$resolvedJobName = Resolve-Param $JobName (Get-ConfigValue $config "jobName") ""
$resolvedCredTarget = Resolve-Param $CredentialTarget (Get-ConfigValue $config "credentialTarget") ""
$resolvedBranch = Resolve-Param $Branch (Get-ConfigValue $config "branch") "dev"
$resolvedBranchParamName = Resolve-Param $BranchParamName (Get-ConfigValue $config "branchParamName") "BRANCH"

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
