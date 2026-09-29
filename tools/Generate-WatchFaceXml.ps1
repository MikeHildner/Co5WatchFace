# Generates watchface/src/main/res/raw/watchface.xml for the Circle of Fifths face (WFF v5).
# Canvas is 450x450, centre (225,225). Angles: 0 = 12 o'clock, clockwise.
# The dial runs in FOURTHS clockwise (C, F, Bb, Eb ...), the user's preferred reading.
$ErrorActionPreference = "Stop"
$inv = [cultureinfo]::InvariantCulture
function F([double]$v) { $v.ToString("0.##", $inv) }
function PX([double]$r, [double]$deg) { F (225 + $r * [math]::Sin($deg * [math]::PI / 180)) }
function PY([double]$r, [double]$deg) { F (225 - $r * [math]::Cos($deg * [math]::PI / 180)) }

# ---------------------------------------------------------------------------
# Theme colour indices (see ColorConfiguration below). Colours are positional:
# whatever sits on the outer ring uses index 0, the inner ring index 1.
# ---------------------------------------------------------------------------
$C_OUTER = "[CONFIGURATION.themeColor.0]"
$C_INNER = "[CONFIGURATION.themeColor.1]"
$ACCENT  = "[CONFIGURATION.themeColor.2]"
$HANDS   = "[CONFIGURATION.themeColor.3]"
$LINES   = "[CONFIGURATION.themeColor.4]"

$FONT_BOLD   = "libre_baskerville_bold"
$FONT_REG    = "libre_baskerville_regular"
$FONT_ITALIC = "libre_baskerville_italic"

# ---------------------------------------------------------------------------
# Geometry (450 canvas). Change these to rebalance the dial.
# ---------------------------------------------------------------------------
$R_TICK_OUT      = 222      # outer end of all ticks
$R_TICK_MINUTE   = 214      # inner end of minute ticks
$R_TICK_HOUR     = 206      # inner end of hour ticks
$R_OUTER_LINE    = 203      # outer ring
$R_OUTER_LABEL   = 183      # centre of outer labels
$OUTER_BOX       = @(100, 40)
$OUTER_SIZE      = 33;  $OUTER_SIZE_DUAL = 27
$R_MIDDLE_LINE   = 162      # ring between the two label bands
$R_INNER_LABEL   = 137      # centre of inner labels
$INNER_BOX       = @(86, 32)
$INNER_SIZE      = 26;  $INNER_SIZE_DUAL = 21
$R_INNER_LINE    = 112      # inner ring
$MODE_NAME_DIAM  = 204      # diameter of the arc the mode name follows (6 o'clock)
$MODE_NAME_SIZE  = 19
$SLOT            = 58       # complication slot size
$SLOT_OFFSET     = 68       # slot centre distance from dial centre (12 and 9 o'clock)
$SLOT_OFFSET_6   = 62       # 6 o'clock slot sits a little higher to clear the mode name

# ---------------------------------------------------------------------------
# Music theory: spell every key and its relative modes correctly.
# ---------------------------------------------------------------------------
$LETTERS   = @("C","D","E","F","G","A","B")
$NATURAL   = @(0, 2, 4, 5, 7, 9, 11)          # pitch class of each natural letter
$INTERVALS = @(0, 2, 4, 5, 7, 9, 11)          # major scale degrees

# Major keys, clockwise from 12 o'clock. Positions 5, 6 and 7 carry both enharmonic spellings.
$KEY_NAMES = @("C","F","Bb","Eb","Ab","Db/C#","Gb/F#","B/Cb","E","A","D","G")
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
$MAJOR_KEYS = @($KEY_NAMES | ForEach-Object { ,(ParseKey $_) })

# Modes: id, 0-based scale degree of the mode's tonic, lowercase (minor third)?
$MODES = @(
  @{ id = "aeolian";    degree = 5; lower = $true  }
  @{ id = "dorian";     degree = 1; lower = $true  }
  @{ id = "phrygian";   degree = 2; lower = $true  }
  @{ id = "lydian";     degree = 3; lower = $false }
  @{ id = "mixolydian"; degree = 4; lower = $false }
  @{ id = "locrian";    degree = 6; lower = $true  }
)
# Hourly cycle, brightness order (each step adds a flat): hour mod 6 picks the mode.
$CYCLE_ORDER = @("lydian", "mixolydian", "dorian", "aeolian", "phrygian", "locrian")

# Scrambled hourly order. The day splits into four 6-hour blocks (00-06, 06-12, 12-18, 18-24);
# each block shows every mode exactly once, in one of $PERM_COUNT fixed shuffles. Which shuffle
# is picked pseudo-randomly per block from the day of the year, so a given hour does not always
# show the same mode. The face has no state, so everything is derived from the clock.
$PERM_COUNT = 12
$rng = New-Object System.Random 20260929          # fixed seed: the shuffles are stable across rebuilds
$PERMS = New-Object System.Collections.Generic.List[string]
while ($PERMS.Count -lt $PERM_COUNT) {
  $p = (@(0..5) | Sort-Object { $rng.Next() }) -join ""
  if (-not $PERMS.Contains($p)) { $PERMS.Add($p) }
}
# Each shuffle is encoded as a 6-digit number whose n-th digit is the mode for hour n of the block.
function PermExpr([string]$block) {
  # abs() before fract(): on the Galaxy Watch fract() keeps the sign of negative inputs, which
  # made roughly half the blocks fall through to the last shuffle.
  $sel = "floor(fract(abs(sin($block * 12.9898) * 43758.5453)) * $PERM_COUNT)"
  $e = "$([int]$PERMS[$PERM_COUNT - 1])"
  for ($i = $PERM_COUNT - 2; $i -ge 0; $i--) { $e = "($sel == $i ? $([int]$PERMS[$i]) : $e)" }
  return $e
}
$BLOCK      = "([DAY_OF_YEAR] * 4 + floor([HOUR_0_23] / 6))"
$PERM_CUR   = PermExpr $BLOCK
$PERM_PREV  = PermExpr "($BLOCK - 1)"
$POS        = "([HOUR_0_23] % 6)"
# No repeats across a block boundary: if this block's first mode equals the previous block's last,
# swap this block's first two hours. A block's last hour is never altered, so the check never cascades.
$CONFLICT   = "((floor($PERM_CUR / 100000) % 10) == ($PERM_PREV % 10))"
$POS_FIXED  = "($CONFLICT ? ($POS == 0 ? 1 : ($POS == 1 ? 0 : $POS)) : $POS)"
$MODE_INDEX = "(floor($PERM_CUR / pow(10, 5 - $POS_FIXED)) % 10)"

function ModeTonic([int]$letter, [int]$acc, [int]$degree) {
  $L  = ($letter + $degree) % 7
  $pc = (($NATURAL[$letter] + $acc + $INTERVALS[$degree]) % 12 + 12) % 12
  $a  = $pc - $NATURAL[$L]
  if ($a -gt 6)  { $a -= 12 }
  if ($a -lt -6) { $a += 12 }
  return @($L, $a)
}

function ModeSpellings($mode) {
  $all = New-Object System.Collections.Generic.List[object]
  foreach ($key in $MAJOR_KEYS) {
    $t = New-Object System.Collections.Generic.List[object]
    foreach ($sp in $key) { $t.Add((ModeTonic $sp[0] $sp[1] $mode.degree)) }
    $all.Add($t)
  }
  return ,$all
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

# Ring placement: the outer band always uses bold and the outer colour; the inner band uses the
# inner colour, italic for modes and upright for major keys.
$PLACE = @{
  outer = @{ r = $R_OUTER_LABEL; box = $OUTER_BOX; size = $OUTER_SIZE; dual = $OUTER_SIZE_DUAL; color = $C_OUTER }
  inner = @{ r = $R_INNER_LABEL; box = $INNER_BOX; size = $INNER_SIZE; dual = $INNER_SIZE_DUAL; color = $C_INNER }
}

function RingLabelsXml($spellingLists, [string]$placement, [string]$family, [bool]$lower, [string]$partExtra = "") {
  $p = $PLACE[$placement]
  $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt 12; $i++) {
    $sp = $spellingLists[$i]
    $size = if ($sp.Count -gt 1) { $p.dual } else { $p.size }
    $a  = $i * 30
    $cx = 225 + $p.r * [math]::Sin($a * [math]::PI / 180)
    $cy = 225 - $p.r * [math]::Cos($a * [math]::PI / 180)
    $w = $p.box[0]; $h = $p.box[1]
    $x = [int][math]::Round($cx - $w / 2); $y = [int][math]::Round($cy - $h / 2)
    $extraLine = if ($partExtra) { "`n$partExtra" } else { "" }
    [void]$sb.Append(@"
      <PartText x="$x" y="$y" width="$w" height="$h">$extraLine
        <Text align="CENTER" verticalAlign="CENTER" isAutoSize="TRUE"><Font family="$family" size="$(F $size)" minSize="12" color="$($p.color)">$(LabelXml $sp $lower $size $p.color)</Font></Text>
      </PartText>

"@)
  }
  return $sb.ToString()
}

# Curved mode name at 6 o'clock, just inside the inner ring, reading left to right.
function ModeNameXml([string]$modeId, [string]$partExtra = "") {
  $extraLine = if ($partExtra) { "`n$partExtra" } else { "" }
  return @"
      <PartText x="0" y="0" width="450" height="450">$extraLine
        <TextCircular centerX="225" centerY="225" width="$MODE_NAME_DIAM" height="$MODE_NAME_DIAM" startAngle="235" endAngle="125" direction="COUNTER_CLOCKWISE" align="CENTER"><Font family="$FONT_ITALIC" size="$MODE_NAME_SIZE" color="$C_INNER">mode_$modeId</Font></TextCircular>
      </PartText>

"@
}

function ModeGroupXml($mode, [string]$placement, [string]$name, [string]$partExtra = "", [string]$groupExtra = "") {
  $family = if ($placement -eq "outer") { $FONT_BOLD } else { $FONT_ITALIC }
  $groupLine = if ($groupExtra) { "`n$groupExtra" } else { "" }
  return @"
        <Group x="0" y="0" width="450" height="450" name="$name">$groupLine
$(RingLabelsXml (ModeSpellings $mode) $placement $family $mode.lower $partExtra)$(ModeNameXml $mode.id $partExtra)        </Group>
"@
}

function MajorsGroupXml([string]$placement, [string]$name) {
  $family = if ($placement -eq "outer") { $FONT_BOLD } else { $FONT_REG }
  return @"
      <Group x="0" y="0" width="450" height="450" name="$name">
$(RingLabelsXml $MAJOR_KEYS $placement $family $false)      </Group>
"@
}

# One complete ring set. $modesAt = "inner" (standard) or "outer" (swapped).
# Everything time-driven sits under BooleanOptions: on the Galaxy Watch, content inside a
# ListOption is evaluated once at load (against the preview time) and never refreshed, while
# BooleanOption content stays live. Fixed modes are static, so they may live in the ListOption.
function RingSetXml([string]$modesAt, [string]$tag) {
  $majorsAt = if ($modesAt -eq "inner") { "outer" } else { "inner" }
  $cycle = New-Object System.Text.StringBuilder
  for ($k = 0; $k -lt $CYCLE_ORDER.Count; $k++) {
    $m = $MODES | Where-Object { $_.id -eq $CYCLE_ORDER[$k] }
    $alpha = "          <Transform target=""alpha"" value=""$MODE_INDEX == $k ? 255 : 0""/>"
    [void]$cycle.AppendLine((ModeGroupXml $m $modesAt "modes_$($m.id)_cycle_$tag" "" $alpha))
  }
  $fixed = New-Object System.Text.StringBuilder
  foreach ($m in $MODES) {
    [void]$fixed.AppendLine("            <ListOption id=""$($m.id)"">")
    [void]$fixed.AppendLine((ModeGroupXml $m $modesAt "modes_$($m.id)_fixed_$tag"))
    [void]$fixed.AppendLine("            </ListOption>")
  }
  [void]$fixed.AppendLine("            <ListOption id=""none"">")
  [void]$fixed.AppendLine("              <Group x=""0"" y=""0"" width=""450"" height=""450"" name=""modes_none_$tag""/>")
  [void]$fixed.AppendLine("            </ListOption>")
  return @"
      <Group x="0" y="0" width="450" height="450" name="rings_$tag">
$(MajorsGroupXml $majorsAt "majors_$tag")
        <BooleanConfiguration id="cycleHourly">
          <BooleanOption id="TRUE">
            <Group x="0" y="0" width="450" height="450" name="cycle_$tag">
$($cycle.ToString().TrimEnd())
            </Group>
          </BooleanOption>
          <BooleanOption id="FALSE">
            <Group x="0" y="0" width="450" height="450" name="fixed_$tag">
          <ListConfiguration id="innerRing">
$($fixed.ToString().TrimEnd())
          </ListConfiguration>
            </Group>
          </BooleanOption>
        </BooleanConfiguration>
      </Group>
"@
}

# ---- ticks: 60 minute ticks, every 5th is an hour tick ----
$ticks = New-Object System.Text.StringBuilder
for ($k = 0; $k -lt 60; $k++) {
  $a = $k * 6
  if ($k % 5 -eq 0) { $r1 = $R_TICK_HOUR; $th = 3 } else { $r1 = $R_TICK_MINUTE; $th = 1.5 }
  [void]$ticks.AppendLine("        <Line startX=""$(PX $r1 $a)"" startY=""$(PY $r1 $a)"" endX=""$(PX $R_TICK_OUT $a)"" endY=""$(PY $R_TICK_OUT $a)""><Stroke color=""$LINES"" thickness=""$th"" cap=""BUTT""/></Line>")
}
# ---- spokes between the 12 segments ----
$spokes = New-Object System.Text.StringBuilder
for ($k = 0; $k -lt 12; $k++) {
  $a = 15 + $k * 30
  [void]$spokes.AppendLine("        <Line startX=""$(PX $R_INNER_LINE $a)"" startY=""$(PY $R_INNER_LINE $a)"" endX=""$(PX $R_OUTER_LINE $a)"" endY=""$(PY $R_OUTER_LINE $a)""><Stroke color=""$LINES"" thickness=""1"" cap=""BUTT""/></Line>")
}
function RingEllipse([double]$r, [double]$thick) {
  "        <Ellipse x=""$(F (225 - $r))"" y=""$(F (225 - $r))"" width=""$(F (2 * $r))"" height=""$(F (2 * $r))""><Stroke color=""$LINES"" thickness=""$thick""/></Ellipse>"
}

# ---- complication rendering (coordinates relative to the $SLOT-sized slot) ----
function CompText([int]$x, [int]$y, [int]$w, [int]$h, [double]$size) {
@"
            <PartText x="$x" y="$y" width="$w" height="$h">
              <Text align="CENTER" verticalAlign="CENTER" isAutoSize="TRUE" ellipsis="TRUE"><Font family="$FONT_REG" size="$size" minSize="11" color="$C_INNER"><Template><![CDATA[%s]]><Parameter expression="[COMPLICATION.TEXT]"/></Template></Font></Text>
            </PartText>
"@
}
function Slot($id, $name, $displayName, [int]$cx, [int]$cy, $policy) {
  $S = $SLOT; $half = [int]($S / 2)
  $x = $cx - $half; $y = $cy - $half
@"
    <ComplicationSlot x="$x" y="$y" width="$S" height="$S" slotId="$id" name="$name" displayName="$displayName" supportedTypes="SHORT_TEXT RANGED_VALUE MONOCHROMATIC_IMAGE SMALL_IMAGE EMPTY" isCustomizable="TRUE">
      $policy
      <BoundingOval x="0" y="0" width="$S" height="$S" outlinePadding="2"/>
      <Complication type="SHORT_TEXT">
        <Condition>
          <Expressions>
            <Expression name="hasIcon"><![CDATA[[COMPLICATION.MONOCHROMATIC_IMAGE] != null]]></Expression>
          </Expressions>
          <Compare expression="hasIcon">
            <PartImage x="$($half - 9)" y="4" width="18" height="18" tintColor="$C_INNER">
              <Image resource="[COMPLICATION.MONOCHROMATIC_IMAGE]"/>
            </PartImage>
$(CompText 1 23 ($S - 2) 26 20)
          </Compare>
          <Default>
$(CompText 1 15 ($S - 2) 28 22)
          </Default>
        </Condition>
      </Complication>
      <Complication type="RANGED_VALUE">
        <PartDraw x="0" y="0" width="$S" height="$S">
          <Arc centerX="$half" centerY="$half" width="$($S - 6)" height="$($S - 6)" startAngle="-135" endAngle="135">
            <Stroke color="$LINES" thickness="3" cap="ROUND"/>
          </Arc>
          <Arc centerX="$half" centerY="$half" width="$($S - 6)" height="$($S - 6)" startAngle="-135" endAngle="135">
            <Stroke color="$ACCENT" thickness="3" cap="ROUND"/>
            <Transform target="endAngle" value="-135 + ((clamp([COMPLICATION.RANGED_VALUE_VALUE], [COMPLICATION.RANGED_VALUE_MIN], [COMPLICATION.RANGED_VALUE_MAX]) - [COMPLICATION.RANGED_VALUE_MIN]) / ([COMPLICATION.RANGED_VALUE_MAX] - [COMPLICATION.RANGED_VALUE_MIN])) * 270"/>
          </Arc>
        </PartDraw>
        <Condition>
          <Expressions>
            <Expression name="hasIcon"><![CDATA[[COMPLICATION.MONOCHROMATIC_IMAGE] != null]]></Expression>
          </Expressions>
          <Compare expression="hasIcon">
            <PartImage x="$($half - 7)" y="10" width="14" height="14" tintColor="$C_INNER">
              <Image resource="[COMPLICATION.MONOCHROMATIC_IMAGE]"/>
            </PartImage>
$(CompText 6 25 ($S - 12) 20 17)
          </Compare>
          <Default>
$(CompText 6 17 ($S - 12) 24 19)
          </Default>
        </Condition>
      </Complication>
      <Complication type="MONOCHROMATIC_IMAGE">
        <PartImage x="$($half - 15)" y="$($half - 15)" width="30" height="30" tintColor="$C_INNER">
          <Image resource="[COMPLICATION.MONOCHROMATIC_IMAGE]"/>
        </PartImage>
      </Complication>
      <Complication type="SMALL_IMAGE">
        <PartImage x="$($half - 19)" y="$($half - 19)" width="38" height="38">
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
$slotTop    = Slot 0 "top"    "slot_top"    225 (225 - $SLOT_OFFSET) $batteryPolicy
$slotBottom = Slot 3 "bottom" "slot_bottom" 225 (225 + $SLOT_OFFSET_6) $stopwatchPolicy
$slotLeft   = Slot 4 "left"   "slot_left"   (225 - $SLOT_OFFSET) 225 $weatherPolicy

# Highlight sector spans the outer label band.
$HL_R     = ($R_MIDDLE_LINE + $R_OUTER_LINE) / 2
$HL_THICK = $R_OUTER_LINE - $R_MIDDLE_LINE

$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<!--
  Circle of Fifths - analog watch face (Watch Face Format v5).
  Generated by tools/Generate-WatchFaceXml.ps1; edit that script for layout changes.

  Layout (450x450 canvas, centre 225,225):
    r $R_TICK_HOUR-$R_TICK_OUT  minute/hour ticks
    r $R_OUTER_LINE      outer ring
    r $R_OUTER_LABEL      outer labels: major keys, clockwise in FOURTHS: C F Bb Eb Ab Db/C# Gb/F# B/Cb E A D G
    r $R_MIDDLE_LINE      middle ring
    r $R_INNER_LABEL      inner labels: relative mode of each key (cycles hourly by default)
    r $R_INNER_LINE      inner ring
    inside     date window (3 o'clock, tap opens Calendar), battery (12), stopwatch (6), weather (9),
               mode name curved along the inner ring at 6 o'clock
  "Swap rings" puts the modes on the outer ring and the major keys on the inner ring.

  Theme colours, by index into the selected ColorOption:
    0 outer ring labels   1 inner ring labels / secondary text   2 accent (second hand, gauges, key highlight)
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
    <BooleanConfiguration id="swapRings" displayName="swap_label" screenReaderText="swap_label" defaultValue="FALSE"/>
    <BooleanConfiguration id="highlightKey" displayName="highlight_label" screenReaderText="highlight_label" defaultValue="TRUE"/>
  </UserConfigurations>

  <Scene backgroundColor="#000000">

    <!-- Rings, spokes and ticks. Dimmed in ambient mode. -->
    <Group x="0" y="0" width="450" height="450" name="dial">
      <Variant mode="AMBIENT" target="alpha" value="120"/>
      <PartDraw x="0" y="0" width="450" height="450">
$(RingEllipse $R_OUTER_LINE 1.5)
$(RingEllipse $R_MIDDLE_LINE 1)
$(RingEllipse $R_INNER_LINE 1.5)
$($spokes.ToString().TrimEnd())
$($ticks.ToString().TrimEnd())
      </PartDraw>
    </Group>

    <!-- Highlight sector behind the outer label the hour hand points at (optional) -->
    <BooleanConfiguration id="highlightKey">
      <BooleanOption id="TRUE">
        <Group x="0" y="0" width="450" height="450" name="key_highlight">
          <PartDraw x="0" y="0" width="450" height="450" pivotX="0.5" pivotY="0.5" alpha="70">
            <Arc centerX="225" centerY="225" width="$(F (2 * $HL_R))" height="$(F (2 * $HL_R))" startAngle="-15" endAngle="15">
              <Stroke color="$ACCENT" thickness="$(F $HL_THICK)" cap="BUTT"/>
            </Arc>
            <Transform target="angle" value="round([HOUR_0_11] + [MINUTE] / 60) * 30"/>
          </PartDraw>
        </Group>
      </BooleanOption>
    </BooleanConfiguration>

    <!-- Key and mode rings: standard (keys outside) or swapped (modes outside) -->
    <BooleanConfiguration id="swapRings">
      <BooleanOption id="FALSE">
$(RingSetXml "inner" "std")
      </BooleanOption>
      <BooleanOption id="TRUE">
$(RingSetXml "outer" "swap")
      </BooleanOption>
    </BooleanConfiguration>

    <!-- Date window at 3 o'clock; tap opens Calendar -->
    <Group x="256" y="207" width="74" height="36" name="date">
      <Launch target="CALENDAR"/>
      <PartDraw x="0" y="0" width="74" height="36">
        <RoundRectangle x="1" y="1" width="72" height="34" cornerRadiusX="5" cornerRadiusY="5"><Stroke color="$LINES" thickness="1.5"/></RoundRectangle>
      </PartDraw>
      <PartText x="2" y="2" width="70" height="32">
        <Text align="CENTER" verticalAlign="CENTER" isAutoSize="TRUE"><Font family="$FONT_REG" size="19" minSize="12" color="$C_INNER"><Template><![CDATA[%s %d]]><Parameter expression="[DAY_OF_WEEK_S]"/><Parameter expression="[DAY]"/></Template></Font></Text>
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
