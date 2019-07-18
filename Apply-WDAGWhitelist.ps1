# Apply-WDAGWhitelist.ps1 will parse the list of trusted sites and import them
# into the Windows Defender Application Guard trusted sites lists.

$TRUST_LIST_PATH = "Whitelist.txt.prod"
$allowGlobally = @()
$allowOutsiteWDAG = @()

if (Test-Path $TRUST_LIST_PATH) {
    $sites = Get-Content $TRUST_LIST_PATH
    $sites | ForEach-Object {
        $site = $_
        if ($site -notmatch "#" -and -not([string]::IsNullOrEmpty($site))) {
            if ($site -match "@") {
                $site = $site -replace "@"
                $allowOutsiteWDAG += $site
            } else {
                $allowGlobally += $site
            }
        }
    }
} else {
    Write-Warning "Error opening file: $TRUST_LIST_PATH"
    return
}

"Global:"
$allowGlobally -join ","
"
Non-WDAG Only:"
$allowOutsiteWDAG -join "|"