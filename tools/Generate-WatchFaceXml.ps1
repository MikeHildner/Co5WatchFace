# Generates watchface/src/main/res/raw/watchface.xml for the Circle of Fifths face.
# Canvas is 450x450, centre (225,225). Angles: 0 = 12 o'clock, clockwise.
$ErrorActionPreference = "Stop"
$inv = [cultureinfo]::InvariantCulture
function F([double]$v) { $v.ToString("0.##", $inv) }
function PX([double]$r, [double]$deg) { F (225 + $r * [math]::Sin($deg * [math]::PI / 180)) }
function PY([double]$r, [double]$deg) { F (225 - $r * [math]::Cos($deg * [math]::PI / 180)) }

$LINES  = "[CONFIGURATION.themeColor.4]"
$MAJOR  = "[CONFIGURATION.themeColor.0]"
$MINOR  = "[CONFIGURATION.themeColor.1]"
$ACCENT = "[CONFIGURATION.themeColor.2]"
$HANDS  = "[CONFIGURATION.themeColor.3]"

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

# ---- key labels ----
# Musical sharp/flat as code points so the script is safe in any file encoding.
$S = [string][char]0x266F   # ♯
$B = [string][char]0x266D   # ♭
$majors = @("C","G","D","A","E","B","F$S/G$B","D$B","A$B","E$B","B$B","F")
$minors = @("a","e","b","f$S","c$S","g$S","d$S/e$B","b$B","f","c","g","d")

function Labels($names, $r, $w, $h, $size, $weight, $tint) {
  $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt 12; $i++) {
    $a = $i * 30
    $cx = 225 + $r * [math]::Sin($a * [math]::PI / 180)
    $cy = 225 - $r * [math]::Cos($a * [math]::PI / 180)
    $x = [int][math]::Round($cx - $w / 2); $y = [int][math]::Round($cy - $h / 2)
    [void]$sb.AppendLine("      <PartText x=""$x"" y=""$y"" width=""$w"" height=""$h"" tintColor=""$tint"">")
    [void]$sb.AppendLine("        <Text align=""CENTER""><Font family=""SYNC_TO_DEVICE"" size=""$size"" weight=""$weight"" color=""#ffffff"">$($names[$i])</Font></Text>")
    [void]$sb.AppendLine("      </PartText>")
  }
  $sb.ToString().TrimEnd()
}
$majorXml = Labels $majors 184 90 36 30 "BOLD" $MAJOR
$minorXml = Labels $minors 143 70 28 21 "MEDIUM" $MINOR

# ---- complication slot renderer (64x64, coordinates relative to the slot) ----
function Slot($id, $name, $displayName, $x, $y, $provider, $providerType) {
@"
    <ComplicationSlot x="$x" y="$y" width="64" height="64" slotId="$id" name="$name" displayName="$displayName" supportedTypes="SHORT_TEXT RANGED_VALUE MONOCHROMATIC_IMAGE SMALL_IMAGE EMPTY" isCustomizable="TRUE">
      <DefaultProviderPolicy defaultSystemProvider="$provider" defaultSystemProviderType="$providerType"/>
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
            <PartText x="2" y="28" width="60" height="26" tintColor="$MINOR">
              <Text align="CENTER" ellipsis="TRUE"><Font family="SYNC_TO_DEVICE" size="18" weight="MEDIUM" color="#ffffff"><Template><![CDATA[%s]]><Parameter expression="[COMPLICATION.TEXT]"/></Template></Font></Text>
            </PartText>
          </Compare>
          <Default>
            <PartText x="2" y="18" width="60" height="28" tintColor="$MINOR">
              <Text align="CENTER" ellipsis="TRUE"><Font family="SYNC_TO_DEVICE" size="20" weight="MEDIUM" color="#ffffff"><Template><![CDATA[%s]]><Parameter expression="[COMPLICATION.TEXT]"/></Template></Font></Text>
            </PartText>
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
            <PartText x="8" y="29" width="48" height="22" tintColor="$MINOR">
              <Text align="CENTER" ellipsis="TRUE"><Font family="SYNC_TO_DEVICE" size="15" weight="MEDIUM" color="#ffffff"><Template><![CDATA[%s]]><Parameter expression="[COMPLICATION.TEXT]"/></Template></Font></Text>
            </PartText>
          </Compare>
          <Default>
            <PartText x="8" y="20" width="48" height="24" tintColor="$MINOR">
              <Text align="CENTER" ellipsis="TRUE"><Font family="SYNC_TO_DEVICE" size="16" weight="MEDIUM" color="#ffffff"><Template><![CDATA[%s]]><Parameter expression="[COMPLICATION.TEXT]"/></Template></Font></Text>
            </PartText>
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
$slotTop    = Slot 0 "top"    "slot_top"    193 115 "WATCH_BATTERY" "RANGED_VALUE"
$slotLeft   = Slot 1 "left"   "slot_left"   115 193 "STEP_COUNT"    "SHORT_TEXT"
$slotBottom = Slot 2 "bottom" "slot_bottom" 193 271 "HEART_RATE"    "SHORT_TEXT"

$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<!--
  Circle of Fifths - analog watch face (Watch Face Format v2).

  Layout (450x450 canvas, centre 225,225):
    r 206-222  minute/hour ticks
    r 203      outer ring
    r 184      major keys   (C G D A E B F#/Gb Db Ab Eb Bb F)
    r 165      middle ring
    r 143      relative minors
    r 120      inner ring
    inside     date window (3 o'clock) and three complication slots (12, 9, 6 o'clock)

  Theme colours, by index into the selected ColorOption:
    0 major keys   1 minor keys / secondary text   2 accent (second hand, gauges)
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

    <!-- Major keys (outer ring) -->
    <Group x="0" y="0" width="450" height="450" name="major_keys">
$majorXml
    </Group>

    <!-- Relative minors (inner ring) -->
    <Group x="0" y="0" width="450" height="450" name="minor_keys">
$minorXml
    </Group>

    <!-- Date window at 3 o'clock -->
    <Group x="0" y="0" width="450" height="450" name="date">
      <PartDraw x="248" y="208" width="70" height="34">
        <RoundRectangle x="1" y="1" width="68" height="32" cornerRadiusX="5" cornerRadiusY="5"><Stroke color="$LINES" thickness="1.5"/></RoundRectangle>
      </PartDraw>
      <PartText x="250" y="210" width="66" height="30" tintColor="$MINOR">
        <Text align="CENTER"><Font family="SYNC_TO_DEVICE" size="18" weight="MEDIUM" color="#ffffff"><Upper/><Template><![CDATA[%s %d]]><Parameter expression="[DAY_OF_WEEK_S]"/><Parameter expression="[DAY]"/></Template></Font></Text>
      </PartText>
    </Group>

    <!-- Complication slots: 12, 9 and 6 o'clock -->
$slotTop
$slotLeft
$slotBottom

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
