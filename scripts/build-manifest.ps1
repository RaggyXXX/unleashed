# Builds dist/manifest.json + dist daemons from source.
#  - CLI version follows the $VERSION constant in UnleashedBypass.cmd; cli is served from the
#    rolling GitHub Release (url -> releases/latest/download/UnleashedBypass.cmd).
#  - Daemons are served from the repo via raw (dist/). Their version auto-bumps ONLY when the
#    file content (SHA256) changed vs the previous manifest -> clients pull just what changed.
param([string]$Root = (Join-Path $PSScriptRoot '..'), [string]$Repo = $env:GITHUB_REPOSITORY)
$ErrorActionPreference = 'Stop'
if (-not $Repo) { $Repo = 'RaggyXXX/unleashed' }
$Root = (Resolve-Path $Root).Path
$cmd = Join-Path $Root 'UnleashedBypass.cmd'
if (-not (Test-Path $cmd)) { throw "installer not found: $cmd" }
$txt = [IO.File]::ReadAllText($cmd)
$cliVer = ([regex]::Match($txt, "\`$VERSION\s*=\s*'([^']+)'")).Groups[1].Value
if (-not $cliVer) { throw 'could not read $VERSION from the installer' }

$rawBase = "https://raw.githubusercontent.com/$Repo/main/dist"
$relBase = "https://github.com/$Repo/releases/latest/download"
$dist = Join-Path $Root 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item (Join-Path $Root 'src/poro-noads-daemon.ps1')  (Join-Path $dist 'poro-noads-daemon.ps1')  -Force
Copy-Item (Join-Path $Root 'src/blitz-noads-daemon.ps1') (Join-Path $dist 'blitz-noads-daemon.ps1') -Force
Copy-Item (Join-Path $Root 'src/opgg-noads-daemon.ps1')  (Join-Path $dist 'opgg-noads-daemon.ps1')  -Force

function HashOf($p) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower() }
$prev = $null; $pp = Join-Path $dist 'manifest.json'
if (Test-Path $pp) { try { $prev = [IO.File]::ReadAllText($pp) | ConvertFrom-Json } catch {} }
function PrevVer($k) { if ($prev -and $prev.$k) { [string]$prev.$k.version } else { $null } }
function PrevSha($k) { if ($prev -and $prev.$k) { ([string]$prev.$k.sha256).ToLower() } else { $null } }
function BumpPatch($v) { $p = @("$v" -split '\.'); while ($p.Count -lt 3) { $p += '0' }; $p[$p.Count-1] = [string]([int]$p[$p.Count-1] + 1); ($p -join '.') }
function DaemonVer($k, $sha) { $ps = PrevSha $k; $pv = PrevVer $k; if ($ps -and $ps -eq $sha) { return $pv }; if ($pv) { return (BumpPatch $pv) }; return '1.0.0' }

$cliSha   = HashOf $cmd
$poroSha  = HashOf (Join-Path $dist 'poro-noads-daemon.ps1')
$blitzSha = HashOf (Join-Path $dist 'blitz-noads-daemon.ps1')
$opggSha  = HashOf (Join-Path $dist 'opgg-noads-daemon.ps1')
$manifest = [ordered]@{
  cli   = [ordered]@{ version=$cliVer;                       file='UnleashedBypass.cmd';    url="$relBase/UnleashedBypass.cmd";    sha256=$cliSha }
  poro  = [ordered]@{ version=(DaemonVer 'poro' $poroSha);   file='poro-noads-daemon.ps1';  url="$rawBase/poro-noads-daemon.ps1";  sha256=$poroSha }
  blitz = [ordered]@{ version=(DaemonVer 'blitz' $blitzSha); file='blitz-noads-daemon.ps1'; url="$rawBase/blitz-noads-daemon.ps1"; sha256=$blitzSha }
  opgg  = [ordered]@{ version=(DaemonVer 'opgg' $opggSha);   file='opgg-noads-daemon.ps1';  url="$rawBase/opgg-noads-daemon.ps1";  sha256=$opggSha }
}
[IO.File]::WriteAllText($pp, ($manifest | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
Write-Host ("manifest: cli v$cliVer  poro v$($manifest.poro.version)  blitz v$($manifest.blitz.version)  opgg v$($manifest.opgg.version)")
