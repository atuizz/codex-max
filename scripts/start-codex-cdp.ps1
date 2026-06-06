param(
    [int]$Port = 9222,
    [switch]$ForceRestart,
    [switch]$NoProbe,
    [string]$CodexExe,
    [int]$TargetWaitSeconds = 20,
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = "Stop"

function Resolve-CodexExe {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        $resolved = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop
        return $resolved.ProviderPath
    }

    $pkg = Get-AppxPackage OpenAI.Codex -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg) {
        $candidate = Join-Path $pkg.InstallLocation "app\Codex.exe"
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $localCandidates = @(
        "$env:LOCALAPPDATA\Programs\Codex\Codex.exe",
        "$env:LOCALAPPDATA\OpenAI\Codex\Codex.exe",
        "$env:ProgramFiles\Codex\Codex.exe"
    )

    foreach ($candidate in $localCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "Could not find Codex.exe. Pass -CodexExe with the full path."
}

function Get-CodexProcesses {
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -ieq "Codex.exe" -and
            $_.CommandLine -match "\\OpenAI\.Codex_|\\Codex\.exe"
        }
}

function Test-CdpEndpoint {
    param([int]$Port)

    $base = "http://127.0.0.1:$Port"
    try {
        $version = Invoke-RestMethod -Uri "$base/json/version" -TimeoutSec 2
        $targets = Invoke-RestMethod -Uri "$base/json/list" -TimeoutSec 2
        [PSCustomObject]@{
            Open = $true
            Browser = $version.Browser
            BrowserWebSocket = $version.webSocketDebuggerUrl
            TargetCount = @($targets).Count
            Targets = $targets
        }
    } catch {
        [PSCustomObject]@{
            Open = $false
            Browser = $null
            BrowserWebSocket = $null
            TargetCount = 0
            Targets = @()
            Error = $_.Exception.Message
        }
    }
}

$exe = Resolve-CodexExe -ExplicitPath $CodexExe
$existing = @(Get-CodexProcesses)

if ($existing.Count -gt 0 -and -not $ForceRestart) {
    Write-Warning "Codex is already running. The app may reuse the existing instance and ignore new Chromium arguments."
    Write-Host "Running Codex process ids: $($existing.ProcessId -join ', ')"
    Write-Host "Run again with -ForceRestart to close Codex first and relaunch with CDP enabled."
} elseif ($existing.Count -gt 0 -and $ForceRestart) {
    Write-Host "Stopping existing Codex processes: $($existing.ProcessId -join ', ')"
    foreach ($proc in $existing) {
        Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

$argsList = @(
    "--remote-debugging-port=$Port",
    "--remote-allow-origins=http://127.0.0.1:$Port"
) + $ExtraArgs

Write-Host "Starting Codex:"
Write-Host "  $exe"
Write-Host "Arguments:"
Write-Host "  $($argsList -join ' ')"

$process = Start-Process -FilePath $exe -ArgumentList $argsList -PassThru
Write-Host "Started process id: $($process.Id)"

if ($NoProbe) {
    exit 0
}

Write-Host "Probing CDP endpoint http://127.0.0.1:$Port ..."
$deadline = (Get-Date).AddSeconds($TargetWaitSeconds)
$probe = $null
do {
    Start-Sleep -Milliseconds 500
    $probe = Test-CdpEndpoint -Port $Port
    if ($probe.Open -and $probe.TargetCount -gt 0) {
        break
    }
} while ((Get-Date) -lt $deadline)

if (-not $probe.Open) {
    Write-Warning "CDP did not respond on 127.0.0.1:$Port."
    Write-Host "Last error: $($probe.Error)"
    Write-Host "Check whether Codex accepted the argument:"
    Write-Host "  Get-CimInstance Win32_Process | ? Name -eq 'Codex.exe' | Select ProcessId,CommandLine | fl"
    exit 2
}

Write-Host "CDP is open."
Write-Host "Browser: $($probe.Browser)"
Write-Host "Browser WS: $($probe.BrowserWebSocket)"
Write-Host "Targets: $($probe.TargetCount)"

if ($probe.TargetCount -eq 0) {
    Write-Warning "CDP is open, but no page targets are visible yet. This means the port opened, but Codex UI is not currently injectable through /json/list."
    Write-Host "Try again after the Codex window is fully loaded, or check:"
    Write-Host "  Invoke-RestMethod http://127.0.0.1:$Port/json/list"
    exit 3
}

foreach ($target in @($probe.Targets)) {
    Write-Host ""
    Write-Host "Target: $($target.title)"
    Write-Host "Type:   $($target.type)"
    Write-Host "URL:    $($target.url)"
    Write-Host "WS:     $($target.webSocketDebuggerUrl)"
}
