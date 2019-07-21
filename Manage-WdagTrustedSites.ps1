# Manage-WdagTrustedSites.ps1 makes it easier to manage the lists of trusted
# sites for Windows Defender Application Guard via local group policy.
# Specifically, you can add or remove sites from the "Domains categorized as
# both work and personal" (NeutralResources) and "Enterprise resource domains
# hosted in the cloud" (CloudResources) lists.
#
# Copyright (C) 2019 jdgregson <jonathan@jdgregson.com>
# License: GPLv3

[cmdletbinding()]
Param (
    [Parameter(ParameterSetName='Global')]
    [string]$TrustedSitesList = 'Whitelist.txt',

    [string]$AddTrustedSite,

    [switch]$PromptTrustedSites,

    [switch]$UpdateTrustedSites
)

Import-Module PolicyFileEditor
$TargetRegKey = "SOFTWARE\Policies\Microsoft\Windows\NetworkIsolation"
$GpRegFile = "$env:windir\System32\GroupPolicy\Machine\registry.pol"

function Get-WdagSiteGroups {
    [cmdletbinding()]
    Param (
        [Parameter(
            ParameterSetName='WdagSiteGroups',
            Mandatory=$true,
            ValueFromPipeline=$true
        )]
        [string]$TrustedSitesList
    )

    begin {
        $NeutralResources = @()
        $CloudResources = @()
        if (-not([string]::IsNullOrEmpty($TrustedSitesList)) -and (Test-Path $TrustedSitesList)) {
            $TrustedSitesList = Get-Content $TrustedSitesList
        }
    }
    process {
        $sites = Get-Content $TrustedSitesList
        $sites | ForEach-Object {
            $site = $_
            if ($site -notmatch "#" -and -not([string]::IsNullOrEmpty($site))) {
                if ($site -match "@") {
                    $site = $site -replace "@"
                    $CloudResources += $site
                } else {
                    $NeutralResources += $site
                }
            }
        }
    }
    end {
        return @($CloudResources, $NeutralResources)
    }
}


function Set-NeutralResourcesList {
    [cmdletbinding()]
    Param (
        [Parameter(
            ParameterSetName='NeutralResourcesList',
            Mandatory=$true,
            ValueFromPipeline=$true
        )]
        [string]$NeutralResources
    )

    for ($i = 0; $i -lt $NeutralResources.length; $i++) {
        $char = $NeutralResources[$i]
        if ($char -notmatch '[A-z0-9\.\-_,]') {
            Write-Warning "Invalid character in NeutralResources list: `"$char`""
            Write-Warning "Not appliying NeutralResources."
            $NeutralResources = $null
        }
    }
    if ($NeutralResources) {
        Set-PolicyFileEntry -Path $GpRegFile -Key $TargetRegKey -ValueName 'NeutralResources' -Data $NeutralResources -Type 'String'
    }
}


function Set-CloudResourcesList {
    [cmdletbinding()]
    Param (
        [Parameter(
            ParameterSetName='CloudResourcesList',
            Mandatory=$true,
            ValueFromPipeline=$true
        )]
        [string]$CloudResources
    )

    for ($i = 0; $i -lt $CloudResources.length; $i++) {
        $char = $CloudResources[$i]
        if ($char -notmatch '[A-z0-9\.\-_|]') {
            Write-Warning "Invalid character in CloudResources list: `"$char`""
            Write-Warning "Not appliying CloudResources."
            $CloudResources = $null
        }
    }
    if ($CloudResources) {
        Set-PolicyFileEntry -Path $GpRegFile -Key $TargetRegKey -ValueName 'CloudResources' -Data $CloudResources -Type 'String'
    }
}


function Add-WdagTrustedSites {
    [cmdletbinding()]
    Param (
        [Parameter(
            ParameterSetName='WdagTrustedSite',
            Mandatory=$true,
            ValueFromPipeline=$true
        )]
        [string[]]$NewSites,

        [string]$TrustedSitesList = $global:TrustedSitesList
    )

    begin {
        if ([string]::IsNullOrEmpty($TrustedSitesList) -or -not(Test-Path $TrustedSitesList)) {
            Write-Host "Cannot find trusted sites file: $TrustedSitesList"
            return
        }
    }
    process {
        $NewSites | Add-Content $TrustedSitesList -Encoding "UTF8"
    }
    end {
        Update-WdagSiteTrust $TrustedSitesList
    }
}


function Prompt-TrustedSites {
    Write-Host "Enter a comma-separated list of sites to add to the trusted " `
        "sites list. Prefix a site with `".`" to include subdomains. Prefix a " `
        "site with `"@`" to prevent access from inside of Windows Defender " `
        "Application Guard. E.g.: .facebook.com, @.mycompany.com"
    $NewSites = Read-Host "New trusted sites"
    $NewSites = $NewSites -replace " " -split "," | Add-WdagTrustedSites -TrustedSitesList $TrustedSitesList
}


function Update-WdagSiteTrust {
    $CloudResources,$NeutralResources = $TrustedSitesList | Get-WdagSiteGroups

    $NeutralResources = $NeutralResources -join ","
    Write-Host "Applying NeutralResources:" -ForegroundColor "green"
    Write-Host $NeutralResources
    $NeutralResources | Set-NeutralResourcesList

    $CloudResources = $CloudResources -join "|"
    Write-Host "Applying CloudResources:" -ForegroundColor "green"
    Write-Host $CloudResources
    $CloudResources | Set-CloudResourcesList

    Write-Host "Updating Group Policy" -ForegroundColor "green"
    gpupdate /Force
}


if ($AddTrustedSite) {
    Add-WdagTrustedSites -TrustedSitesList $TrustedSitesList -NewSites $AddTrustedSite
} elseif ($PromptTrustedSites) {
    Prompt-TrustedSites
} elseif ($UpdateTrustedSites) {
    Update-WdagSiteTrust
}
