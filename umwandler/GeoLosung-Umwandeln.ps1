# GeoLosung-Umwandeln.ps1
# Wandelt W32LOS-Losungsdateien (de_losJJ.xml) in GeoLosung-Datendateien
# (GLOSjjjj.DAT) fuer GeoWorks 1 um.
#
#  - Zeichensatz der Ausgabe: GEOS-Zeichensatz (Umlaute, ss, typografische
#    Anfuehrungszeichen und Gedankenstriche bleiben erhalten)
#  - Zeilenumbrueche der Vorlage werden entfernt, GeoLosung bricht selbst um
#  - Sonn- und Feiertagsnamen werden aus dem Kalender berechnet
#
# Aufruf (Beispiele):
#   powershell -ExecutionPolicy Bypass -File GeoLosung-Umwandeln.ps1
#       -> alle de_los*.xml im Ordner des Skripts (sonst aus C:\Program Files (x86)\w32los)
#   powershell -ExecutionPolicy Bypass -File GeoLosung-Umwandeln.ps1 -Quelle "C:\Program Files (x86)\w32los\de_los27.xml" -Ziel C:\GEOWORKS\DOCUMENT
#   ... -AsciiAnfuehrungszeichen   (ersetzt ' " - Zeichen durch einfache ASCII-Zeichen)
#
# Die Datei ist bewusst reines ASCII, damit Windows PowerShell 5.1 sie
# unabhaengig von der Codepage richtig liest.

param(
    [string[]]$Quelle,
    [string]$Ziel,
    [switch]$AsciiAnfuehrungszeichen
)

$ErrorActionPreference = 'Stop'
$skriptOrdner = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Quelle) {
    $Quelle = @($skriptOrdner)
    $pf = ${env:ProgramFiles(x86)}
    if (-not $pf) { $pf = $env:ProgramFiles }
    $w32los = Join-Path $pf 'w32los'
    if (-not (Get-ChildItem -LiteralPath $skriptOrdner -Filter 'de_los*.xml') -and (Test-Path -LiteralPath $w32los)) {
        $Quelle = @($w32los)
    }
}
if (-not $Ziel)   { $Ziel = $skriptOrdner }

# ---------------------------------------------------------------- Zeichensatz
# Unicode-Werte der GEOS-Zeichen 0x80..0xFF (FreeGEOS Include/char.def)
$geosHigh = @(
 0xC4,0xC5,0xC7,0xC9,0xD1,0xD6,0xDC,0xE1,0xE0,0xE2,0xE4,0xE3,0xE5,0xE7,0xE9,0xE8,
 0xEA,0xEB,0xED,0xEC,0xEE,0xEF,0xF1,0xF3,0xF2,0xF4,0xF6,0xF5,0xFA,0xF9,0xFB,0xFC,
 0x2020,0xB0,0xA2,0xA3,0xA7,0x2022,0xB6,0xDF,0xAE,0xA9,0x2122,0xB4,0xA8,0x2260,0xC6,0xD8,
 0x221E,0xB1,0x2264,0x2265,0xA5,0xB5,0x2202,0x2211,0x220F,0x3C0,0x222B,0xAA,0xBA,0x3A9,0xE6,0xF8,
 0xBF,0xA1,0xAC,0x221A,0x192,0x2248,0x2206,0xAB,0xBB,0x2026,0xA0,0xC0,0xC3,0xD5,0x152,0x153,
 0x2013,0x2014,0x201C,0x201D,0x2018,0x2019,0xF7,0x25CA,0xFF,0x178,0x2044,0xA4,0x2039,0x203A,0xDD,0xFD,
 0x2021,0xB7,0x201A,0x201E,0x2030,0xC2,0xCA,0xC1,0xCB,0xC8,0xCD,0xCE,0xCF,0xCC,0xD3,0xD4,
 0,0xD2,0xDA,0xDB,0xD9,0x131,0x2C6,0x2DC,0xAF,0x2D8,0x2D9,0x2DA,0xB8,0x2DD,0x2DB,0x2C7)
$u2g = @{}
for ($i = 0; $i -lt 128; $i++) { if ($geosHigh[$i] -ne 0) { $u2g[[int]$geosHigh[$i]] = 0x80 + $i } }
$fallback = @{ 0x20AC = 'EUR'; 0x2012 = '-'; 0x2015 = '-'; 0x2212 = '-'; 0x2032 = "'"; 0x2033 = '"' }
$script:unbekannt = 0

function ConvertTo-Geos([string]$s, [System.Collections.Generic.List[byte]]$out) {
    foreach ($ch in $s.ToCharArray()) {
        $c = [int]$ch
        if ($AsciiAnfuehrungszeichen) {
            if ($c -eq 0x2018 -or $c -eq 0x2019 -or $c -eq 0x201A) { $c = 0x27 }
            elseif ($c -eq 0x201C -or $c -eq 0x201D -or $c -eq 0x201E -or $c -eq 0xAB -or $c -eq 0xBB) { $c = 0x22 }
        }
        if ($c -ge 0x20 -and $c -lt 0x7F) { $out.Add([byte]$c) }
        elseif ($u2g.ContainsKey($c)) { $out.Add([byte]$u2g[$c]) }
        elseif ($fallback.ContainsKey($c)) { foreach ($b in [Text.Encoding]::ASCII.GetBytes($fallback[$c])) { $out.Add($b) } }
        elseif ($c -eq 9) { $out.Add([byte]0x20) }
        else { $out.Add([byte]0x3F); $script:unbekannt++ }
    }
}

# ---------------------------------------------------------------- Kalender
$ae = [char]0xE4; $oe = [char]0xF6; $ue = [char]0xFC; $sz = [char]0xDF

function Get-Ostern([int]$y) {
    $a = $y % 19; $b = [math]::Floor($y / 100); $c = $y % 100
    $d = [math]::Floor($b / 4); $e = $b % 4; $f = [math]::Floor(($b + 8) / 25)
    $g = [math]::Floor(($b - $f + 1) / 3)
    $h = (19 * $a + $b - $d - $g + 15) % 30
    $i = [math]::Floor($c / 4); $k = $c % 4
    $l = (32 + 2 * $e + 2 * $i - $h - $k) % 7
    $m = [math]::Floor(($a + 11 * $h + 22 * $l) / 451)
    $mo = [math]::Floor(($h + $l - 7 * $m + 114) / 31)
    $da = (($h + $l - 7 * $m + 114) % 31) + 1
    return New-Object DateTime ([int]$y), ([int]$mo), ([int]$da)
}

function Get-Feiertage([int]$y) {
    $r = @{}
    $E = Get-Ostern $y
    $put = { param($d, $s) if ($d.Year -eq $y) { $r[$d.ToString('MMdd')] = $s } }
    $sonntag = [DayOfWeek]::Sunday

    for ($t = 2; $t -le 5; $t++) {
        $d = New-Object DateTime $y, 1, $t
        if ($d.DayOfWeek -eq $sonntag) { & $put $d '2. Sonntag nach Weihnachten' }
    }
    for ($t = 27; $t -le 31; $t++) {
        $d = New-Object DateTime $y, 12, $t
        if ($d.DayOfWeek -eq $sonntag) { & $put $d '1. Sonntag nach Weihnachten' }
    }
    $lichtmess = New-Object DateTime $y, 2, 2
    if ($E.AddDays(-70) -gt $lichtmess) {
        $letzter = $E.AddDays(-77)
    } else {
        $letzter = $lichtmess
        while ($letzter.DayOfWeek -ne $sonntag) { $letzter = $letzter.AddDays(-1) }
        while ($letzter -ge $E.AddDays(-49)) { $letzter = $letzter.AddDays(-7) }
    }
    $d = New-Object DateTime $y, 1, 7
    while ($d.DayOfWeek -ne $sonntag) { $d = $d.AddDays(1) }
    $n = 0
    while ($d -lt $letzter) { $n++; & $put $d "$n. Sonntag nach Epiphanias"; $d = $d.AddDays(7) }
    & $put $letzter 'Letzter Sonntag nach Epiphanias'
    foreach ($p in @(@(-70, '4. Sonntag vor der Passionszeit'),
                     @(-63, '3. Sonntag vor der Passionszeit - Septuagesimae'),
                     @(-56, '2. Sonntag vor der Passionszeit - Sexagesimae'))) {
        if ($E.AddDays($p[0]) -gt $letzter) { & $put $E.AddDays($p[0]) $p[1] }
    }
    $passion = @(
        @(-49, 'Sonntag vor der Passionszeit - Estomihi (Sei mir ein starker Fels! Psalm 31,3)'),
        @(-42, "1. Sonntag der Passionszeit - Invokavit (Er ruft mich an, darum will ich ihn erh$($oe)ren. Psalm 91,15)"),
        @(-35, '2. Sonntag der Passionszeit - Reminiszere (Gedenke, HERR, an deine Barmherzigkeit! Psalm 25,6)'),
        @(-28, '3. Sonntag der Passionszeit - Okuli (Meine Augen sehen stets auf den HERRN. Psalm 25,15)'),
        @(-21, "4. Sonntag der Passionszeit - L$($ae)tare (Freuet euch mit Jerusalem! Jesaja 66,10)"),
        @(-14, '5. Sonntag der Passionszeit - Judika (Schaffe mir Recht, Gott! Psalm 43,1)'),
        @(-7,  '6. Sonntag der Passionszeit - Palmsonntag'),
        @(-3,  "Gr$($ue)ndonnerstag"), @(-2, 'Karfreitag'), @(0, 'Osterfest'), @(1, 'Ostermontag'),
        @(7,   '1. Sonntag nach Ostern - Quasimodogeniti (Wie die neugeborenen Kindlein. 1. Petrus 2,2)'),
        @(14,  "2. Sonntag nach Ostern - Miserikordias Domini (Die Erde ist voll der G$($ue)te des HERRN. Psalm 33,5)"),
        @(21,  '3. Sonntag nach Ostern - Jubilate (Jauchzet Gott, alle Lande! Psalm 66,1)'),
        @(28,  '4. Sonntag nach Ostern - Kantate (Singet dem HERRN ein neues Lied! Psalm 98,1)'),
        @(35,  '5. Sonntag nach Ostern - Rogate (Betet!)'),
        @(39,  'Christi Himmelfahrt'),
        @(42,  "6. Sonntag nach Ostern - Exaudi (HERR, h$($oe)re meine Stimme! Psalm 27,7)"),
        @(49,  'Pfingstfest'), @(50, 'Pfingstmontag'), @(56, 'Trinitatis (Dreieinigkeit)'))
    foreach ($p in $passion) { & $put $E.AddDays($p[0]) $p[1] }

    $a1 = New-Object DateTime $y, 11, 27
    while ($a1.DayOfWeek -ne $sonntag) { $a1 = $a1.AddDays(1) }
    for ($k = 0; $k -lt 4; $k++) { & $put $a1.AddDays(7 * $k) "$($k + 1). Sonntag im Advent" }
    & $put $a1.AddDays(-7)  'Letzter Sonntag des Kirchenjahres - Ewigkeitssonntag'
    & $put $a1.AddDays(-14) 'Vorletzter Sonntag des Kirchenjahres'
    & $put $a1.AddDays(-21) 'Drittletzter Sonntag des Kirchenjahres'
    & $put $a1.AddDays(-11) "Bu$($sz)- und Bettag"
    $d = $E.AddDays(63); $k = 1
    while ($d -lt $a1.AddDays(-21)) {
        $s = "$k. Sonntag nach Trinitatis"
        if ($k -eq 10) { $s += ' (Israelsonntag)' }
        & $put $d $s
        $d = $d.AddDays(7); $k++
    }
    $ed = New-Object DateTime $y, 10, 1
    while ($ed.DayOfWeek -ne $sonntag) { $ed = $ed.AddDays(1) }
    & $put $ed 'Erntedankfest'

    $fest = @(@('0101','Neujahr'), @('0106','Epiphanias'), @('0624','Johannistag'),
              @('0929','Michaelistag'), @('1031','Reformationstag'), @('1224','Heiliger Abend'),
              @('1225','Weihnachtsfest'), @('1226','2. Weihnachtstag'), @('1231','Altjahrsabend'))
    foreach ($f in $fest) {
        if ($f[0] -eq '1224' -and $r.ContainsKey('1224')) { $r['1224'] = $r['1224'] + ' - ' + $f[1] }
        else { $r[$f[0]] = $f[1] }
    }
    $nik = New-Object DateTime $y, 12, 6
    if ($nik.DayOfWeek -ne $sonntag) { $r['1206'] = 'Nikolaustag' }
    return $r
}

# ---------------------------------------------------------------- Texte
function Clean([string]$s) {
    if ($null -eq $s) { return '' }
    return ([regex]::Replace($s, '\s+', ' ')).Trim()
}

function Gesperrt([string]$s) {
    return [regex]::Replace($s, '#([^#]+)#', { param($m) ($m.Groups[1].Value.ToCharArray() -join ' ') })
}

function Get-Teil($el) {
    $intro = ''
    $il = $el.SelectSingleNode('IL')
    if ($null -ne $il) { $intro = Clean $il.InnerText }
    $zeilen = @()
    foreach ($l in $el.SelectNodes('L')) { $zeilen += (Clean $l.InnerText) }
    $text = Clean ($zeilen -join ' ')
    $m = [regex]::Match($text, '^/([^/]+)/\s*(.*)$')
    if ($m.Success -and $intro -eq '') { $intro = Clean $m.Groups[1].Value; $text = $m.Groups[2].Value }
    $sl = $el.SelectSingleNode('SL')
    $stelle = ''
    if ($null -ne $sl) { $stelle = Clean $sl.InnerText }
    return @($intro, (Gesperrt $text), $stelle)
}

function Convert-Losung([string]$pfad) {
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($pfad, $settings)
    try { $doc = New-Object System.Xml.XmlDocument; $doc.Load($reader) } finally { $reader.Close() }
    $root = $doc.DocumentElement
    $jahr = [int]$root.GetAttribute('year')
    $fe = Get-Feiertage $jahr

    $zeilen = New-Object System.Collections.Generic.List[string]
    $zeilen.Add('GEOLOSUNG 1'); $zeilen.Add("JAHR $jahr"); $zeilen.Add('QUELLE ' + [IO.Path]::GetFileName($pfad))
    $anzahl = 0
    $praefix = "Losung f$($ue)r"
    foreach ($los in $root.SelectNodes('LOSUNG')) {
        $d = [int]$los.GetAttribute('d'); $m = [int]$los.GetAttribute('m')
        $schluessel = '{0:00}{1:00}' -f $m, $d
        $titel = ''
        $tl = $los.SelectSingleNode('TL')
        if ($null -ne $tl) { $titel = Clean $tl.InnerText }
        if ($titel.StartsWith($praefix, [StringComparison]::Ordinal)) { $titel = $titel.Substring($praefix.Length).TrimStart() }
        $zeilen.Add("[$schluessel]")
        $zeilen.Add("T=$titel")
        if ($fe.ContainsKey($schluessel)) { $zeilen.Add('F=' + $fe[$schluessel]) }
        foreach ($p in @(@('A', 'OT'), @('N', 'NT'))) {
            $teil = Get-Teil ($los.SelectSingleNode($p[1]))
            if ($teil[0] -ne '') { $zeilen.Add($p[0] + 'E=' + $teil[0]) }
            $zeilen.Add($p[0] + 'T=' + $teil[1])
            $zeilen.Add($p[0] + 'S=' + $teil[2])
        }
        $anzahl++
    }
    $zeilen.Add('[ENDE]')

    $bytes = New-Object System.Collections.Generic.List[byte]
    foreach ($z in $zeilen) { ConvertTo-Geos $z $bytes; $bytes.Add(13); $bytes.Add(10) }
    $ausgabe = Join-Path $Ziel ("GLOS{0}.DAT" -f $jahr)
    $arr = $bytes.ToArray()
    [IO.File]::WriteAllBytes($ausgabe, $arr)
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = (($sha.ComputeHash($arr) | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16)
    $soll = 365; if ([DateTime]::IsLeapYear($jahr)) { $soll = 366 }
    $farbe = 'Green'; if ($anzahl -ne $soll) { $farbe = 'Yellow' }
    Write-Host ("{0}: {1} Tage (erwartet {2}), {3} Bytes, Pruefsumme {4}" -f [IO.Path]::GetFileName($ausgabe), $anzahl, $soll, $arr.Length, $hash) -ForegroundColor $farbe
}

# ---------------------------------------------------------------- Hauptteil
if (-not (Test-Path -LiteralPath $Ziel)) { New-Item -ItemType Directory -Path $Ziel | Out-Null }
$Ziel = (Resolve-Path -LiteralPath $Ziel).Path
$dateien = @()
foreach ($q in $Quelle) {
    if (Test-Path -LiteralPath $q -PathType Container) {
        $dateien += Get-ChildItem -LiteralPath $q -Filter 'de_los*.xml' | Sort-Object Name | ForEach-Object { $_.FullName }
    } else { $dateien += (Resolve-Path -LiteralPath $q).Path }
}
if ($dateien.Count -eq 0) { Write-Host 'Keine de_los*.xml gefunden.' -ForegroundColor Red; exit 2 }
foreach ($f in $dateien) {
    try { Convert-Losung $f }
    catch { Write-Host ("Fehler bei {0}: {1}" -f $f, $_.Exception.Message) -ForegroundColor Red }
}
if ($script:unbekannt -gt 0) {
    Write-Host ("Hinweis: {0} Zeichen ohne GEOS-Entsprechung wurden durch ? ersetzt." -f $script:unbekannt) -ForegroundColor Yellow
}
Write-Host ("Fertig. Ausgabeordner: {0}" -f $Ziel)
