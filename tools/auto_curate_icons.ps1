param(
  [string]$Api = 'https://commons.wikimedia.org/w/api.php',
  [string]$ListPath = 'tools/aircraft_list.txt',
  [string]$OutDir = 'objectIcons',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Ensure list exists
if (-not (Test-Path $ListPath)) {
  php tools/list_aircraft.php | Out-File -FilePath $ListPath -Encoding utf8
}

$root = Get-Location
$manifestPath = Join-Path $root 'data/aircraft_icons_manifest.json'
if (Test-Path $manifestPath) {
  $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
} else {
  $manifest = [PSCustomObject]@{ meta = [PSCustomObject]@{ description=''; created=(Get-Date -Format 'yyyy-MM-dd'); notes='' }; aircraft = @() }
}

$lines = Get-Content $ListPath | Where-Object { $_ -and ($_ -notmatch '^Found ') }
$names = @()
foreach ($line in $lines) {
  $parts = $line -split "`t"
  if ($parts.Length -ge 1) { $names += $parts[0].Trim() }
}
$names = $names | Sort-Object -Unique

# Map aircraft names to Wikipedia article titles
# Comprehensive list of all DCS World aircraft (flyable modules and AI units)
$wikiTitleMap = @{
  # A-10 family
  'A-10A Thunderbolt II' = 'Fairchild Republic A-10 Thunderbolt II'
  'A-10C Thunderbolt II' = 'Fairchild Republic A-10 Thunderbolt II'
  'A-10C II Thunderbolt II' = 'Fairchild Republic A-10 Thunderbolt II'
  
  # Other American attack aircraft
  'A-4E Skyhawk' = 'Douglas A-4 Skyhawk'
  'A-4E-C Skyhawk' = 'Douglas A-4 Skyhawk'
  'A-6E Intruder' = 'Grumman A-6 Intruder'
  'A-7E Corsair II' = 'LTV A-7 Corsair II'
  'A-29 Super Tucano' = 'Embraer EMB 314 Super Tucano'
  'AV-8B Harrier II NA' = 'McDonnell Douglas AV-8B Harrier II'
  'AV-8B Harrier II' = 'McDonnell Douglas AV-8B Harrier II'
  
  # Russian/Soviet AWACS
  'A-50 Mainstay' = 'Beriev A-50'
  
  # Saab Viggen
  'AJS 37 Viggen' = 'Saab 37 Viggen'
  'AJ 37 Viggen' = 'Saab 37 Viggen'
  'JA 37 Viggen' = 'Saab 37 Viggen'
  
  # Antonov transports
  'An-26B Curl' = 'Antonov An-26'
  'An-30M Clank' = 'Antonov An-30'
  
  # Bombers
  'B-1B Lancer' = 'Rockwell B-1 Lancer'
  'B-1 Lancer' = 'Rockwell B-1 Lancer'
  'B-52H Stratofortress' = 'Boeing B-52 Stratofortress'
  'B-52 Stratofortress' = 'Boeing B-52 Stratofortress'
  
  # Transports
  'C-17A Globemaster III' = 'Boeing C-17 Globemaster III'
  'C-130 Hercules' = 'Lockheed C-130 Hercules'
  'C-130J Super Hercules' = 'Lockheed Martin C-130J Super Hercules'
  'C-5 Galaxy' = 'Lockheed C-5 Galaxy'
  
  # AWACS
  'E-2C Hawkeye' = 'Grumman E-2 Hawkeye'
  'E-2D Advanced Hawkeye' = 'Grumman E-2 Hawkeye'
  'E-3A Sentry' = 'Boeing E-3 Sentry'
  
  # Fighters - F series
  'F-4E Phantom II' = 'McDonnell Douglas F-4 Phantom II'
  'F-5E Tiger II' = 'Northrop F-5'
  'F-5E-3 Tiger II' = 'Northrop F-5'
  'F-14A Tomcat' = 'Grumman F-14 Tomcat'
  'F-14B Tomcat' = 'Grumman F-14 Tomcat'
  'F-15C Eagle' = 'McDonnell Douglas F-15 Eagle'
  'F-15E Strike Eagle' = 'McDonnell Douglas F-15E Strike Eagle'
  'F-15ESE Strike Eagle' = 'McDonnell Douglas F-15E Strike Eagle'
  'F-16A Fighting Falcon' = 'General Dynamics F-16 Fighting Falcon'
  'F-16C Fighting Falcon' = 'General Dynamics F-16 Fighting Falcon'
  'F-16C Viper' = 'General Dynamics F-16 Fighting Falcon'
  'F-86F Sabre' = 'North American F-86 Sabre'
  'F-104 Starfighter' = 'Lockheed F-104 Starfighter'
  'F-104G Starfighter' = 'Lockheed F-104 Starfighter'
  'F-117A Nighthawk' = 'Lockheed F-117 Nighthawk'
  'F/A-18A Hornet' = 'McDonnell Douglas F/A-18 Hornet'
  'F/A-18C Hornet' = 'McDonnell Douglas F/A-18 Hornet'
  'F/A-18E Super Hornet' = 'Boeing F/A-18E/F Super Hornet'
  'F/A-18F Super Hornet' = 'Boeing F/A-18E/F Super Hornet'
  
  # WWII American fighters
  'F4F Wildcat' = 'Grumman F4F Wildcat'
  'F4U Corsair' = 'Vought F4U Corsair'
  'F4U-1D Corsair' = 'Vought F4U Corsair'
  'F6F Hellcat' = 'Grumman F6F Hellcat'
  'P-40F Warhawk' = 'Curtiss P-40 Warhawk'
  'P-47D Thunderbolt' = 'Republic P-47 Thunderbolt'
  'P-47D-30 Thunderbolt' = 'Republic P-47 Thunderbolt'
  'P-47D-40 Thunderbolt' = 'Republic P-47 Thunderbolt'
  'P-51D Mustang' = 'North American P-51 Mustang'
  'P-51D-25-NA Mustang' = 'North American P-51 Mustang'
  'P-51D-30-NA Mustang' = 'North American P-51 Mustang'
  
  # IL/Ilyushin aircraft
  'IL-76MD' = 'Ilyushin Il-76'
  'IL-78M' = 'Ilyushin Il-78'
  
  # MiG fighters
  'MiG-15bis' = 'Mikoyan-Gurevich MiG-15'
  'MiG-19P Farmer-B' = 'Mikoyan-Gurevich MiG-19'
  'MiG-21bis Fishbed-L/N' = 'Mikoyan-Gurevich MiG-21'
  'MiG-21bis' = 'Mikoyan-Gurevich MiG-21'
  'MiG-23MLD Flogger-K' = 'Mikoyan-Gurevich MiG-23'
  'MiG-25PD Foxbat-E' = 'Mikoyan-Gurevich MiG-25'
  'MiG-27K Flogger-J' = 'Mikoyan-Gurevich MiG-27'
  'MiG-29 Fulcrum' = 'Mikoyan MiG-29'
  'MiG-29A Fulcrum-A' = 'Mikoyan MiG-29'
  'MiG-29G Fulcrum' = 'Mikoyan MiG-29'
  'MiG-29S Fulcrum-C' = 'Mikoyan MiG-29'
  'MiG-31 Foxhound' = 'Mikoyan MiG-31'
  
  # French aircraft
  'Mirage 2000C' = 'Dassault Mirage 2000'
  'Mirage 2000-5' = 'Dassault Mirage 2000'
  'Mirage F1 EE' = 'Dassault Mirage F1'
  'Mirage F1 BE' = 'Dassault Mirage F1'
  'Mirage F1 CE' = 'Dassault Mirage F1'
  'Mirage F1 M-EE' = 'Dassault Mirage F1'
  'Rafale M' = 'Dassault Rafale'
  'Super Etendard' = 'Dassault-Breguet Super Étendard'
  
  # Other fighters
  'JF-17 Thunder' = 'PAC JF-17 Thunder'
  'Tornado IDS' = 'Panavia Tornado'
  'Tornado GR4' = 'Panavia Tornado'
  
  # Chinese aircraft
  'J-11A' = 'Shenyang J-11'
  'Shenyang J-11A' = 'Shenyang J-11'
  'JH-7A' = 'Xian JH-7'
  
  # Sukhoi fighters/attackers
  'Su-17M4 Fitter-K' = 'Sukhoi Su-17'
  'Su-22M4' = 'Sukhoi Su-17'
  'Su-24M Fencer-D' = 'Sukhoi Su-24'
  'Su-24MR Fencer-E' = 'Sukhoi Su-24'
  'Su-25 Frogfoot' = 'Sukhoi Su-25'
  'Su-25T Frogfoot' = 'Sukhoi Su-25'
  'Su-25TM Frogfoot' = 'Sukhoi Su-25'
  'Su-27 Flanker-B' = 'Sukhoi Su-27'
  'Su-27 Flanker' = 'Sukhoi Su-27'
  'Su-30 Flanker-C' = 'Sukhoi Su-27'
  'Su-30M Flanker-C' = 'Sukhoi Su-27'
  'Su-30MK Flanker-C' = 'Sukhoi Su-27'
  'Su-30MKA Flanker-C' = 'Sukhoi Su-27'
  'Su-30MKI Flanker-H' = 'Sukhoi Su-30MKI'
  'Su-30MKM Flanker-C' = 'Sukhoi Su-27'
  'Su-30SM Flanker-H' = 'Sukhoi Su-27'
  'Su-33 Flanker-D' = 'Sukhoi Su-33'
  'Su-34 Fullback' = 'Sukhoi Su-34'
  
  # Bombers - Tupolev
  'Tu-22M3 Backfire-C' = 'Tupolev Tu-22M'
  'Tu-95MS Bear-H' = 'Tupolev Tu-95'
  'Tu-142 Bear-F' = 'Tupolev Tu-142'
  'Tu-160 Blackjack' = 'Tupolev Tu-160'
  
  # Trainer aircraft
  'MB-339 PAN' = 'Aermacchi MB-339'
  'MB-339A' = 'Aermacchi MB-339'
  'L-39C Albatros' = 'Aero L-39 Albatros'
  'L-39ZA Albatros' = 'Aero L-39 Albatros'
  'T-45C Goshawk' = 'McDonnell Douglas T-45 Goshawk'
  
  # Tankers
  'KC-135 Stratotanker' = 'Boeing KC-135 Stratotanker'
  'KC-135BDA Stratotanker' = 'Boeing KC-135 Stratotanker'
  'KC-10A Extender' = 'McDonnell Douglas KC-10 Extender'
  
  # Drones/UAVs
  'MQ-9 Reaper' = 'General Atomics MQ-9 Reaper'
  'RQ-1A Predator' = 'General Atomics MQ-1 Predator'
  
  # WWII German aircraft
  'Bf 109 K-4' = 'Messerschmitt Bf 109'
  'Fw 190 A-8' = 'Focke-Wulf Fw 190'
  'Fw 190 D-9' = 'Focke-Wulf Fw 190'
  
  # WWII British aircraft
  'Spitfire LF Mk. IX' = 'Supermarine Spitfire'
  'Mosquito FB VI' = 'de Havilland Mosquito'
  
  # WWII Japanese aircraft
  'A6M5 Zero' = 'Mitsubishi A6M Zero'
  'Ki-61-I Hien' = 'Kawasaki Ki-61'
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

function Set-Prop($obj, [string]$name, $value) {
  $p = $obj.PSObject.Properties[$name]
  if ($null -ne $p) { $obj.$name = $value }
  else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

function Get-WikipediaMainImage($articleTitle) {
  # Get the main infobox image from Wikipedia using pageimages API
  $wikiApi = 'https://en.wikipedia.org/w/api.php'
  $params = @{
    action = 'query'
    format = 'json'
    titles = $articleTitle
    prop = 'pageimages'
    pithumbsize = 1280
  }
  $uri = "$($wikiApi)?$(($params.GetEnumerator() | ForEach-Object { '{0}={1}' -f [System.Web.HttpUtility]::UrlEncode($_.Key), [System.Web.HttpUtility]::UrlEncode([string]$_.Value) }) -join '&')"
  try {
    $json = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent'='php-tacview/1.0' } -TimeoutSec 30
  } catch {
    return $null
  }
  if (-not $json.query.pages) { return $null }
  $page = $json.query.pages.PSObject.Properties.Value | Select-Object -First 1
  if ($page.PSObject.Properties['missing'] -or (-not $page.PSObject.Properties['thumbnail'])) { return $null }
  
  $thumb = $page.thumbnail.source
  # Get full-size URL by manipulating thumbnail URL
  $fullUrl = $thumb -replace '/thumb/', '/' -replace '/\d+px-[^/]+$', ''
  
  return [PSCustomObject]@{
    Title = $page.title
    Thumb = $thumb
    Url   = $fullUrl
    Desc  = "https://en.wikipedia.org/wiki/$([System.Web.HttpUtility]::UrlEncode($page.title))"
    Meta  = $null
  }
}

$ok = 0; $fail = 0
foreach ($name in $names) {
  $base = ($name -replace '[ /]', '_')
  $jpgPath = Join-Path $OutDir ($base + '.jpg')
  $pngPath = Join-Path $OutDir ($base + '.png')
  if ( ((Test-Path $jpgPath) -or (Test-Path $pngPath)) -and (-not $Force) ) {
    $existing = if (Test-Path $jpgPath) { (Split-Path $jpgPath -Leaf) } else { (Split-Path $pngPath -Leaf) }
    Write-Host "SKIP`t$name`t$existing (exists)" -ForegroundColor Yellow
    continue
  }
  # Look up the Wikipedia article title
  $wikiTitle = if ($wikiTitleMap.ContainsKey($name)) { $wikiTitleMap[$name] } else { $name }
  
  # Try Wikipedia article first
  $res = Get-WikipediaMainImage $wikiTitle
  if (-not $res) {
    # Try with " (aircraft)" suffix for disambiguation
    $res = Get-WikipediaMainImage "$wikiTitle (aircraft)"
  }
  if (-not $res -or -not $res.Url) {
    Write-Host "MISS`t$name" -ForegroundColor Red
    $fail++
    continue
  }
  $src = $res.Thumb
  if (-not $src) { $src = $res.Url }
  $ext = if ($src -match '\.png($|\?)') { 'png' } elseif ($src -match '\.jpe?g($|\?)') { 'jpg' } else { 'jpg' }
  $target = "$base.$ext"
  $dst = Join-Path $OutDir $target
  try {
    Invoke-WebRequest -Uri $src -Headers @{ 'User-Agent'='php-tacview/1.0' } -OutFile $dst -TimeoutSec 60
    Write-Host "OK`t$name`t$target" -ForegroundColor Green
    $ok++
    # Update manifest entry
    $entry = $manifest.aircraft | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $entry) {
      $entry = [PSCustomObject]@{ name=$name; targetFilename=$target }
      $manifest.aircraft += $entry
    }
    Set-Prop $entry 'targetFilename' $target
  Set-Prop $entry 'fileUrl' $res.Url
  Set-Prop $entry 'descriptionPage' $res.Desc
  $meta = $res.Meta
  $lic = $null
  if ($meta -and $meta.PSObject.Properties['LicenseShortName']) { $lic = $meta.LicenseShortName.value }
  if (-not $lic -and $meta -and $meta.PSObject.Properties['UsageTerms']) { $lic = $meta.UsageTerms.value }
  if ($lic) { Set-Prop $entry 'license' $lic }
  $attr = $null
  if ($meta -and $meta.PSObject.Properties['Artist']) { $attr = $meta.Artist.value }
  if (-not $attr -and $meta -and $meta.PSObject.Properties['Credit']) { $attr = $meta.Credit.value }
  if ($attr) { Set-Prop $entry 'attribution' $attr }
  } catch {
    Write-Host "DLFAIL`t$name`t$src`t$($_.Exception.Message)" -ForegroundColor Red
    $fail++
  }
}

$manifest | ConvertTo-Json -Depth 6 | Out-File -FilePath $manifestPath -Encoding utf8

Write-Host "`nCompleted. OK=$ok FAIL=$fail" -ForegroundColor Cyan
