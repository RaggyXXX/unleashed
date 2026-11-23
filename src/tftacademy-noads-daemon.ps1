# Blocks ad requests and reclaims TFTAcademy ad panels through CDP.
$ErrorActionPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PORT       = 9226
$IP         = '127.0.0.1'
$TASK       = 'TFTAcademyNoAds'
$MUTEX_NAME = 'Global\TFTAcademyNoAds.singleton'
$YIELD_NAME = 'Global\TFTAcademyNoAds.yield'
$APP_IMAGE  = 'TFTAcademy.exe'
$DIR        = $PSScriptRoot
if (-not $DIR) {
  $DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$FLAGS      = Join-Path $DIR 'tftacademy-flags.ps1'
$LAUNCHER   = Join-Path $DIR 'tftacademy-launcher.vbs'
$APP_KEY    = 'tftacademy'
$STATE      = Join-Path (Split-Path $DIR -Parent) 'updater.json'
$WSCRIPT    = Join-Path $env:SystemRoot 'System32\wscript.exe'

$BLOCK = @(
  '*overwolf.com/monsdk*', '*/adview.html*', '*overwolf.com*/ads*', '*monetization*',
  '*doubleclick.net*', '*googlesyndication*', '*googletagservices*', '*googleadservices*',
  '*googletagmanager.com*', '*amazon-adsystem*', '*adnxs*', '*pubmatic*', '*rubiconproject*',
  '*casalemedia*', '*33across*', '*smartadserver*', '*yieldlab*', '*onetag-sys*', '*criteo*',
  '*sharethrough*', '*3lift*', '*media.net*', '*indexww*', '*sonobi*', '*gumgum*', '*teads*',
  '*openx*', '*yieldmo*', '*adform.net*', '*smilewanted*', '*admatic.de*', '*2mdn.net*',
  '*adsrvr.org*', '*ad.gt*', '*360yield*', '*geoedge*', '*arttrk*', '*bttrack*', '*moatads*',
  '*adsafeprotected*', '*simpli.fi*', '*ads.linkedin.com*', '*content.overwolf.com/libs/ads/*',
  '*content.overwolf.com/*/adview*'
)

# TFTAcademy 0.9.25 uses a tower ad column and a sticky studio ad panel.
$INJECTOR = @'
(function () {
  var injectorVersion = 2;
  if (window.__unleashedTFTAcademyNoAds === injectorVersion) {
    return;
  }
  if (/\/(overlay|display)(?:\.html)?\/?$/.test(location.pathname)) {
    return;
  }
  window.__unleashedTFTAcademyNoAds = injectorVersion;

  var tower = '.shrink-0[class~="basis-[360px]"]:has(owadview[cid^="tower-plus-"])';
  var studio = '.sticky.bottom-0:has(owadview[cid^="studio-"])';
  var adSurfaces = 'owadview,ow-ad,ins.adsbygoogle,[id^="google_ads_iframe"],iframe[src*="doubleclick.net"],iframe[src*="googlesyndication.com"]';
  var content = '[class~="@container/desktop"]';
  var sidebar = '.fixed.h-screen:has(img[alt="TFT ACADEMY logo"])';
  var sidebarPromotions = sidebar + ' > .relative[class~="h-[120px]"]:has(> button),' +
    sidebar + ' > .mt-auto > .relative[class~="h-[100px]"]:has(a[href="/academyplus"])';
  var sidebarCss = sidebarPromotions + ' { display: none !important; }';
  var css = tower + ',' + studio + ',' + adSurfaces + ' {' +
    'display: none !important; width: 0 !important; height: 0 !important;' +
    'min-width: 0 !important; min-height: 0 !important;' +
    'margin: 0 !important; padding: 0 !important; overflow: hidden !important;' +
    '}' +
    content + ' { flex: 1 1 0% !important; min-width: 0 !important; }' +
    content + ' > .w-full { width: 100% !important; max-width: none !important; }';

  function ensureStyle() {
    var style = document.getElementById('unleashed-tftacademy-noads');
    if (!style) {
      style = document.createElement('style');
      style.id = 'unleashed-tftacademy-noads';
      (document.head || document.documentElement).appendChild(style);
    }
    if (style.textContent !== css) {
      style.textContent = css;
    }
    var sidebarStyle = document.getElementById('unleashed-tftacademy-sidebar');
    if (!sidebarStyle) {
      sidebarStyle = document.createElement('style');
      sidebarStyle.id = 'unleashed-tftacademy-sidebar';
      (document.head || document.documentElement).appendChild(sidebarStyle);
    }
    if (sidebarStyle.textContent !== sidebarCss) {
      sidebarStyle.textContent = sidebarCss;
    }
  }

  function updateBanner() {
    try {
      var update = window.__unlUpd;
      var banner = document.getElementById('__unl_banner');
      if (!update || !update.avail || window.__unlHide) {
        if (banner) {
          banner.style.display = 'none';
        }
        return;
      }
      if (!document.body) {
        return;
      }
      if (!banner) {
        banner = document.createElement('div');
        banner.id = '__unl_banner';
        banner.style.cssText='position:fixed;top:14px;right:16px;z-index:2147483647;width:300px;font-family:Segoe UI,system-ui,sans-serif;color:#e8ecff;background:linear-gradient(135deg,#20223a,#171829);border:1px solid #5865f2;border-radius:12px;box-shadow:0 10px 30px rgba(0,0,0,.5);padding:13px 14px';
        banner.innerHTML='<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px"><span style="font-size:16px">&#9889;</span><b style="font-size:13px;letter-spacing:.2px">Unleashed update available</b></div>'+
          '<div id="__unl_ver" style="font-size:12px;opacity:.8;margin-bottom:10px"></div>'+
          '<div style="display:flex;gap:8px;align-items:center">'+
          '<button id="__unl_up" style="flex:1;cursor:pointer;border:0;border-radius:8px;padding:8px 10px;font-weight:700;font-size:12px;color:#fff;background:linear-gradient(135deg,#6b8afd,#4f46e5)">Update now</button>'+
          '<button id="__unl_hd" style="cursor:pointer;border:1px solid #3a3d5c;border-radius:8px;padding:8px 10px;font-size:12px;color:#aab0d6;background:transparent">Later</button>'+
          '</div>'+
          '<div style="display:flex;gap:14px;margin-top:9px;font-size:11px">'+
          '<a id="__unl_au" href="#" style="color:#8aa0ff;text-decoration:none">Auto-update</a>'+
          '<a id="__unl_nv" href="#" style="color:#6b7099;text-decoration:none">Never show again</a>'+
          '</div>';
        document.body.appendChild(banner);
        function act(action) {
          window.__unlAct = action;
        }
        banner.querySelector('#__unl_up').onclick = function () {
          var version = document.getElementById('__unl_ver');
          if (version) {
            version.textContent = 'Updating...';
          }
          act('update');
        };
        banner.querySelector('#__unl_hd').onclick = function () {
          window.__unlHide = true;
          banner.style.display = 'none';
          act('hide');
        };
        banner.querySelector('#__unl_au').onclick = function (event) {
          event.preventDefault();
          window.__unlHide = true;
          banner.style.display = 'none';
          act('auto');
        };
        banner.querySelector('#__unl_nv').onclick = function (event) {
          event.preventDefault();
          window.__unlHide = true;
          banner.style.display = 'none';
          act('never');
        };
      }
      banner.style.display = 'block';
      var versionLabel = document.getElementById('__unl_ver');
      if (versionLabel && !/Updating/.test(versionLabel.textContent)) {
        var label = 'v' + (update.cur || '?') + ' -> v' + (update.lat || '?');
        if (versionLabel.textContent !== label) {
          versionLabel.textContent = label;
        }
      }
    } catch (error) {
    }
  }

  function apply() {
    if (!document.documentElement) {
      return;
    }
    ensureStyle();
    updateBanner();
  }

  var pending = false;
  function scheduleApply() {
    if (pending) {
      return;
    }
    pending = true;
    setTimeout(function () {
      pending = false;
      apply();
    }, 100);
  }

  apply();
  new MutationObserver(scheduleApply).observe(document, {
    childList: true,
    subtree: true
  });
  setInterval(apply, 800);
})();
'@

function Log([string]$m){
  try {
    [Console]::Out.WriteLine('[tftacademy-noads] ' + $m)
  }
  catch {
  }
}
function Now-Ms {
  [long]([Diagnostics.Stopwatch]::GetTimestamp() / ([Diagnostics.Stopwatch]::Frequency / 1000))
}

function Test-Elevated {
  try {
    (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  }
  catch {
    $true
  }  # fail-open: if we cannot tell, run rather than defer
}
$elevated = Test-Elevated
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $MUTEX_NAME, [ref]$createdNew)
$yield = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::ManualReset, $YIELD_NAME)
if (-not $createdNew) {
  if ($elevated) {
    # Elevated copy takes over from a non-elevated holder: signal yield, then grab.
    $yield.Set() | Out-Null
    $self = $PSCommandPath
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
      $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine.IndexOf($self,[StringComparison]::OrdinalIgnoreCase) -ge 0
    } | ForEach-Object {
      Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    $got = $false
    try {
      $got = $mutex.WaitOne(10000)
    }
    catch [System.Threading.AbandonedMutexException] {
      $got = $true
    }
    if (-not $got) {
      Log 'could not take over singleton -> exit'
      exit
    }
    $yield.Reset() | Out-Null
    Log 'took over singleton as elevated (replaced non-elevated owner)'
  }
  else {
    Log 'another daemon owns the singleton -> deferring'
    exit
  }
}

$script:ws = $null
$script:connected = $false
$script:wsUrl = $null
$script:cmdId = 0
$ct = [Threading.CancellationToken]::None

function Http-Json([string]$path){
  try {
    $r = Invoke-RestMethod -Uri ("http://{0}:{1}{2}" -f $IP,$PORT,$path) -TimeoutSec 4
    return $r
  }
  catch {
    return $null
  }
}
function Send-Cdp([string]$method, $params, [string]$session){
  if (-not $script:ws -or $script:ws.State -ne 'Open') {
    return
  }
  $script:cmdId++
  $o = @{
    id = $script:cmdId
    method = $method
  }
  if ($params) {
    $o.params = $params
  }
  else {
    $o.params = @{
    }
  }
  if ($session) {
    $o.sessionId = $session
  }
  $json = $o | ConvertTo-Json -Compress -Depth 8
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $seg = [System.ArraySegment[byte]]::new($bytes)
    [void]$script:ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).GetAwaiter().GetResult()
  }
  catch {
  }
}
function Configure-Session([string]$s){
  Send-Cdp 'Network.enable' $null $s
  Send-Cdp 'Network.setBlockedURLs' @{
    urls = $BLOCK
  } $s
  Send-Cdp 'Page.enable' $null $s
  Send-Cdp 'Page.addScriptToEvaluateOnNewDocument' @{
    source = $INJECTOR
  } $s
  Send-Cdp 'Runtime.evaluate' @{
    expression = $INJECTOR
  } $s
  Send-Cdp 'Target.setAutoAttach' @{
    autoAttach=$true
    waitForDebuggerOnStart=$true
    flatten=$true
  } $s
  if ($script:sessions -notcontains $s) {
    $script:sessions += $s
  }
  Send-Cdp 'Runtime.runIfWaitingForDebugger' $null $s
}
function Cleanup-Ws {
  if ($script:ws) {
    try {
      $script:ws.Abort()
    }
    catch {
    }
    try {
      $script:ws.Dispose()
    }
    catch {
    }
  }
  $script:ws = $null
  $script:connected = $false
  $script:wsUrl = $null
  $script:sessions = @()
}
function Connect-Cdp {
  $v = Http-Json '/json/version'
  if (-not $v -or -not $v.webSocketDebuggerUrl) {
    return
  }
  if ($script:connected -and $script:wsUrl -eq $v.webSocketDebuggerUrl -and $script:ws.State -eq 'Open') {
    return
  }
  Cleanup-Ws
  try {
    $w = New-Object System.Net.WebSockets.ClientWebSocket
    $w.ConnectAsync([Uri]$v.webSocketDebuggerUrl, $ct).GetAwaiter().GetResult() | Out-Null
    $script:ws = $w
    $script:wsUrl = $v.webSocketDebuggerUrl
    $script:connected = $true
    Log 'connected to browser endpoint'
    Send-Cdp 'Target.setAutoAttach' @{
      autoAttach=$true
      waitForDebuggerOnStart=$true
      flatten=$true
    } $null
  }
  catch {
    Cleanup-Ws
  }
}
function Handle-Message([string]$txt){
  if ($txt -match '__UNLRESP:') {
    try {
      $m = $txt | ConvertFrom-Json
      if ("$($m.result.result.value)" -match '^__UNLRESP:(\w+)') {
        Do-Action $matches[1]
      }
    }
    catch {
    }
    return
  }
  if ($txt -match 'detachedFromTarget') {
    try {
      $m = $txt | ConvertFrom-Json
    }
    catch {
      return
    }
    if ($m.method -eq 'Target.detachedFromTarget' -and $m.params.sessionId) {
      $script:sessions = @($script:sessions | Where-Object {
        $_ -ne $m.params.sessionId
      })
    }
    return
  }
  if ($txt -notmatch 'attachedToTarget') {
    return
  }
  try {
    $m = $txt | ConvertFrom-Json
  }
  catch {
    return
  }
  if ($m.method -eq 'Target.attachedToTarget' -and $m.params.sessionId) {
    Configure-Session $m.params.sessionId
  }
}

$script:sessions     = @()
$script:updInfo      = $null
$script:manifest     = $null
$script:notify       = 'banner'
$script:bannerHidden = $false
$script:lastUpdCheck = 0
$script:lastNotifyRead = 0
$script:offDone = $false
function Read-State {
  try {
    if (Test-Path $STATE) {
      return ([IO.File]::ReadAllText($STATE) | ConvertFrom-Json)
    }
  }
  catch {
  }
  return $null
}
function Save-State($st) {
  try {
    [IO.File]::WriteAllText($STATE, ($st | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
  }
  catch {
  }
}
function Set-StateVer($st,$key,$ver) {
  try {
    if ($st.versions.PSObject.Properties[$key]) {
      $st.versions.$key = [string]$ver
    }
    else {
      $st.versions | Add-Member -NotePropertyName $key -NotePropertyValue ([string]$ver) -Force
    }
    Save-State $st
  }
  catch {
  }
}
function Set-StateNotify($v) {
  try {
    $st = Read-State
    if (-not $st) {
      return
    }
    if ($st.PSObject.Properties['notify']) {
      $st.notify = $v
    }
    else {
      $st | Add-Member -NotePropertyName notify -NotePropertyValue $v -Force
    }
    Save-State $st
    $script:notify = $v
  }
  catch {
  }
}
function Web-Str($url) {
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $w = New-Object Net.WebClient
    $w.Encoding = [Text.Encoding]::UTF8
    return $w.DownloadString($url)
  }
  catch {
    return $null
  }
}
function Web-File($url,$path) {
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object Net.WebClient).DownloadFile($url,$path)
    return $true
  }
  catch {
    return $false
  }
}
function Sha-Of($p) {
  try {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower()
  }
  catch {
    return $null
  }
}
function Ver-Gt($a,$b) {
  $pa = "$a" -split '\.'
  $pb = "$b" -split '\.'
  for ($i=0;$i -lt [Math]::Max($pa.Count,$pb.Count);$i++){
    $x=0
    $y=0
    if($i -lt $pa.Count){
      [void][int]::TryParse([string]$pa[$i],[ref]$x)
    }
    if($i -lt $pb.Count){
      [void][int]::TryParse([string]$pb[$i],[ref]$y)
    }
    if($x -ne $y){
      return ($x -gt $y)
    }
  }
  return $false
}
function Comp-Url($m,$base) {
  if ($m.PSObject.Properties['url'] -and $m.url) {
    return [string]$m.url
  }
  else {
    return ($base.TrimEnd('/') + '/' + $m.file)
  }
}
function Check-Update {
  $st = Read-State
  if (-not $st) {
    return
  }
  $script:notify = if ($st.PSObject.Properties['notify'] -and $st.notify) {
    [string]$st.notify
  }
  else {
    'banner'
  }
  if ($script:notify -eq 'off') {
    $script:updInfo = @{
      avail = $false
    }
    return
  }
  $base = [string]$st.base
  if (-not $base) {
    return
  }
  $txt = Web-Str ($base.TrimEnd('/') + '/manifest.json')
  if (-not $txt) {
    return
  }
  try {
    $man = $txt | ConvertFrom-Json
  }
  catch {
    return
  }
  $script:manifest = $man
  $cur = if ($st.versions.PSObject.Properties[$APP_KEY]) {
    [string]$st.versions.$APP_KEY
  }
  else {
    '0.0.0'
  }
  $lat = if ($man.$APP_KEY) {
    [string]$man.$APP_KEY.version
  }
  else {
    $null
  }
  if ($lat -and (Ver-Gt $lat $cur)) {
    $script:updInfo = @{
      avail = $true
      cur = $cur
      lat = $lat
    }
    if ($script:notify -eq 'auto') {
      Do-Update
    }
  }
  else {
    $script:updInfo = @{
      avail = $false
    }
  }
}
function Push-Update {
  if (-not $script:connected -or -not $script:updInfo) {
    return
  }
  $show = ($script:notify -eq 'banner') -and (-not $script:bannerHidden) -and $script:updInfo.avail
  if ($show) {
    $js = "window.__unlUpd={avail:true,cur:'$($script:updInfo.cur)',lat:'$($script:updInfo.lat)'};"
  }
  else {
    $js = 'window.__unlUpd={avail:false};'
  }
  foreach ($s in $script:sessions) {
    Send-Cdp 'Runtime.evaluate' @{
      expression = $js
    } $s
  }
}
function Poll-Action {
  if (-not $script:connected) {
    return
  }
  foreach ($s in $script:sessions) {
    Send-Cdp 'Runtime.evaluate' @{
      expression = "var a=window.__unlAct||'';window.__unlAct='';'__UNLRESP:'+a"
      returnByValue = $true
    } $s
  }
}
function Do-Update {
  try {
    $st = Read-State
    if (-not $st) {
      return
    }
    $base = [string]$st.base
    $man = $script:manifest
    if (-not $man) {
      $t = Web-Str ($base.TrimEnd('/') + '/manifest.json')
      if ($t) {
        try {
          $man = $t | ConvertFrom-Json
        }
        catch {
        }
      }
    }
    if (-not $man) {
      return
    }
    if ($st.PSObject.Properties['cliPath'] -and $st.cliPath -and (Test-Path $st.cliPath) -and $man.cli) {
      $ccur = if ($st.versions.PSObject.Properties['cli']) {
        [string]$st.versions.cli
      }
      else {
        '0.0.0'
      }
      if (Ver-Gt ([string]$man.cli.version) $ccur) {
        $ctmp = "$($st.cliPath).new"
        if ((Web-File (Comp-Url $man.cli $base) $ctmp) -and ((Sha-Of $ctmp) -eq ([string]$man.cli.sha256).ToLower())) {
          try {
            Move-Item $ctmp $st.cliPath -Force
            Set-StateVer $st 'cli' $man.cli.version
          }
          catch {
          }
        }
        else {
          Remove-Item $ctmp -Force -ErrorAction SilentlyContinue
        }
      }
    }
    $m = $man.$APP_KEY
    if (-not $m) {
      return
    }
    $mcur = if ($st.versions.PSObject.Properties[$APP_KEY]) {
      [string]$st.versions.$APP_KEY
    }
    else {
      '0.0.0'
    }
    if (-not (Ver-Gt ([string]$m.version) $mcur)) {
      return
    }
    $self = $PSCommandPath
    $tmp = "$self.new"
    if (-not (Web-File (Comp-Url $m $base) $tmp)) {
      Remove-Item $tmp -Force -ErrorAction SilentlyContinue
      return
    }
    if ((Sha-Of $tmp) -ne ([string]$m.sha256).ToLower()) {
      Remove-Item $tmp -Force -ErrorAction SilentlyContinue
      return
    }
    Move-Item $tmp $self -Force
    $st2 = Read-State
    if ($st2) {
      Set-StateVer $st2 $APP_KEY $m.version
    }
    Log ('updated to v' + $m.version + ' -> restarting daemon')
    Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$self -WindowStyle Hidden
    Cleanup-Ws
    exit
  }
  catch {
    Log ('update error: ' + $_.Exception.Message)
  }
}
function Do-Action([string]$a) {
  switch ($a) {
    'update' {
      Do-Update
    }
    'hide'   {
      $script:bannerHidden = $true
      Push-Update
    }
    'never'  {
      Set-StateNotify 'off'
      $script:updInfo = @{
        avail = $false
      }
      Push-Update
    }
    'auto'   {
      Set-StateNotify 'auto'
      Do-Update
    }
  }
}
$HEAL_GRACE    = 15000
$HEAL_COOLDOWN = 45000
$MAX_HEALS     = 5
$REASSERT_MS   = 20000

$script:lastSeen = Now-Ms
$script:appGoneSince = 0
$script:portDownSince = 0
$script:lastHeal = 0
$script:healCount = 0
$script:lastReassert = 0

function App-MainPid {
  $p = Get-CimInstance Win32_Process -Filter "Name='$APP_IMAGE'" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -notmatch '--type='
  } | Select-Object -First 1
  if ($p) {
    return $p.ProcessId
  }
  else {
    return $null
  }
}
function App-Present {
  [bool](Get-CimInstance Win32_Process -Filter "Name='$APP_IMAGE'" -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Heal {
  $script:lastHeal = Now-Ms
  $script:healCount++
  Log ("port dead while app runs -> clean restart via launcher ({0}/{1})" -f $script:healCount,$MAX_HEALS)
  $mp = App-MainPid
  if ($mp) {
    & taskkill /PID $mp /T /F 2>$null | Out-Null
  }
  else {
    & taskkill /IM $APP_IMAGE /T /F 2>$null | Out-Null
  }
  Start-Sleep -Milliseconds 1500
  try {
    Start-Process $WSCRIPT -ArgumentList ('"'+$LAUNCHER+'" --ub-relaunch') -WindowStyle Hidden
  }
  catch {
  }
  $script:portDownSince = 0
}
function Reassert {
  $now = Now-Ms
  if (($now - $script:lastReassert) -lt $REASSERT_MS) {
    return
  }
  $script:lastReassert = $now
  try {
    Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',$FLAGS -WindowStyle Hidden
  }
  catch {
  }
}
function Periodic([bool]$portUp){
  Reassert
  $nowt = Now-Ms
  if (($nowt - $script:lastNotifyRead) -ge 30000) {
    $script:lastNotifyRead = $nowt
    try {
      $st0 = Read-State
      $script:notify = if ($st0 -and $st0.PSObject.Properties['notify'] -and $st0.notify) {
        [string]$st0.notify
      }
      else {
        'banner'
      }
    }
    catch {
    }
  }
  if ($script:notify -ne 'off') {
    $script:offDone = $false
    if (($nowt - $script:lastUpdCheck) -ge 3600000) {
      $script:lastUpdCheck = $nowt
      try {
        Check-Update
      }
      catch {
      }
    }
    try {
      Push-Update
    }
    catch {
    }
    try {
      Poll-Action
    }
    catch {
    }
  }
  elseif (-not $script:offDone) {
    $script:offDone = $true
    try {
      foreach ($s in $script:sessions) {
        Send-Cdp 'Runtime.evaluate' @{
          expression = 'window.__unlUpd={avail:false};'
        } $s
      }
    }
    catch {
    }
  }
  if (-not $elevated -and $yield.WaitOne(0)) {
    Log 'yielding singleton to elevated daemon'
    Cleanup-Ws
    exit
  }
  $now = Now-Ms
  if ($portUp) {
    $script:lastSeen = $now
    $script:appGoneSince = 0
    $script:portDownSince = 0
    $script:healCount = 0
    return
  }
  if (-not $script:portDownSince) {
    $script:portDownSince = $now
  }
  if (App-Present) {
    $script:lastSeen = $now
    $script:appGoneSince = 0
    if ((($now - $script:portDownSince) -gt $HEAL_GRACE) -and (($now - $script:lastHeal) -gt $HEAL_COOLDOWN) -and ($script:healCount -lt $MAX_HEALS)) {
      Heal
    }
    elseif (($script:healCount -ge $MAX_HEALS) -and (($now - $script:lastHeal) -gt ($HEAL_COOLDOWN * 5))) {
      $script:healCount = 0
    } # back-off, retry later
  }
  else {
    if (-not $script:appGoneSince) {
      $script:appGoneSince = $now
    }
    $script:portDownSince = 0
    $script:healCount = 0
    Check-Uninstalled
  }
}

$APP_REL      = 'Programs\TFTAcademy\TFTAcademy.exe'
$APP_DISPLAY  = 'TFTAcademy'           # Windows "installed programs" DisplayName match (path-agnostic)
$RUN_VALUE    = 'TFTAcademy'            # our HKCU Run value name
$GONE_KEY     = $APP_KEY + 'Gone'
$GONE_CONFIRM = 3                 # consecutive checks with zero trace before removal
$UNINST_INTERVAL = 300000         # re-evaluate install state at most every 5 min
$script:uninstInit = $false
$script:lastUninstChk = 0
function Find-AppExe {
  $def = Join-Path $env:LOCALAPPDATA $APP_REL
  if (Test-Path -LiteralPath $def) {
    return $def
  }
  $roots = @((Join-Path $env:LOCALAPPDATA 'Programs'), $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData) | Where-Object {
    $_ -and (Test-Path -LiteralPath $_)
  }
  foreach ($r in $roots) {
    try {
      $hit = Get-ChildItem -LiteralPath $r -Filter $APP_IMAGE -Recurse -Depth 3 -File -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($hit) {
        return $hit.FullName
      }
    }
    catch {
    }
  }
  return $null
}
function Test-AppInstalled {
  try {
    if (App-Present) {
      return $true
    }
  }
  catch {
  }
  $unKeys = @(
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  foreach ($k in $unKeys) {
    try {
      if (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -and $_.DisplayName -like ('*' + $APP_DISPLAY + '*')
      }) {
        return $true
      }
    }
    catch {
    }
  }
  foreach ($k in @("HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\$APP_IMAGE", "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\$APP_IMAGE")) {
    try {
      if (Test-Path -LiteralPath $k) {
        return $true
      }
    }
    catch {
    }
  }
  try {
    if (Find-AppExe) {
      return $true
    }
  }
  catch {
  }
  return $false
}
function Remove-Self {
  Log ($APP_DISPLAY + ' uninstall confirmed -> removing bypass autostart + files')
  try {
    & schtasks /delete /tn $TASK /f 2>$null | Out-Null
  }
  catch {
  }
  try {
    & reg delete 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' /v $RUN_VALUE /f 2>$null | Out-Null
  }
  catch {
  }
  try {
    $st = Read-State
    if ($st) {
      if ($st.PSObject.Properties['versions'] -and $st.versions.PSObject.Properties[$APP_KEY]) {
        $st.versions.PSObject.Properties.Remove($APP_KEY)
      }
      if ($st.PSObject.Properties[$GONE_KEY]) {
        $st.PSObject.Properties.Remove($GONE_KEY)
      }
      Save-State $st
    }
  }
  catch {
  }
  foreach ($companionFile in @($FLAGS, $LAUNCHER, $PSCommandPath)) {
    Remove-Item -LiteralPath $companionFile -Force -ErrorAction SilentlyContinue
  }
  Cleanup-Ws
  exit
}
function Check-Uninstalled {
  $nowU = Now-Ms
  if ($script:uninstInit -and (($nowU - $script:lastUninstChk) -lt $UNINST_INTERVAL)) {
    return
  }
  $script:uninstInit = $true
  $script:lastUninstChk = $nowU
  try {
    $st = Read-State
    if (Test-AppInstalled) {
      if ($st -and $st.PSObject.Properties[$GONE_KEY] -and ([int]$st.$GONE_KEY -ne 0)) {
        $st.$GONE_KEY = 0
        Save-State $st
      }
      return
    }
    $n = 0
    if ($st -and $st.PSObject.Properties[$GONE_KEY]) {
      $n = [int]$st.$GONE_KEY
    }
    $n++
    Log ($APP_DISPLAY + (" not detected (no process / no uninstall entry / no app paths / no exe) -> strike {0}/{1}" -f $n, $GONE_CONFIRM))
    if ($n -ge $GONE_CONFIRM) {
      Remove-Self
      return
    }
    if (-not $st) {
      $st = [pscustomobject]@{
      }
    }
    if ($st.PSObject.Properties[$GONE_KEY]) {
      $st.$GONE_KEY = $n
    }
    else {
      $st | Add-Member -NotePropertyName $GONE_KEY -NotePropertyValue $n -Force
    }
    Save-State $st
  }
  catch {
  }
}
Check-Uninstalled

Log ("daemon started (PowerShell, no Node), polling DevTools on {0}:{1}" -f $IP,$PORT)
$buf = New-Object byte[] 16384
$seg = [System.ArraySegment[byte]]::new($buf)
$sb = New-Object Text.StringBuilder
$pending = $null
$lastPeriodic = 0
while ($true) {
  try {
    if (-not $script:connected) {
      Connect-Cdp
      Periodic $script:connected
      if (-not $script:connected) {
        Start-Sleep -Milliseconds 1500
      }
      continue
    }
    if (-not $pending) {
      if ($script:ws.State -ne 'Open') {
        Cleanup-Ws
        continue
      }
      $pending = $script:ws.ReceiveAsync($seg, $ct)
    }
    [void][Threading.Tasks.Task]::WaitAny([Threading.Tasks.Task[]]@($pending), 250)
    $nowP = Now-Ms
    if (($nowP - $lastPeriodic) -ge 2000) {
      $lastPeriodic = $nowP
      Periodic $true
    }
    if ($pending.IsCompleted) {
      $r = $null
      try {
        $r = $pending.GetAwaiter().GetResult()
      }
      catch {
        $r = $null
      }
      $pending = $null
      if ($null -eq $r -or $r.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close -or $script:ws.State -ne 'Open') {
        Cleanup-Ws
        continue
      }
      [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $r.Count))
      if ($r.EndOfMessage) {
        $full = $sb.ToString()
        [void]$sb.Clear()
        Handle-Message $full
      }
    }
  }
  catch {
    Log ('loop error: ' + $_.Exception.Message)
    Cleanup-Ws
    Start-Sleep -Milliseconds 1000
  }
}
