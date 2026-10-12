#!/usr/bin/env pwsh
# Install n8n-skills (and this fork's Feishu skills) into Cursor and/or Claude Code.
# Re-running updates. Same flags plus -Uninstall removes what this command would install.
#
# Download overrides (for tests / a non-main ref):
#   N8N_SKILLS_SOURCE=/path/to/checkout   skip network, use local skills/
#   N8N_SKILLS_REPO=RandallAnjie/n8n-skills
#   N8N_SKILLS_REF=main
[CmdletBinding()]
param(
    [ValidateSet('cursor', 'claude', 'both', 'Cursor', 'Claude', 'Both')]
    [string]$Tool,

    [string]$Project,

    [ValidateSet('feishu', 'Feishu')]
    [string]$Only,

    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
}

function Show-Usage {
    @"
Usage: install.ps1 -Tool cursor|claude|both [-Project [dir]] [-Only feishu] [-Uninstall]

  -Tool cursor|claude|both   Required. Destination tool skill roots.
  -Project [dir]             Project install. dir defaults to the current directory when omitted after the switch in bash; here pass -Project .
  -Only feishu               Only Feishu skills (folders named feishu-*).
  -Uninstall                 Remove the selected skills from the same destinations.

Claude Code:  ~/.claude/skills/<name>   or   <repo>/.claude/skills/<name>
Cursor:       ~/.cursor/skills/<name>   or   <repo>/.cursor/skills/<name>

Examples:
  irm https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.ps1 -OutFile install.ps1; .\install.ps1 -Tool cursor
  .\install.ps1 -Tool claude
  .\install.ps1 -Tool cursor -Project .
  .\install.ps1 -Tool cursor -Only feishu
  .\install.ps1 -Tool cursor -Uninstall
"@
}

if (-not $Tool) {
    Show-Usage
    throw "-Tool is required (cursor|claude|both)."
}

$toolNorm = $Tool.ToLowerInvariant()
$onlyNorm = if ($Only) { $Only.ToLowerInvariant() } else { '' }

$repo = if ($env:N8N_SKILLS_REPO) { $env:N8N_SKILLS_REPO } else { 'RandallAnjie/n8n-skills' }
$ref = if ($env:N8N_SKILLS_REF) { $env:N8N_SKILLS_REF } else { 'main' }
$source = $env:N8N_SKILLS_SOURCE

$userHome = [System.Environment]::GetFolderPath('UserProfile')
if (-not $userHome) { $userHome = $env:HOME }

$useProject = $PSBoundParameters.ContainsKey('Project')
if ($useProject) {
    $projectRoot = if ([string]::IsNullOrWhiteSpace($Project)) { (Get-Location).Path } else { $Project }
    if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) {
        throw "project directory does not exist: $projectRoot"
    }
    $projectRoot = (Resolve-Path -LiteralPath $projectRoot).Path
    $cursorDest = Join-Path $projectRoot '.cursor/skills'
    $claudeDest = Join-Path $projectRoot '.claude/skills'
} else {
    $cursorDest = Join-Path $userHome '.cursor/skills'
    $claudeDest = Join-Path $userHome '.claude/skills'
}

$dests = @()
switch ($toolNorm) {
    'cursor' { $dests = @($cursorDest) }
    'claude' { $dests = @($claudeDest) }
    'both' { $dests = @($cursorDest, $claudeDest) }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("n8n-skills-install-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $skillsDir = $null
    if ($source) {
        $candidate = Join-Path $source 'skills'
        if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
            throw "N8N_SKILLS_SOURCE has no skills/: $source"
        }
        $skillsDir = (Resolve-Path -LiteralPath $candidate).Path
    } else {
        $tgz = Join-Path $tmp 'src.tar.gz'
        $url = "https://github.com/$repo/archive/refs/heads/$ref.tar.gz"
        Invoke-WebRequest -Uri $url -OutFile $tgz -UseBasicParsing
        $extract = Join-Path $tmp 'extract'
        New-Item -ItemType Directory -Path $extract | Out-Null
        & tar -xzf $tgz -C $extract
        if ($LASTEXITCODE -ne 0) { throw "tar failed extracting $url" }
        $found = Get-ChildItem -Path $extract -Directory | ForEach-Object {
            Join-Path $_.FullName 'skills'
        } | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
        if (-not $found) { throw "tarball from $url has no skills/ directory" }
        $skillsDir = $found
    }

    $names = @(
        Get-ChildItem -LiteralPath $skillsDir -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
            Where-Object { if ($onlyNorm -eq 'feishu') { $_.Name -like 'feishu-*' } else { $true } } |
            Select-Object -ExpandProperty Name
    )

    if ($names.Count -eq 0) {
        throw "no matching skills found (only=$(if ($onlyNorm) { $onlyNorm } else { 'all' }))"
    }

    foreach ($dest in $dests) {
        if ($Uninstall) {
            $removed = 0
            foreach ($name in $names) {
                $target = Join-Path $dest $name
                if (Test-Path -LiteralPath $target) {
                    Remove-Item -LiteralPath $target -Recurse -Force
                    $removed++
                }
            }
            Write-Host "uninstalled $removed skill(s) from $dest"
        } else {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            foreach ($name in $names) {
                $target = Join-Path $dest $name
                if (Test-Path -LiteralPath $target) {
                    Remove-Item -LiteralPath $target -Recurse -Force
                }
                Copy-Item -LiteralPath (Join-Path $skillsDir $name) -Destination $target -Recurse -Force
            }
            Write-Host "installed $($names.Count) skill(s) to $dest"
        }
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
