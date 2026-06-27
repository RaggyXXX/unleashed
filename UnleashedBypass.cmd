@echo off
title Unleashed Bypass Installer
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8);$i=$s.IndexOf('#PS'+'BODY#');$j=$s.IndexOf([char]10,$i);iex $s.Substring($j+1)"
exit /b
#PSBODY#
# ============================================================
#  UNLEASHED BYPASS - unified installer CLI (pure PowerShell, no Node)
#  Auto-detects Porofessor & Blitz, shows live status, installs
#  everywhere possible. Optional custom app / install paths.
# ============================================================
$ErrorActionPreference = 'Stop'
try { [Console]::Title = 'Unleashed Bypass Installer' } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'Gray' } catch {}


function IsAdmin { ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) }
function Pause2 { Write-Host ''; [void](Read-Host '   Press Enter to continue') }

$Apps = @{
  poro = @{ key='poro'; name='Porofessor'; appRel='Programs\Porofessor Standalone\Porofessor Standalone.exe'; procName='Porofessor Standalone';
            task='PorofessorNoAds'; daemonFile='poro-noads-daemon.ps1'; flagsFile='poro-flags.ps1'; launcherFile='poro-launcher.vbs';
            port='9333'; autoArg='--hidden-launch'; runKeyName='PorofessorApp';
            defDir="$env:LOCALAPPDATA\UnleashedBypass\Porofessor"; legacyDir='C:\BlitzBypass\Porofessor';
            shortcuts=@("$env:USERPROFILE\Desktop\Porofessor Standalone.lnk","$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Porofessor Standalone.lnk") }
  blitz = @{ key='blitz'; name='Blitz'; appRel='Programs\Blitz\Blitz.exe'; procName='Blitz';
             task='BlitzNoAds'; daemonFile='blitz-noads-daemon.ps1'; flagsFile='blitz-flags.ps1'; launcherFile='blitz-launcher.vbs';
             port='9222'; autoArg='--autostart'; runKeyName='com.blitz.app';
             defDir="$env:LOCALAPPDATA\UnleashedBypass\Blitz"; legacyDir='C:\BlitzBypass';
             shortcuts=@("$env:USERPROFILE\Desktop\Blitz.lnk","$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Blitz.lnk") }
}
$Order = @('poro','blitz')

# --- auto-detection ---------------------------------------------------------
function Find-AppExe($a) {
  $def = "$env:LOCALAPPDATA\$($a.appRel)"
  if (Test-Path $def) { return $def }
  $exeName = Split-Path $a.appRel -Leaf
  $roots = @("$env:LOCALAPPDATA\Programs", $env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:ProgramData")
  foreach ($r in $roots) {
    if ($r -and (Test-Path $r)) {
      try { $hit = Get-ChildItem -Path $r -Filter $exeName -Recurse -Depth 3 -ErrorAction SilentlyContinue -File | Select-Object -First 1 } catch { $hit = $null }
      if ($hit) { return $hit.FullName }
    }
  }
  return $null
}

function Get-RunKeyValue($a) {
  try { return (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $a.runKeyName -ErrorAction SilentlyContinue).$($a.runKeyName) } catch { return $null }
}
function Get-LaunchPointPath($a) {
  $rk = Get-RunKeyValue $a
  if (-not $rk) { return $null }
  $m = [regex]::Match($rk, '([A-Za-z]:\\[^"]*\.vbs)')
  if ($m.Success) { return $m.Groups[1].Value }
  return $null
}

function Get-AppStatus($a) {
  $exe = Find-AppExe $a
  $lpPath = Get-LaunchPointPath $a                       # absolute launcher path stored in the Run key
  $redirected = [bool]$lpPath
  $lpExists = ($lpPath -and (Test-Path $lpPath))
  $instDir = if ($lpPath) { Split-Path $lpPath -Parent } else { $a.defDir }
  $daemonOnDisk = Test-Path (Join-Path $instDir $a.daemonFile)
  $flagsOnDisk  = Test-Path (Join-Path $instDir $a.flagsFile)
  $filesOk = $lpExists -and $daemonOnDisk -and $flagsOnDisk
  $taskExists = $false; try { $null = Get-ScheduledTask -TaskName $a.task -ErrorAction Stop; $taskExists = $true } catch {}
  $active = $false; try { $active = [bool](Get-NetTCPConnection -LocalPort ([int]$a.port) -State Listen -ErrorAction SilentlyContinue) } catch {}
  $running = $false; try { $running = [bool](Get-Process -Name $a.procName -ErrorAction SilentlyContinue) } catch {}
  $installed = ($redirected -or $taskExists -or (Test-Path (Join-Path $a.defDir $a.daemonFile)))
  $broken = $installed -and -not $active -and $redirected -and ((-not $lpExists) -or (-not $daemonOnDisk))
  $mislocated = $installed -and -not $broken -and $lpPath -and (($instDir.TrimEnd('\')) -ne ($a.defDir.TrimEnd('\')))
  return [pscustomobject]@{ name=$a.name; exe=$exe; installed=$installed; active=$active; task=$taskExists;
    running=$running; instDir=$instDir; lpPath=$lpPath; lpExists=$lpExists; filesOk=$filesOk; broken=$broken; mislocated=$mislocated }
}

# --- install / uninstall ----------------------------------------------------
function Write-FlagsFile($a, $dir) {
  $rk = $a.runKeyName; $autoArg = $a.autoArg
  $shJoined = ($a.shortcuts | ForEach-Object { "'" + $_.Replace("'","''") + "'" }) -join ','
  $appRel = $a.appRel
  $appImg = Split-Path $a.appRel -Leaf
  $launcherFile = $a.launcherFile
  $content = @"
`$ErrorActionPreference='SilentlyContinue'
`$launcher = Join-Path `$PSScriptRoot '$launcherFile'
`$wscript  = "`$env:SystemRoot\System32\wscript.exe"
`$runKey   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
`$appExe = Join-Path `$env:LOCALAPPDATA '$appRel'
if (-not (Test-Path `$appExe)) {
  `$appExe = `$null
  foreach (`$r in @("`$env:LOCALAPPDATA\Programs", `$env:ProgramFiles, `${env:ProgramFiles(x86)}, `$env:ProgramData)) {
    if (`$r -and (Test-Path `$r)) {
      `$h = Get-ChildItem `$r -Filter '$appImg' -Recurse -Depth 3 -File -ErrorAction SilentlyContinue | Select-Object -First 1
      if (`$h) { `$appExe = `$h.FullName; break }
    }
  }
}
`$cur = (Get-ItemProperty -Path `$runKey -Name '$rk' -ErrorAction SilentlyContinue)."$rk"
if (`$cur -notlike "*`$launcher*") { Set-ItemProperty -Path `$runKey -Name '$rk' -Value "`$wscript ``"`$launcher``" $autoArg" }
foreach (`$s in @($shJoined)) {
  if (Test-Path `$s) {
    `$sh = New-Object -ComObject WScript.Shell; `$l = `$sh.CreateShortcut(`$s)
    if (`$l.TargetPath -ne `$wscript -or `$l.Arguments -notlike "*`$launcher*") {
      `$l.TargetPath = `$wscript; `$l.Arguments = "``"`$launcher``""
      if (`$appExe) { `$l.IconLocation = "`$appExe,0" }
      `$l.Save()
    }
  }
}
"@
  [IO.File]::WriteAllText((Join-Path $dir $a.flagsFile), $content, (New-Object Text.UTF8Encoding($false)))
}

function Write-LauncherVbs($a, $dir) {
  $launcher   = Join-Path $dir $a.launcherFile
  $daemonLeaf = $a.daemonFile
  $appImg     = Split-Path $a.appRel -Leaf
  $appRel     = $a.appRel
  $vbs = @(
    'Set sh = CreateObject("WScript.Shell")',
    'Set fso = CreateObject("Scripting.FileSystemObject")',
    'q = Chr(34)',
    'here = fso.GetParentFolderName(WScript.ScriptFullName)',
    ('daemon = fso.BuildPath(here, "' + $daemonLeaf + '")'),
    ('appImg = "' + $appImg + '"'),
    ('appRel = "' + $appRel + '"'),
    'app = ResolveApp(appRel, appImg)',
    'If fso.FileExists(daemon) Then sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & q & daemon & q, 0, False',
    'extra = ""',
    'For Each a In WScript.Arguments',
    '  extra = extra & " " & a',
    'Next',
    ('If Len(app) > 0 Then sh.Run q & app & q & " --remote-debugging-port=' + $a.port + '" & extra, 1, False'),
    '',
    'Function ResolveApp(relPath, leaf)',
    '  Dim def, roots, r, hit',
    '  def = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\" & relPath',
    '  If fso.FileExists(def) Then ResolveApp = def : Exit Function',
    '  roots = Array(sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Programs", _',
    '                sh.ExpandEnvironmentStrings("%ProgramFiles%"), _',
    '                sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%"), _',
    '                sh.ExpandEnvironmentStrings("%ProgramData%"))',
    '  For Each r In roots',
    '    hit = FindLeaf(r, leaf, 3)',
    '    If Len(hit) > 0 Then ResolveApp = hit : Exit Function',
    '  Next',
    '  ResolveApp = def',
    'End Function',
    '',
    'Function FindLeaf(folderPath, leaf, depth)',
    '  Dim f, sf, res',
    '  FindLeaf = ""',
    '  On Error Resume Next',
    '  If Not fso.FolderExists(folderPath) Then Exit Function',
    '  If fso.FileExists(folderPath & "\" & leaf) Then FindLeaf = folderPath & "\" & leaf : Exit Function',
    '  If depth <= 0 Then Exit Function',
    '  Set f = fso.GetFolder(folderPath)',
    '  For Each sf In f.SubFolders',
    '    res = FindLeaf(sf.Path, leaf, depth - 1)',
    '    If Len(res) > 0 Then FindLeaf = res : Exit Function',
    '  Next',
    'End Function'
  ) -join "`r`n"
  [IO.File]::WriteAllText($launcher, $vbs, [Text.Encoding]::ASCII)
}

function Clear-LegacyDir($a, $dir) {
  if (-not $a.legacyDir) { return }
  if (-not (Test-Path $a.legacyDir)) { return }
  if (($a.legacyDir.TrimEnd('\')) -ieq ($dir.TrimEnd('\'))) { return }
  foreach ($f in @($a.daemonFile, $a.flagsFile, $a.launcherFile, 'PorofessorBypassUninstaller.cmd', 'BlitzBypassUninstaller.cmd')) {
    $lf = Join-Path $a.legacyDir $f
    if (Test-Path $lf) { Remove-Item $lf -Force -ErrorAction SilentlyContinue }
  }
  try { if (-not (Get-ChildItem $a.legacyDir -Force -ErrorAction SilentlyContinue)) { Remove-Item $a.legacyDir -Force -ErrorAction SilentlyContinue } } catch {}
}

function Install-App($a, $appExe, $dir) {
  if ([string]::IsNullOrWhiteSpace($appExe)) { $appExe = Find-AppExe $a; if (-not $appExe) { $appExe = "$env:LOCALAPPDATA\$($a.appRel)" } }
  if ([string]::IsNullOrWhiteSpace($dir))    { $dir = $a.defDir }
  Write-Host ''
  Write-Host "   Installing $($a.name)" -ForegroundColor Cyan
  Write-Host "     app : $appExe" -ForegroundColor DarkGray
  Write-Host "     dir : $dir" -ForegroundColor DarkGray
  if (-not (Test-Path $appExe)) { Write-Host "     ERROR: app EXE not found. (use option 7 for a custom path)" -ForegroundColor Red; return }
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  try { (Get-Item (Split-Path $dir)).Attributes = 'Hidden' } catch {}
  $daemonFile = Join-Path $dir $a.daemonFile
  $di = Install-DaemonFile $a $dir
  if (-not $di.web) {
    Write-Host ("     ERROR: cannot fetch daemon from the web (" + $di.err + ").") -ForegroundColor Red
    Write-Host  '            needs internet + a valid update source. Nothing was changed.' -ForegroundColor DarkGray
    return
  }
  Write-Host ("     daemon : pulled from web  (v" + $di.ver + ")") -ForegroundColor Green
  Write-FlagsFile $a $dir
  Write-LauncherVbs $a $dir
  $launcher = Join-Path $dir $a.launcherFile
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir $a.flagsFile)
  if (IsAdmin) {
    try {
      $act = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument ('"' + $launcher + '" ' + $a.autoArg)
      $trg = New-ScheduledTaskTrigger -AtLogOn
      $prn = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
      $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)
      Register-ScheduledTask -TaskName $a.task -Action $act -Trigger $trg -Principal $prn -Settings $set -Force | Out-Null
      Write-Host "     admin-locked task '$($a.task)' created (at logon, highest privileges)." -ForegroundColor Green
    } catch { Write-Host "     task creation failed: $($_.Exception.Message)" -ForegroundColor Yellow }
  } else {
    Write-Host "     note: no elevated task without admin. Ad-block + auto-heal still run." -ForegroundColor DarkGray
  }
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like "*$($a.daemonFile)*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Get-Process -Name $a.procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep 2
  Start-Process 'wscript.exe' -ArgumentList ('"' + $launcher + '" ' + $a.autoArg)
  Start-Sleep 6
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir $a.flagsFile)
  Clear-LegacyDir $a $dir
  Write-Host "     DONE - $($a.name) now runs ad-free and persistent." -ForegroundColor Green
}

function Repair-App($a) {
  $exe = Find-AppExe $a
  if (-not $exe) { $exe = "$env:LOCALAPPDATA\$($a.appRel)" }
  Install-App $a $exe $a.defDir
}

function Uninstall-App($a, $appExe) {
  if ([string]::IsNullOrWhiteSpace($appExe)) { $appExe = Find-AppExe $a; if (-not $appExe) { $appExe = "$env:LOCALAPPDATA\$($a.appRel)" } }
  Write-Host ''
  Write-Host "   Uninstalling $($a.name)" -ForegroundColor Cyan
  if (IsAdmin) { Unregister-ScheduledTask -TaskName $a.task -Confirm:$false -ErrorAction SilentlyContinue }
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like "*$($a.daemonFile)*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Start-Sleep 1
  $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  Set-ItemProperty -Path $runKey -Name $a.runKeyName -Value ('"' + $appExe + '" ' + $a.autoArg) -ErrorAction SilentlyContinue
  $sh = New-Object -ComObject WScript.Shell
  foreach ($s in $a.shortcuts) { if (Test-Path $s) { $l = $sh.CreateShortcut($s); $l.TargetPath = $appExe; $l.Arguments = ''; $l.IconLocation = "$appExe,0"; $l.Save() } }
  foreach ($d in @($a.defDir, $a.legacyDir)) {
    if ($d -and (Test-Path $d)) {
      foreach ($f in @($a.daemonFile, $a.flagsFile, $a.launcherFile)) { $lf = Join-Path $d $f; if (Test-Path $lf) { Remove-Item $lf -Force -ErrorAction SilentlyContinue } }
      try { if (-not (Get-ChildItem $d -Force -ErrorAction SilentlyContinue)) { Remove-Item $d -Force -ErrorAction SilentlyContinue } } catch {}
    }
  }
  Get-Process -Name $a.procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep 2
  if (Test-Path $appExe) { Start-Process $appExe }
  Write-Host "     $($a.name) bypass removed (task + launch points reset, app restarted)." -ForegroundColor Green
}

function Restart-Elevated {
  try { Start-Process $env:SELF -Verb RunAs } catch {}
  exit
}

# --- auto-updater (opt-in) --------------------------------------------------
$VERSION       = '1.0.0'
$UPDATE_BASE   = 'https://raw.githubusercontent.com/RaggyXXX/unleashed/main/dist'
$UpdaterDir    = "$env:LOCALAPPDATA\UnleashedBypass"
$UpdaterCfg    = Join-Path $UpdaterDir 'updater.json'
$UpdaterScript = Join-Path $UpdaterDir 'unleashed-updater.ps1'
$UpdaterVbs    = Join-Path $UpdaterDir 'updater-launcher.vbs'
$UpdaterRunKey = 'UnleashedUpdater'
$UpdaterTask   = 'UnleashedUpdater'

function Get-UpdaterStatus {
  if (-not (Test-Path $UpdaterCfg)) { return [pscustomobject]@{ enabled=$false; base=$UPDATE_BASE } }
  try { $c = [IO.File]::ReadAllText($UpdaterCfg) | ConvertFrom-Json } catch { return [pscustomobject]@{ enabled=$false; base=$UPDATE_BASE } }
  return [pscustomobject]@{ enabled=[bool]$c.enabled; base=$c.base }
}

# --- web fetch + version state (shared by web-installer + updater) ----------
$script:ManifestCache = $null
$script:ManifestTried = $false

function Get-WebString($url) {
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
  try {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Timeout = 6000; $req.ReadWriteTimeout = 6000; $req.UserAgent = 'UnleashedBypass'
    $resp = $req.GetResponse()
    $sr = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    $out = $sr.ReadToEnd(); $sr.Close(); $resp.Close(); return $out
  } catch { return $null }
}
function Get-WebFile($url, $path) {
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
  try { (New-Object System.Net.WebClient).DownloadFile($url, $path); return $true } catch { return $false }
}
function Get-Sha256($path) { try { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLower() } catch { return $null } }

function Get-StateBase {
  $s = Get-UpdaterStatus
  if ($s.base -and ($s.base -notmatch 'REPLACE_ME')) { return ([string]$s.base).TrimEnd('/') }
  return $UPDATE_BASE.TrimEnd('/')
}
function Get-RemoteManifest {
  if ($script:ManifestTried) { return $script:ManifestCache }
  $script:ManifestTried = $true
  $b = Get-StateBase
  if ($b -match 'REPLACE_ME') { return $null }
  $txt = Get-WebString ($b + '/manifest.json')
  if ($txt) { try { $script:ManifestCache = $txt | ConvertFrom-Json } catch { $script:ManifestCache = $null } }
  return $script:ManifestCache
}

function Load-State { if (Test-Path $UpdaterCfg) { try { return ([IO.File]::ReadAllText($UpdaterCfg) | ConvertFrom-Json) } catch {} } return $null }
function Save-State($obj) { New-Item -ItemType Directory -Force -Path $UpdaterDir | Out-Null; [IO.File]::WriteAllText($UpdaterCfg, ($obj | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false))) }
function New-State {
  [pscustomobject]@{ enabled=$false; base=$UPDATE_BASE; cliPath=$env:SELF;
    apps=[pscustomobject]@{ poro=[pscustomobject]@{ dir=$Apps['poro'].defDir; daemon=$Apps['poro'].daemonFile }; blitz=[pscustomobject]@{ dir=$Apps['blitz'].defDir; daemon=$Apps['blitz'].daemonFile } };
    versions=[pscustomobject]@{ cli=$VERSION; poro='0.0.0'; blitz='0.0.0' } }
}
function Ensure-Versions($st) {
  if (-not ($st.PSObject.Properties['versions'])) { $st | Add-Member -NotePropertyName versions -NotePropertyValue ([pscustomobject]@{ cli=$VERSION; poro='0.0.0'; blitz='0.0.0' }) -Force }
  return $st
}
function Set-StateVersion($key, $ver) {
  $st = Load-State; if (-not $st) { $st = New-State }
  $st = Ensure-Versions $st
  if ($st.versions.PSObject.Properties[$key]) { $st.versions.$key = [string]$ver } else { $st.versions | Add-Member -NotePropertyName $key -NotePropertyValue ([string]$ver) -Force }
  Save-State $st
}
function Get-StateVersion($key) {
  $st = Load-State
  if ($st -and $st.PSObject.Properties['versions'] -and $st.versions.PSObject.Properties[$key]) { return [string]$st.versions.$key }
  return $null
}
function VerCmp($a, $b) {
  $pa = "$a" -split '\.'; $pb = "$b" -split '\.'; $n = [Math]::Max($pa.Count, $pb.Count)
  for ($i=0; $i -lt $n; $i++) { $x=0;$y=0; if ($i -lt $pa.Count){[void][int]::TryParse([string]$pa[$i],[ref]$x)}; if ($i -lt $pb.Count){[void][int]::TryParse([string]$pb[$i],[ref]$y)}; if ($x -ne $y){ return ($x - $y) } }
  return 0
}
function Get-CompVer($key) {
  $inst = if ($key -eq 'cli') { $VERSION } else { $v = Get-StateVersion $key; if ($v) { $v } else { $null } }
  $man = Get-RemoteManifest
  $lat = if ($man -and $man.$key) { [string]$man.$key.version } else { $null }
  $upd = ($inst -and $lat -and ((VerCmp $lat $inst) -gt 0))
  return @{ inst=$inst; lat=$lat; upd=$upd }
}

function Install-DaemonFile($a, $dir) {
  # pure web installer: pull the daemon from the update source + verify SHA256 (manifest). No bundle.
  $target = Join-Path $dir $a.daemonFile
  $man = Get-RemoteManifest
  if (-not ($man -and $man.($a.key))) { return @{ ver=$null; web=$false; err='update source unreachable' } }
  $m = $man.($a.key)
  $url = if ($m.PSObject.Properties['url'] -and $m.url) { [string]$m.url } else { (Get-StateBase) + '/' + $m.file }
  $tmp = $target + '.dl'
  if (-not (Get-WebFile $url $tmp)) { return @{ ver=$null; web=$false; err='download failed' } }
  if ((Get-Sha256 $tmp) -ne ([string]$m.sha256).ToLower()) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue; return @{ ver=$null; web=$false; err='checksum mismatch' } }
  try { Move-Item $tmp $target -Force } catch { Remove-Item $tmp -Force -ErrorAction SilentlyContinue; return @{ ver=$null; web=$false; err='write failed' } }
  Set-StateVersion $a.key ([string]$m.version)
  return @{ ver=[string]$m.version; web=$true }
}

# --- installer self-update --------------------------------------------------
function Get-CliUpdate {
  $man = Get-RemoteManifest
  if (-not ($man -and $man.cli)) { return $null }
  if ((VerCmp ([string]$man.cli.version) $VERSION) -gt 0) { return $man.cli }
  return $null
}
function Update-Self {
  $c = Get-CliUpdate
  if (-not $c) { Write-Host '   Installer is already up to date.' -ForegroundColor Green; return }
  $cur = $env:SELF
  if (-not $cur -or -not (Test-Path $cur)) { Write-Host '   Cannot locate the installer file.' -ForegroundColor Red; return }
  $url = if ($c.PSObject.Properties['url'] -and $c.url) { [string]$c.url } else { (Get-StateBase) + '/' + $c.file }
  $tmp = $cur + '.new'
  Write-Host ('   Downloading installer v' + $c.version + ' ...') -ForegroundColor Cyan
  if (-not (Get-WebFile $url $tmp)) { Write-Host '   Download failed.' -ForegroundColor Red; return }
  if ((Get-Sha256 $tmp) -ne ([string]$c.sha256).ToLower()) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue; Write-Host '   Checksum mismatch - update aborted.' -ForegroundColor Red; return }
  Set-StateVersion 'cli' ([string]$c.version)
  $hp = Join-Path $env:TEMP 'ub_selfupdate.cmd'
  $h = "@echo off`r`n:w`r`nping -n 2 127.0.0.1 >nul`r`nmove /y `"$tmp`" `"$cur`" >nul 2>&1`r`nif errorlevel 1 goto w`r`nstart `"`" `"$cur`"`r`n"
  [IO.File]::WriteAllText($hp, $h, [Text.Encoding]::ASCII)
  Write-Host ('   Installer updated to v' + $c.version + '. Restarting...') -ForegroundColor Green
  Start-Sleep -Milliseconds 600
  Start-Process 'cmd.exe' -ArgumentList '/c', $hp -WindowStyle Hidden
  exit
}
function Invoke-CliUpdateCheck {
  $c = Get-CliUpdate
  if (-not $c) { return }
  Write-Host ''
  Write-Host ('   ' + [char]0x25B2 + ' INSTALLER UPDATE AVAILABLE   v' + $VERSION + '  ->  v' + $c.version) -ForegroundColor Yellow
  Write-Host  '   The installer itself should be updated.' -ForegroundColor DarkGray
  $ans = Read-Host '   Update now? [Y/n]'
  if ($ans -notmatch '^[nN]') { Update-Self }
}
function Write-UpdaterScript {
  New-Item -ItemType Directory -Force -Path $UpdaterDir | Out-Null
  $body = @'
$ErrorActionPreference='SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
$cfgPath = Join-Path $PSScriptRoot 'updater.json'
if (-not (Test-Path $cfgPath)) { return }
$cfg = [IO.File]::ReadAllText($cfgPath) | ConvertFrom-Json
if (-not $cfg.enabled) { return }
function VerGt($a,$b){
  $pa = "$a" -split '\.'; $pb = "$b" -split '\.'
  $n = [Math]::Max($pa.Count,$pb.Count)
  for($i=0;$i -lt $n;$i++){
    $x=0;$y=0
    if($i -lt $pa.Count){ [void][int]::TryParse([string]$pa[$i],[ref]$x) }
    if($i -lt $pb.Count){ [void][int]::TryParse([string]$pb[$i],[ref]$y) }
    if($x -gt $y){return $true}; if($x -lt $y){return $false}
  }
  return $false
}
function FileHash256($p){ (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower() }
$base = ([string]$cfg.base).TrimEnd('/')
$wc = New-Object System.Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8; try { $manTxt = $wc.DownloadString($base + '/manifest.json') } catch { return }
try { $man = $manTxt | ConvertFrom-Json } catch { return }
$changed = $false
function ApplyComp($name,$target){
  $m = $man.$name; if(-not $m){ return $false }
  $cur = $cfg.versions.$name
  if(-not (VerGt $m.version $cur)){ return $false }
  $url = if ($m.PSObject.Properties['url'] -and $m.url) { [string]$m.url } else { $base + '/' + $m.file }
  $tmp = $target + '.new'
  try { (New-Object System.Net.WebClient).DownloadFile($url, $tmp) } catch { return $false }
  if(-not (Test-Path $tmp)){ return $false }
  if((FileHash256 $tmp) -ne ([string]$m.sha256).ToLower()){ Remove-Item $tmp -Force; return $false }
  try { Move-Item $tmp $target -Force } catch { Remove-Item $tmp -Force -ErrorAction SilentlyContinue; return $false }
  $cfg.versions.$name = [string]$m.version
  return $true
}
if($cfg.cliPath -and (Test-Path $cfg.cliPath)){ if(ApplyComp 'cli' $cfg.cliPath){ $changed=$true } }
foreach($k in @('poro','blitz')){
  $app = $cfg.apps.$k; if(-not $app){ continue }
  $dp = Join-Path $app.dir $app.daemon
  if(Test-Path $dp){
    $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like ('*'+$app.daemon+'*') }
    if(ApplyComp $k $dp){
      $changed=$true
      if($procs){
        $procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep 2
        Start-Process 'powershell.exe' -WindowStyle Hidden -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + $dp + '"')
      }
    }
  }
}
if($changed){ [IO.File]::WriteAllText($cfgPath, ($cfg | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false))) }
'@
  [IO.File]::WriteAllText($UpdaterScript, $body, (New-Object Text.UTF8Encoding($false)))
  $vbs = @(
    'Set sh = CreateObject("WScript.Shell")',
    'q = Chr(34)',
    ('sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & q & "' + $UpdaterScript + '" & q, 0, False')
  ) -join "`r`n"
  [IO.File]::WriteAllText($UpdaterVbs, $vbs, [Text.Encoding]::ASCII)
}

function Install-Updater($base) {
  if ([string]::IsNullOrWhiteSpace($base)) { $base = Get-StateBase }
  New-Item -ItemType Directory -Force -Path $UpdaterDir | Out-Null
  Write-UpdaterScript
  $st = Load-State; if (-not $st) { $st = New-State }
  $st = Ensure-Versions $st
  $st.enabled = $true
  $st.base = $base
  if ($st.PSObject.Properties['cliPath']) { $st.cliPath = $env:SELF } else { $st | Add-Member -NotePropertyName cliPath -NotePropertyValue $env:SELF -Force }
  if (-not ($st.PSObject.Properties['apps'])) { $st | Add-Member -NotePropertyName apps -NotePropertyValue ([pscustomobject]@{ poro=[pscustomobject]@{ dir=$Apps['poro'].defDir; daemon=$Apps['poro'].daemonFile }; blitz=[pscustomobject]@{ dir=$Apps['blitz'].defDir; daemon=$Apps['blitz'].daemonFile } }) -Force }
  Save-State $st
  try { Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $UpdaterRunKey -Value ('"' + $env:SystemRoot + '\System32\wscript.exe" "' + $UpdaterVbs + '"') } catch {}
  try {
    $act = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" -Argument ('"' + $UpdaterVbs + '"')
    $t1  = New-ScheduledTaskTrigger -AtLogOn
    $t2  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 6)
    $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $UpdaterTask -Action $act -Trigger $t1,$t2 -Settings $set -Force | Out-Null
  } catch {}
  try { Start-Process 'wscript.exe' -ArgumentList ('"' + $UpdaterVbs + '"') } catch {}
}

function Remove-Updater {
  if (Test-Path $UpdaterCfg) {
    try { $c = [IO.File]::ReadAllText($UpdaterCfg) | ConvertFrom-Json; $c.enabled=$false; [IO.File]::WriteAllText($UpdaterCfg, ($c | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false))) } catch {}
  }
  Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $UpdaterRunKey -ErrorAction SilentlyContinue
  try { Unregister-ScheduledTask -TaskName $UpdaterTask -Confirm:$false -ErrorAction SilentlyContinue } catch {}
  foreach($f in @($UpdaterScript,$UpdaterVbs,$UpdaterCfg)){ Remove-Item $f -Force -ErrorAction SilentlyContinue }
}

function Invoke-UpdateNow {
  if (-not (Test-Path $UpdaterScript)) { Write-Host '   Auto-updater not installed (use [U] -> install first).' -ForegroundColor Yellow; return }
  Write-Host '   Checking for updates...' -ForegroundColor DarkGray
  & powershell -NoProfile -ExecutionPolicy Bypass -File $UpdaterScript
  Write-Host '   Update check finished.' -ForegroundColor Green
}

function Invoke-UpdaterLaunchCheck {
  $u = Get-UpdaterStatus
  if ($u.enabled -and (Test-Path $UpdaterVbs)) { try { Start-Process 'wscript.exe' -ArgumentList ('"' + $UpdaterVbs + '"') } catch {} }
}

function Offer-Updater {
  if ((Get-UpdaterStatus).enabled) { return }
  Write-Host ''
  $ans = Read-Host '   Install the auto-updater too (keeps everything up to date)? [Y/n]'
  if ($ans -notmatch '^[nN]') { Install-Updater $null; Write-Host '   Auto-updater enabled.' -ForegroundColor Green }
}

function Menu-Updater {
  while ($true) {
    try { Clear-Host } catch {}
    Write-Host ''
    $u = Get-UpdaterStatus
    Sec 'AUTO-UPDATER'
    Write-Host '     status  : ' -NoNewline -ForegroundColor DarkGray
    if ($u.enabled) { Write-Host 'ON' -ForegroundColor Green } else { Write-Host 'off' -ForegroundColor DarkGray }
    Write-Host ('     source  : ' + $u.base) -ForegroundColor DarkGray
    foreach ($comp in @('cli','poro','blitz')) {
      $vi = Get-CompVer $comp
      $instS = if ($vi.inst) { 'v' + $vi.inst } else { '-' }
      $latS  = if ($vi.lat)  { 'v' + $vi.lat }  else { '?' }
      Write-Host ('     ' + $comp.PadRight(7) + ' installed ' + $instS.PadRight(10)) -NoNewline -ForegroundColor DarkGray
      if ($vi.upd) { Write-Host ('latest ' + $latS + '   << UPDATE') -ForegroundColor Yellow }
      elseif ($vi.lat) { Write-Host ('latest ' + $latS) -ForegroundColor DarkGreen }
      else { Write-Host 'latest  (offline)' -ForegroundColor DarkGray }
    }
    Write-Host ''
    Aopt '1' 'Install / enable auto-updater' $null
    Aopt '2' 'Disable / remove auto-updater' $null
    Aopt '3' 'Check for updates now' $null
    Aopt '4' 'Change update source URL' $null
    Aopt '5' 'Update the installer itself' $null
    Aopt '0' 'Back' $null
    $uc = Read-Host ('   ' + $G.arr + ' choice')
    switch ($uc) {
      '1' { Install-Updater $null; Write-Host '   Auto-updater enabled.' -ForegroundColor Green; Pause2 }
      '2' { Remove-Updater; Write-Host '   Auto-updater removed.' -ForegroundColor Yellow; Pause2 }
      '3' { Invoke-UpdateNow; Pause2 }
      '4' { $nb = Read-Host '   New update source URL'; if ($nb) { Install-Updater $nb; Write-Host '   Source updated + enabled.' -ForegroundColor Green; Pause2 } }
      '5' { Update-Self; Pause2 }
      '0' { return }
      default { }
    }
  }
}

# --- UI theme + helpers -----------------------------------------------------
$IW = 56
$FW = 58
$G = @{ tl=[string][char]0x2554; tr=[string][char]0x2557; bl=[string][char]0x255A; br=[string][char]0x255D;
        h=[string][char]0x2550; v=[string][char]0x2551; line=[string][char]0x2500;
        dot=[string][char]0x25CF; ring=[string][char]0x25CB; mid=[string][char]0x00B7; arr=[string][char]0x25B8 }
function BTop { Write-Host ('  ' + $G.tl + ($G.h * $IW) + $G.tr) -ForegroundColor DarkRed }
function BBot { Write-Host ('  ' + $G.bl + ($G.h * $IW) + $G.br) -ForegroundColor DarkRed }
function BMid($text, $color) {
  $t = [string]$text; if ($t.Length -gt $IW) { $t = $t.Substring(0, $IW) }
  $pad = $IW - $t.Length; $l = [int][Math]::Floor($pad / 2); $r = $pad - $l
  Write-Host ('  ' + $G.v) -NoNewline -ForegroundColor DarkRed
  Write-Host ((' ' * $l) + $t + (' ' * $r)) -NoNewline -ForegroundColor $color
  Write-Host $G.v -ForegroundColor DarkRed
}
function Line2 { Write-Host ('  ' + ($G.line * $FW)) -ForegroundColor DarkGray }
function Sec($text) { Write-Host ''; Write-Host ('   ' + $text) -ForegroundColor White; Line2 }
function Grp($text) { Write-Host ('     ' + $text) -ForegroundColor DarkCyan }
function Srow($glyph, $gcolor, $name, $desc) {
  Write-Host '     ' -NoNewline
  Write-Host $glyph -NoNewline -ForegroundColor $gcolor
  Write-Host ('  ' + $name.PadRight(15)) -NoNewline -ForegroundColor Gray
  Write-Host $desc -ForegroundColor DarkGray
}
function Aopt($key, $text, $hint) {
  Write-Host '       ' -NoNewline
  Write-Host $key.PadRight(4) -NoNewline -ForegroundColor Cyan
  if ($hint) { Write-Host $text.PadRight(32) -NoNewline -ForegroundColor Gray; Write-Host $hint -ForegroundColor DarkGreen }
  else       { Write-Host $text -ForegroundColor Gray }
}
function Show-Status {
  Sec 'STATUS'
  foreach ($k in $Order) {
    $s = Get-AppStatus $Apps[$k]
    if (-not $s.exe)        { Srow $G.ring 'DarkGray' $s.name 'app not found' }
    elseif ($s.active)      { Srow $G.dot 'Green'  $s.name ('ad-free running' + $(if ($s.task) { '   ' + $G.mid + ' admin-locked' } else { '' })) }
    elseif ($s.broken)      { Srow $G.dot 'Red'    $s.name 'launch point broken - press R to repair' }
    elseif ($s.mislocated)  { Srow $G.dot 'Yellow' $s.name 'old location - press R to move to stable path' }
    elseif ($s.installed)   { Srow $G.dot 'Yellow' $s.name ('installed, inactive (' + $(if ($s.running) { 'app running, healing' } else { 'app not started' }) + ')') }
    else                    { Srow $G.dot 'Cyan'   $s.name 'ready to install' }
  }
}

function Invoke-StartupRepairCheck {
  $bad = @()
  foreach ($k in $Order) { $s = Get-AppStatus $Apps[$k]; if ($s.exe -and ($s.broken -or $s.mislocated)) { $bad += ,@($k, $s) } }
  if (-not $bad.Count) { return }
  Write-Host ''
  Write-Host '   BROKEN / OUTDATED INSTALL DETECTED' -ForegroundColor Yellow
  Line2
  foreach ($b in $bad) {
    $s = $b[1]
    $why = if ($s.broken) { 'launch point points to missing files' } else { 'installed in an old location' }
    Write-Host ("     - $($s.name): $why") -ForegroundColor Yellow
    if ($s.lpPath) { Write-Host ("         now -> $($s.lpPath)") -ForegroundColor DarkGray }
  }
  Write-Host ''
  $ans = Read-Host '   Repair now to the stable location? [Y/n]'
  if ($ans -notmatch '^[nN]') {
    foreach ($b in $bad) { Repair-App $Apps[$b[0]] }
    Write-Host ''; Write-Host '   Repair complete.' -ForegroundColor Green
    Pause2
  }
}

Invoke-StartupRepairCheck
Invoke-CliUpdateCheck
Invoke-UpdaterLaunchCheck

while ($true) {
  try { Clear-Host } catch {}
  BTop
  BMid 'U N L E A S H E D   B Y P A S S' 'White'
  BMid 'made by Ragou' 'Red'
  BMid 'https://high-minded.cx/members/ragou.709/' 'DarkCyan'
  BBot
  if (IsAdmin) {
    Write-Host '   ' -NoNewline; Write-Host ' ADMIN ' -NoNewline -ForegroundColor Black -BackgroundColor Green
    Write-Host '   admin-locked task active' -ForegroundColor DarkGray
  } else {
    Write-Host '   ' -NoNewline; Write-Host ' STANDARD ' -NoNewline -ForegroundColor Black -BackgroundColor Gray
    Write-Host '   press 8 to elevate' -ForegroundColor DarkGray
  }
  $us = Get-UpdaterStatus
  Write-Host '   ' -NoNewline
  if ($us.enabled) { Write-Host ' AUTO-UPDATE ON ' -NoNewline -ForegroundColor Black -BackgroundColor DarkCyan } else { Write-Host ' auto-update off ' -NoNewline -ForegroundColor DarkGray }
  $cv = Get-CompVer 'cli'
  Write-Host ('     v' + $VERSION) -NoNewline -ForegroundColor DarkGray
  if ($cv.lat -and $cv.upd) { Write-Host ('   ->  v' + $cv.lat + ' available') -ForegroundColor Yellow }
  elseif ($cv.lat) { Write-Host '   (up to date)' -ForegroundColor DarkGreen }
  else { Write-Host '' }
  Show-Status
  Sec 'ACTIONS'
  Grp 'install'
  Aopt '1' 'Auto-install everywhere' 'recommended'
  Aopt '2' 'Porofessor' $null
  Aopt '3' 'Blitz' $null
  Aopt '4' 'Both apps' $null
  Grp 'maintain'
  Aopt 'R' 'Repair / re-point all installs' $null
  Aopt '5' 'Uninstall Porofessor' $null
  Aopt '6' 'Uninstall Blitz' $null
  Grp 'system'
  Aopt '7' 'Install with custom paths' $null
  Aopt '8' 'Restart as Administrator' $null
  Aopt 'U' 'Auto-updater  (install / status)' $null
  Aopt '0' 'Exit' $null
  Line2
  $c = Read-Host ('   ' + $G.arr + ' choice')
  switch ($c) {
    '1' {
      Write-Host ''
      Write-Host '   Auto-install: installing everywhere possible' -ForegroundColor Cyan
      $any = $false
      foreach ($k in $Order) {
        $a = $Apps[$k]; $exe = Find-AppExe $a
        if ($exe) { $any = $true; Install-App $a $exe $null }
        else { Write-Host ''; Write-Host "   $($a.name): app not found - skipped" -ForegroundColor DarkGray }
      }
      if (-not $any) { Write-Host '   No supported app found.' -ForegroundColor Red }
      Offer-Updater

      Pause2
    }
    '2' { Install-App $Apps['poro'] $null $null; Offer-Updater; Pause2 }
    '3' { Install-App $Apps['blitz'] $null $null; Offer-Updater; Pause2 }
    '4' { Install-App $Apps['poro'] $null $null; Install-App $Apps['blitz'] $null $null; Offer-Updater; Pause2 }
    'r' {
      Write-Host ''
      Write-Host '   Repair: re-pointing all detected installs to the stable location' -ForegroundColor Cyan
      $any = $false
      foreach ($k in $Order) { $s = Get-AppStatus $Apps[$k]; if ($s.exe) { $any = $true; Repair-App $Apps[$k] } }
      if (-not $any) { Write-Host '   No supported app found.' -ForegroundColor Red }
      Pause2
    }
    '5' { Uninstall-App $Apps['poro'] $null; Pause2 }
    '6' { Uninstall-App $Apps['blitz'] $null; Pause2 }
    '7' {
      Write-Host ''
      $w = Read-Host '   Which app?  [1] Porofessor   [2] Blitz'
      $a = $null; if ($w -eq '1') { $a = $Apps['poro'] } elseif ($w -eq '2') { $a = $Apps['blitz'] }
      if (-not $a) { Write-Host '   Invalid choice.' -ForegroundColor Red; Pause2; continue }
      $ce = Read-Host '   App EXE path  (empty = auto-detect)'
      $cd = Read-Host "   Install folder  (empty = $($a.defDir))"
      Install-App $a $ce $cd; Pause2
    }
    '8' { if (-not (IsAdmin)) { Restart-Elevated } else { Write-Host '   Already running as admin.' -ForegroundColor Green; Pause2 } }
    'u' { Menu-Updater }
    '0' { return }
    default { }
  }
}
