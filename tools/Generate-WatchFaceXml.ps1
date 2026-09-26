# Generates watchface/src/main/res/raw/watchface.xml for the Circle of Fifths face (WFF v5).
# Canvas is 450x450, centre (225,225). Angles: 0 = 12 o'clock, clockwise.
# The dial runs in FOURTHS clockwise (C, F, Bb, Eb ...), the user's preferred reading.
$ErrorActionPreference = "Stop"
$inv = [cultureinfo]::InvariantCulture
function F([double]$v) { $v.ToString("0.##", $inv) }
function PX([double]$r, [double]$deg) { F (225 + $r * [math]::Sin($deg * [math]::PI / 180)) }
function PY([double]$r, [double]$deg) { F (225 - $r * [math]::Cos($deg * [math]::PI / 180)) }

# Theme colour indices (see ColorConfiguration below)
$MAJOR  = "[CONFIGURATION.themeColor.0]"
$MINOR  = "[CONFIGURATION.themeColor.1]"
$ACCENT = "[CONFIGURATION.themeColor.2]"
$HANDS  = "[CONFIGURATION.themeColor.3]"
$LINES  = "[CONFIGURATION.themeColor.4]"

$FONT_BOLD   = "libre_baskerville_bold"
$FONT_REG    = "libre_baskerville_regular"
$FONT_ITALIC = "libre_baskerville_italic"

# ---------------------------------------------------------------------------
# Music theory: spell every key and its relative modes correctly.
# ---------------------------------------------------------------------------
$LETTERS   = @("C","D","E","F","G","A","B")
$NATURAL   = @(0, 2, 4, 5, 7, 9, 11)          # pitch class of each natural letter
$INTERVALS = @(0, 2, 4, 5, 7, 9, 11)          # major scale degrees

# Outer ring, clockwise from 12 o'clock. Positions 5, 6 and 7 carry both enharmonic spellings.
# Each entry is parsed into a list of (letterIndex, accidental) pairs; "b" = flat, "#" = sharp.
$OUTER_NAMES = @("C","F","Bb","Eb","Ab","Db/C#","Gb/F#","B/Cb","E","A","D","G")
function ParseKey([string]$name) {
  $list = New-Object System.Collections.Generic.List[object]
  foreach ($s in $name.Split("/")) {
    $letter = [array]::IndexOf($LETTERS, $s.Substring(0, 1))
    $acc = 0
    if ($s.Length -gt 1) { $acc = if ($s[1] -eq "#") { 1 } else { -1 } }
    $list.Add(@($letter, $acc))
  }
  return ,$list   # unary comma stops PowerShell unrolling the list
}
$OUTER = @($OUTER_NAMES | ForEach-Object { ,(ParseKey $_) })

# Modes: id, display degree (0-based scale degree of the mode's tonic), lowercase?
$MODES = @(
  @{ id = "aeolian";    degree = 5; lower = $true  }
  @{ id = "dorian";     degree = 1; lower = $true  }
  @{ id = "phrygian";   degree = 2; lower = $true  }
  @{ id = "lydian";     degree = 3; lower = $false }
  @{ id = "mixolydian"; degree = 4; lower = $false }
  @{ id = "locrian";    degree = 6; lower = $true  }
)

function ModeTonic([int]$letter, [int]$acc, [int]$degree) {
  $L  = ($letter + $degree) % 7
  $pc = (($NATURAL[$letter] + $acc + $INTERVALS[$degree]) % 12 + 12) % 12
  $a  = $pc - $NATURAL[$L]
  if ($a -gt 6)  { $a -= 12 }
  if ($a -lt -6) { $a += 12 }
  return @($L, $a)
}

# ---------------------------------------------------------------------------
# Label rendering: letters in Libre Baskerville, accidentals as inline images
# rendered from Bravura Text (see Generate-Assets.ps1) so any theme can tint them.
# ---------------------------------------------------------------------------
function AccidentalXml([int]$acc, [double]$size, $color) {
  if ($acc -eq 0) { return "" }
  $h = [math]::Round($size * 0.78)
  if ($acc -gt 0) { $res = "acc_sharp"; $w = [math]::Round($h * 130 / 364) }
  else            { $res = "acc_flat";  $w = [math]::Round($h * 136 / 369) }
  return "<InlineImage resource=""$res"" width=""$w"" height=""$h"" color=""$color""/>"
}

function SpellingXml($spelling, [bool]$lower, [double]$size, $color) {
  $letter = $LETTERS[$spelling[0]]
  if ($lower) { $letter = $letter.ToLower() }
  return $letter + (AccidentalXml $spelling[1] $size $color)
}

function LabelXml($spellings, [bool]$lower, [double]$size, $color) {
  ($spellings | ForEach-Object { SpellingXml $_ $lower $size $color }) -join "/"
}

function LabelPartText([int]$pos, [double]$r, [int]$w, [int]$h, [string]$family, [double]$size, $color, [string]$inner, [string]$partExtra = "") {
  $a  = $pos * 30
  $cx = 225 + $r * [math]::Sin($a * [math]::PI / 180)
  $cy = 225 - $r * [math]::Cos($a * [math]::PI / 180)
  $x = [int][math]::Round($cx - $w / 2); $y = [int][math]::Round($cy - $h / 2)
  $extraLine = if ($partExtra) { "`n$partExtra" } else { "" }
  return @"
      <PartText x="$x" y="$y" width="$w" height="$h">$extraLine
        <Text align="CENTER" verticalAlign="CENTER" isAutoSize="TRUE"><Font family="$family" size="$(F $size)" minSize="12" color="$color">$inner</Font></Text>
      </PartText>
"@
}

# Outer ring: major keys
$majorXml = New-Object System.Text.StringBuilder
for ($i = 0; $i -lt 12; $i++) {
  $sp = $OUTER[$i]
  $size = if ($sp.Count -gt 1) { 25 } else { 31 }
  [void]$majorXml.Append((LabelPartText $i 184 96 38 $FONT_BOLD $size $MAJOR (LabelXml $sp $false $size $MAJOR)))
}

# Inner ring: one Group per mode, swapped by the innerRing setting
function ModeGroupXml($mode, [string]$suffix = "", [string]$partExtra = "") {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("        <Group x=""0"" y=""0"" width=""450"" height=""450"" name=""inner_$($mode.id)$suffix"">")
  for ($i = 0; $i -lt 12; $i++) {
    $tonics = New-Object System.Collections.Generic.List[object]
    foreach ($sp in $OUTER[$i]) { $tonics.Add((ModeTonic $sp[0] $sp[1] $mode.degree)) }
    $size = if ($tonics.Count -gt 1) { 17 } else { 21 }
    [void]$sb.Append((LabelPartText $i 143 76 28 $FONT_ITALIC $size $MINOR (LabelXml $tonics $mode.lower $size $MINOR) $partExtra))
  }
  # Mode name under the hub
  [void]$sb.AppendLine("      <PartText x=""165"" y=""247"" width=""120"" height=""18"">")
  if ($partExtra) { [void]$sb.AppendLine($partExtra) }
  [void]$sb.AppendLine("        <Text align=""CENTER"" verticalAlign=""CENTER""><Font family=""$FONT_ITALIC"" size=""13"" color=""$MINOR"">mode_$($mode.id)</Font></Text>")
  [void]$sb.AppendLine("      </PartText>")
  [void]$sb.AppendLine("        </Group>")
  return $sb.ToString().TrimEnd()
}
$modeOptions = New-Object System.Text.StringBuilder

# "Cycle modes hourly": the mode follows the hour of day in brightness order (each step adds a
# flat), switching at the top of every hour. Stateless: hour mod 6 picks the mode, applied as an
# alpha transform on every text element of each mode group.
# This lives under a BooleanConfiguration, not a ListOption: on the Galaxy Watch anything inside a
# ListOption is evaluated once at load (against the preview time) and never refreshed, whereas
# content under a BooleanOption stays live (the key highlight relies on the same behaviour).
$CYCLE_ORDER = @("lydian", "mixolydian", "dorian", "aeolian", "phrygian", "locrian")
$cycleGroups = New-Object System.Text.StringBuilder
for ($k = 0; $k -lt $CYCLE_ORDER.Count; $k++) {
  $m = $MODES | Where-Object { $_.id -eq $CYCLE_ORDER[$k] }
  $alpha = "        <Transform target=""alpha"" value=""255 * (1 - clamp(abs(([HOUR_0_23] % 6) - $k), 0, 1))""/>"
  [void]$cycleGroups.AppendLine((ModeGroupXml $m "_cycle$k" $alpha))
}

foreach ($m in $MODES) {
  [void]$modeOptions.AppendLine("      <ListOption id=""$($m.id)"">")
  [void]$modeOptions.AppendLine((ModeGroupXml $m))
  [void]$modeOptions.AppendLine("      </ListOption>")
}
[void]$modeOptions.AppendLine("      <ListOption id=""none"">")
[void]$modeOptions.AppendLine("        <Group x=""0"" y=""0"" width=""450"" height=""450"" name=""inner_none""/>")
[void]$modeOptions.AppendLine("      </ListOption>")

# ---- ticks: 60 minute ticks, every 5th is an hour tick ----
$ticks = New-Object System.Text.StringBuilder
for ($k = 0; $k -lt 60; $k++) {
  $a = $k * 6
  if ($k % 5 -eq 0) { $r1 = 206; $th = 3 } else { $r1 = 214; $th = 1.5 }
  [void]$ticks.AppendLine("        <Line startX=""$(PX $r1 $a)"" startY=""$(PY $r1 $a)"" endX=""$(PX 222 $a)"" endY=""$(PY 222 $a)""><Stroke color=""$LINES"" thickness=""$th"" cap=""BUTT""/></Line>")
}
# ---- spokes between the 12 segments ----
$spokes = New-Object System.Text.StringBuilder
for ($k = 0; $k -lt 12; $k++) {
  $a = 15 + $k * 30
  [void]$spokes.AppendLine("        <Line startX=""$(PX 120 $a)"" startY=""$(PY 120 $a)"" endX=""$(PX 203 $a)"" endY=""$(PY 203 $a)""><Stroke color=""$LINES"" thickness=""1"" cap=""BUTT""/></Line>")
}

# ---- complication text helper ----
function CompText([int]$x, [int]$y, [int]$w, [int]$h, [double]$size, $color) {
@"
            <PartText x="$x" y="$y" width="$w" height="$h">
              <Text align="CENTER" verticalAlign="CENTER" isAutoSize="TRUE" ellipsis="TRUE"><Font family="$FONT_REG" size="$size" minSize="11" color="$color"><Template><![CDATA[%s]]><Parameter expression="[COMPLICATION.TEXT]"/></Template></Font></Text>
            </PartText>
"@
}

# ---- complication slot renderer (64x64, coordinates relative to the slot) ----
function Slot($id, $name, $displayName, $x, $y, $policy) {
@"
    <ComplicationSlot x="$x" y="$y" width="64" height="64" slotId="$id" name="$name" displayName="$displayName" supportedTypes="SHORT_TEXT RANGED_VALUE MONOCHROMATIC_IMAGE SMALL_IMAGE EMPTY" isCustomizable="TRUE">
      $policy
      <BoundingOval x="0" y="0" width="64" height="64" outlinePadding="2"/>
      <Complication type="SHORT_TEXT">
        <Condition>
          <Expressions>
            <Expression name="hasIcon"><![CDATA[[COMPLICATION.MONOCHROMATIC_IMAGE] != null]]></Expression>
          </Expressions>
          <Compare expression="hasIcon">
            <PartImage x="22" y="6" width="20" height="20" tintColor="$MINOR">
              <Image resource="[COMPLICATION.MONOCHROMATIC_IMAGE]"/>
            </PartImage>
$(CompText 2 28 60 26 18 $MINOR)
          </Compare>
          <Default>
$(CompText 2 18 60 28 20 $MINOR)
          </Default>
        </Condition>
      </Complication>
      <Complication type="RANGED_VALUE">
        <PartDraw x="0" y="0" width="64" height="64">
          <Arc centerX="32" centerY="32" width="56" height="56" startAngle="-135" endAngle="135">
            <Stroke color="$LINES" thickness="3" cap="ROUND"/>
          </Arc>
          <Arc centerX="32" centerY="32" width="56" height="56" startAngle="-135" endAngle="135">
            <Stroke color="$ACCENT" thickness="3" cap="ROUND"/>
            <Transform target="endAngle" value="-135 + ((clamp([COMPLICATION.RANGED_VALUE_VALUE], [COMPLICATION.RANGED_VALUE_MIN], [COMPLICATION.RANGED_VALUE_MAX]) - [COMPLICATION.RANGED_VALUE_MIN]) / ([COMPLICATION.RANGED_VALUE_MAX] - [COMPLICATION.RANGED_VALUE_MIN])) * 270"/>
          </Arc>
        </PartDraw>
        <Condition>
          <Expressions>
            <Expression name="hasIcon"><![CDATA[[COMPLICATION.MONOCHROMATIC_IMAGE] != null]]></Expression>
          </Expressions>
          <Compare expression="hasIcon">
            <PartImage x="24" y="12" width="16" height="16" tintColor="$MINOR">
              <Image resource="[COMPLICATION.MONOCHROMATIC_IMAGE]"/>
            </PartImage>
$(CompText 8 29 48 22 15 $MINOR)
          </Compare>
          <Default>
$(CompText 8 20 48 24 16 $MINOR)
          </Default>
        </Condition>
      </Complication>
      <Complication type="MONOCHROMATIC_IMAGE">
        <PartImage x="16" y="16" width="32" height="32" tintColor="$MINOR">
          <Image resource="[COMPLICATION.MONOCHROMATIC_IMAGE]"/>
        </PartImage>
      </Complication>
      <Complication type="SMALL_IMAGE">
        <PartImage x="12" y="12" width="40" height="40">
          <Image resource="[COMPLICATION.SMALL_IMAGE]"/>
        </PartImage>
      </Complication>
    </ComplicationSlot>
"@
}
$batteryPolicy   = '<DefaultProviderPolicy defaultSystemProvider="WATCH_BATTERY" defaultSystemProviderType="RANGED_VALUE"/>'
# Samsung's Stopwatch app on Galaxy Watch; tapping the slot opens it for start/pause/reset.
$stopwatchPolicy = '<DefaultProviderPolicy primaryProvider="com.samsung.android.watch.stopwatch/com.samsung.android.watch.stopwatch.complications.StopwatchComplicationProviderService" primaryProviderType="SHORT_TEXT" defaultSystemProvider="EMPTY" defaultSystemProviderType="EMPTY"/>'
# Samsung Weather on Galaxy Watch: condition icon plus current temperature.
$weatherPolicy   = '<DefaultProviderPolicy primaryProvider="com.samsung.android.watch.weather/com.samsung.android.watch.weather.complication.WeatherComplicationService" primaryProviderType="SHORT_TEXT" defaultSystemProvider="EMPTY" defaultSystemProviderType="EMPTY"/>'
$slotTop    = Slot 0 "top"    "slot_top"    193 115 $batteryPolicy
$slotBottom = Slot 3 "bottom" "slot_bottom" 193 271 $stopwatchPolicy
$slotLeft   = Slot 4 "left"   "slot_left"   115 193 $weatherPolicy

$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<!--
  Circle of Fifths - analog watch face (Watch Face Format v5).
  Generated by tools/Generate-WatchFaceXml.ps1; edit that script for layout changes.

  Layout (450x450 canvas, centre 225,225):
    r 206-222  minute/hour ticks
    r 203      outer ring
    r 184      major keys, clockwise in FOURTHS: C F Bb Eb Ab Db/C# Gb/F# B/Cb E A D G
    r 165      middle ring
    r 143      relative mode of each key (cycles hourly by default; user-selectable)
    r 120      inner ring
    inside     date window (3 o'clock), battery (12), stopwatch (6), weather (9), mode name under the hub

  Theme colours, by index into the selected ColorOption:
    0 major keys   1 inner ring / secondary text   2 accent (second hand, gauges, key highlight)
    3 hour+minute hands   4 rings, ticks and spokes
-->
<WatchFace width="450" height="450" clipShape="CIRCLE">
  <Metadata key="CLOCK_TYPE" value="ANALOG"/>
  <Metadata key="PREVIEW_TIME" value="10:08:32"/>

  <UserConfigurations>
    <ColorConfiguration id="themeColor" displayName="theme_label" screenReaderText="theme_label" defaultValue="0">
      <ColorOption id="0" displayName="theme_classic" colors="#ffffff #9aa0a6 #e53935 #ffffff #5f6368"/>
      <ColorOption id="1" displayName="theme_ivory"   colors="#f5ead6 #b7a883 #c62828 #f5ead6 #6b604a"/>
      <ColorOption id="2" displayName="theme_gold"    colors="#e8c46a #a8853b #f5f5f5 #e8c46a #6b5a2a"/>
      <ColorOption id="3" displayName="theme_ocean"   colors="#a9d6f5 #5b9bc4 #ffb703 #dbeefb #3d5f78"/>
      <ColorOption id="4" displayName="theme_sage"    colors="#d5e2c4 #93a884 #e76f51 #e8f0dd #4f6146"/>
      <ColorOption id="5" displayName="theme_mono"    colors="#ffffff #ffffff #ffffff #ffffff #808080"/>
    </ColorConfiguration>
    <BooleanConfiguration id="cycleHourly" displayName="cycle_label" screenReaderText="cycle_label" defaultValue="TRUE"/>
    <ListConfiguration id="innerRing" displayName="inner_ring_label" screenReaderText="inner_ring_label" defaultValue="aeolian">
      <ListOption id="aeolian"    displayName="mode_aeolian"/>
      <ListOption id="dorian"     displayName="mode_dorian"/>
      <ListOption id="phrygian"   displayName="mode_phrygian"/>
      <ListOption id="lydian"     displayName="mode_lydian"/>
      <ListOption id="mixolydian" displayName="mode_mixolydian"/>
      <ListOption id="locrian"    displayName="mode_locrian"/>
      <ListOption id="none"       displayName="mode_none"/>
    </ListConfiguration>
    <BooleanConfiguration id="highlightKey" displayName="highlight_label" screenReaderText="highlight_label" defaultValue="TRUE"/>
  </UserConfigurations>

  <Scene backgroundColor="#000000">

    <!-- Rings, spokes and ticks. Dimmed in ambient mode. -->
    <Group x="0" y="0" width="450" height="450" name="dial">
      <Variant mode="AMBIENT" target="alpha" value="120"/>
      <PartDraw x="0" y="0" width="450" height="450">
        <Ellipse x="22" y="22" width="406" height="406"><Stroke color="$LINES" thickness="1.5"/></Ellipse>
        <Ellipse x="60" y="60" width="330" height="330"><Stroke color="$LINES" thickness="1"/></Ellipse>
        <Ellipse x="105" y="105" width="240" height="240"><Stroke color="$LINES" thickness="1.5"/></Ellipse>
$($spokes.ToString().TrimEnd())
$($ticks.ToString().TrimEnd())
      </PartDraw>
    </Group>

    <!-- Highlight sector behind the key the hour hand points at (optional) -->
    <BooleanConfiguration id="highlightKey">
      <BooleanOption id="TRUE">
        <Group x="0" y="0" width="450" height="450" name="key_highlight">
          <PartDraw x="0" y="0" width="450" height="450" pivotX="0.5" pivotY="0.5" alpha="70">
            <Arc centerX="225" centerY="225" width="368" height="368" startAngle="-15" endAngle="15">
              <Stroke color="$ACCENT" thickness="38" cap="BUTT"/>
            </Arc>
            <Transform target="angle" value="round([HOUR_0_11] + [MINUTE] / 60) * 30"/>
          </PartDraw>
        </Group>
      </BooleanOption>
    </BooleanConfiguration>

    <!-- Major keys (outer ring) -->
    <Group x="0" y="0" width="450" height="450" name="major_keys">
$($majorXml.ToString().TrimEnd())
    </Group>

    <!-- Inner ring: relative mode of each key. Cycles hourly by default; otherwise the chosen mode. -->
    <BooleanConfiguration id="cycleHourly">
      <BooleanOption id="TRUE">
        <Group x="0" y="0" width="450" height="450" name="inner_cycle">
$($cycleGroups.ToString().TrimEnd())
        </Group>
      </BooleanOption>
      <BooleanOption id="FALSE">
        <Group x="0" y="0" width="450" height="450" name="inner_fixed">
    <ListConfiguration id="innerRing">
$($modeOptions.ToString().TrimEnd())
    </ListConfiguration>
        </Group>
      </BooleanOption>
    </BooleanConfiguration>

    <!-- Date window at 3 o'clock -->
    <Group x="0" y="0" width="450" height="450" name="date">
      <PartDraw x="248" y="208" width="70" height="34">
        <RoundRectangle x="1" y="1" width="68" height="32" cornerRadiusX="5" cornerRadiusY="5"><Stroke color="$LINES" thickness="1.5"/></RoundRectangle>
      </PartDraw>
      <PartText x="250" y="210" width="66" height="30">
        <Text align="CENTER" verticalAlign="CENTER"><Font family="$FONT_REG" size="17" color="$MINOR"><Template><![CDATA[%s %d]]><Parameter expression="[DAY_OF_WEEK_S]"/><Parameter expression="[DAY]"/></Template></Font></Text>
      </PartText>
    </Group>

    <!-- Complication slots: battery at 12, stopwatch at 6, weather at 9 -->
$slotTop
$slotBottom
$slotLeft

    <!-- Hands -->
    <AnalogClock x="0" y="0" width="450" height="450">
      <HourHand resource="hand_hour" x="218" y="85" width="14" height="160" pivotX="0.5" pivotY="0.875" tintColor="$HANDS"/>
      <MinuteHand resource="hand_minute" x="220" y="25" width="10" height="225" pivotX="0.5" pivotY="0.8889" tintColor="$HANDS"/>
      <SecondHand resource="hand_second" x="219" y="13" width="12" height="252" pivotX="0.5" pivotY="0.8413" tintColor="$ACCENT">
        <Variant mode="AMBIENT" target="alpha" value="0"/>
        <Sweep frequency="SYNC_TO_DEVICE"/>
      </SecondHand>
    </AnalogClock>

    <!-- Hub -->
    <PartDraw x="213" y="213" width="24" height="24">
      <Ellipse x="2" y="2" width="20" height="20"><Fill color="$HANDS"/></Ellipse>
      <Ellipse x="9" y="9" width="6" height="6"><Fill color="#000000"/></Ellipse>
    </PartDraw>

  </Scene>
</WatchFace>
"@

$out = Join-Path $PSScriptRoot "..\watchface\src\main\res\raw\watchface.xml"
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
[IO.File]::WriteAllText($out, $xml.Replace("`r`n", "`n"), (New-Object System.Text.UTF8Encoding $false))
Write-Output "wrote $out ($((Get-Item $out).Length) bytes)"
