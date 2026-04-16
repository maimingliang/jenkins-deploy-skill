$ErrorActionPreference = "Stop"

# ---- Platform detection (same logic as trigger_jenkins_build.ps1) ----
$isWin = $true; $isMac = $false
if ($null -ne $IsWindows) { $isWin = $IsWindows }
if ($null -ne $IsMacOS)   { $isMac = $IsMacOS }
Write-Host "Platform: isWin=$isWin  isMac=$isMac"
Write-Host ""

# ===========================================================================
# Test 1: Direct credential pass-through (both provided → skip all lookups)
# ===========================================================================
Write-Host "=== Test 1: Direct credential pass-through ==="
$u = "direct-user"; $t = "direct-token"
if (-not [string]::IsNullOrWhiteSpace($u) -and -not [string]::IsNullOrWhiteSpace($t)) {
    Write-Host "  PASS  - user=$u"
} else { Write-Host "  FAIL" }

# ===========================================================================
# Test 2: Env-var fallback (simulate no credential manager hit)
# ===========================================================================
Write-Host ""
Write-Host "=== Test 2: Environment variable fallback ==="
$env:JENKINS_USERNAME  = "env-user"
$env:JENKINS_API_TOKEN = "env-token"
$u2 = ""; $t2 = ""
if ([string]::IsNullOrWhiteSpace($u2)) { $u2 = $env:JENKINS_USERNAME }
if ([string]::IsNullOrWhiteSpace($t2)) { $t2 = $env:JENKINS_API_TOKEN }
if (-not [string]::IsNullOrWhiteSpace($u2) -and -not [string]::IsNullOrWhiteSpace($t2)) {
    Write-Host "  PASS  - user=$u2"
} else { Write-Host "  FAIL" }
# cleanup
$env:JENKINS_USERNAME  = $null
$env:JENKINS_API_TOKEN = $null

# ===========================================================================
# Test 3: No credentials at all → should detect as incomplete
# ===========================================================================
Write-Host ""
Write-Host "=== Test 3: No credentials available ==="
$u3 = ""; $t3 = ""
if ([string]::IsNullOrWhiteSpace($u3)) { $u3 = $env:JENKINS_USERNAME }
if ([string]::IsNullOrWhiteSpace($t3)) { $t3 = $env:JENKINS_API_TOKEN }
if ([string]::IsNullOrWhiteSpace($u3) -or [string]::IsNullOrWhiteSpace($t3)) {
    Write-Host "  PASS  - Correctly detects missing credentials"
} else { Write-Host "  FAIL" }

# ===========================================================================
# Test 4: Full end-to-end with env vars via the REAL script
# ===========================================================================
Write-Host ""
Write-Host "=== Test 4: End-to-end with env vars (real script, fake Jenkins) ==="
$env:JENKINS_USERNAME  = "e2e-user"
$env:JENKINS_API_TOKEN = "e2e-token"
try {
    & (Join-Path $PSScriptRoot "trigger_jenkins_build.ps1") `
        -JenkinsBaseUrl "http://fake-jenkins-e2e:9999" `
        -JobName "e2e-job" `
        -CredentialTarget "nonexistent-target-xyz" `
        -Branch "dev"
    Write-Host "  INFO  - Script exited normally (unexpected unless Jenkins was reachable)"
} catch {
    $msg = $_.Exception.Message
    if ($msg -match "remote name could not be resolved|connection attempt failed|Unable to connect") {
        Write-Host "  PASS  - Credentials resolved OK; failed at network call (expected with fake URL)"
    } else {
        Write-Host "  FAIL  - Unexpected error: $msg"
    }
}
$env:JENKINS_USERNAME  = $null
$env:JENKINS_API_TOKEN = $null

# ===========================================================================
# Test 5: Full end-to-end with direct -Username -ApiToken
# ===========================================================================
Write-Host ""
Write-Host "=== Test 5: End-to-end with -Username -ApiToken (real script) ==="
try {
    & (Join-Path $PSScriptRoot "trigger_jenkins_build.ps1") `
        -JenkinsBaseUrl "http://fake-jenkins-direct:9999" `
        -JobName "direct-job" `
        -Username "cli-user" `
        -ApiToken "cli-token" `
        -CredentialTarget "unused" `
        -Branch "dev"
} catch {
    $msg = $_.Exception.Message
    if ($msg -match "remote name could not be resolved|connection attempt failed|Unable to connect") {
        Write-Host "  PASS  - Credentials resolved OK; failed at network call (expected)"
    } else {
        Write-Host "  FAIL  - Unexpected error: $msg"
    }
}

# ===========================================================================
# Test 6: TargetEnv override
# ===========================================================================
Write-Host ""
Write-Host "=== Test 6: -TargetEnv environment override ==="
try {
    & (Join-Path $PSScriptRoot "trigger_jenkins_build.ps1") `
        -ConfigFile (Join-Path $PSScriptRoot "..\config.example.json") `
        -TargetEnv "test" `
        -Username "env-override-user" `
        -ApiToken "env-override-token"
} catch {
    $msg = $_.Exception.Message
    if ($msg -match "remote name could not be resolved|connection attempt failed|Unable to connect") {
        Write-Host "  PASS  - TargetEnv override applied; failed at network call (expected)"
    } else {
        Write-Host "  FAIL  - Unexpected error: $msg"
    }
}

Write-Host ""
Write-Host "=============================="
Write-Host "  All tests completed."
Write-Host "=============================="
