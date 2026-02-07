# update_hosts.ps1
param(
    [string]$MappingFile = "mapping.json",
    [string]$HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
)

# --- 1. Admin Check ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Please run this script as an Administrator!" -ForegroundColor Red
    return
}

# --- 2. Load and Validate ---
Write-Host "[1/3] Loading files..." -ForegroundColor Cyan
if (-not (Test-Path $MappingFile)) {
    Write-Host "ERROR: Mapping file not found." -ForegroundColor Red
    return
}

$mapping = Get-Content -Raw $MappingFile | ConvertFrom-Json
$hostsContent = Get-Content $HostsFile
$newEntries = @()
$addedCount = 0

# --- 3. Process Mappings ---
Write-Host "[2/3] Checking for changes..." -ForegroundColor Cyan

foreach ($prop in $mapping.PSObject.Properties.Name) {
    if ($prop -notmatch '^[a-z]+$') {
        Write-Host " -> Skipping '$prop': Invalid key (use a-z only)." -ForegroundColor Red
        continue
    }

    $hostname = $prop
    # FORCED IP: We ignore the JSON value and hardcode localhost
    $ip = "127.0.0.1"
    $newLine = "$ip`t$hostname"

    # Check for existing hostname
    $match = $hostsContent | Where-Object { $_ -match "\b$hostname\b" }

    if ($match) {
        Write-Host " -> Skipping '$hostname': Already exists as [$($match.Trim())]" -ForegroundColor Yellow
    } else {
        Write-Host " -> Queuing: $newLine" -ForegroundColor Green
        $newEntries += $newLine
        $addedCount++
    }
}

# --- 4. Write and Flush DNS ---
Write-Host "[3/3] Finalizing..." -ForegroundColor Cyan

if ($addedCount -gt 0) {
    try {
        # Construct the block to add
        $payload = "`n# Added by alias-proxy`n" + ($newEntries -join "`n")
        Add-Content -Path $HostsFile -Value $payload -ErrorAction Stop
        
        # Flush DNS cache so changes take effect immediately
        ipconfig /flushdns | Out-Null
        
        Write-Host "Successfully added $addedCount entries and flushed DNS!" -ForegroundColor White
    } catch {
        Write-Host "CRITICAL ERROR: Could not write to hosts file. Check Anti-Virus." -ForegroundColor Red
    }
} else {
    Write-Host "No changes were needed." -ForegroundColor Gray
}