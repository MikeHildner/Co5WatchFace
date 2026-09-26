# Circle of Fifths watch face

An analog Wear OS watch face built with the declarative
[Watch Face Format](https://developer.android.com/training/wearables/wff) (WFF),
version 5. The dial is a circle of fifths read in fourths clockwise: the twelve
major keys sit where the hour numerals would be (C at 12, F at 1, B♭ at 2 ...)
with the relative mode of each key on an inner ring. There is no Kotlin or Java
code; the whole face is `watchface/src/main/res/raw/watchface.xml` plus a few
PNG images and three font files.

## Layout

| Radius (px, 450 canvas) | Element |
| --- | --- |
| 206 to 222 | minute ticks, hour ticks every fifth |
| 203 | outer ring |
| 184 | major keys: C F B♭ E♭ A♭ D♭/C♯ G♭/F♯ B/C♭ E A D G |
| 165 | middle ring |
| 143 | relative mode of each key |
| 120 | inner ring |
| inside | date window at 3 o'clock, battery at 12, stopwatch at 6, weather at 9, mode name under the hub |

Keys with two common spellings (D♭/C♯, G♭/F♯, B/C♭) show both, on both rings.

## Settings (on-watch editor)

- **Theme.** Six colour sets: Classic, Ivory, Gold, Ocean, Sage, Mono.
- **Cycle modes hourly.** On by default. The inner ring changes at the top of
  every hour, stepping through the modes in brightness order: Lydian,
  Mixolydian, Dorian, Aeolian, Phrygian, Locrian, then round again. The mode
  is derived from the hour of day (hour mod 6), so it needs no stored state.
- **Inner ring.** Used when cycling is off: Aeolian (default), Dorian,
  Phrygian, Lydian, Mixolydian, Locrian, or None. Modes with a minor third are
  written in lowercase, Lydian and Mixolydian in uppercase. Whichever mode is
  showing, its name appears under the hub.
- **Highlight current key.** A translucent sector in the accent colour behind
  whichever key the hour hand points at. On by default.
- **Complications.** Battery gauge at 12, Samsung Stopwatch at 6 and Samsung
  Weather (condition icon and temperature) at 9 by default. Tap the stopwatch
  to open the app for start, pause and reset. Any slot can be pointed at
  another installed data source or cleared.

WFF has no timers or state of its own, so the stopwatch is the system app's
complication, not something the face runs itself.

## Themes

Each `ColorOption` in `watchface.xml` is a list of five colours referenced by index:

| Index | Used for |
| --- | --- |
| 0 | major keys |
| 1 | inner ring, date, complication text, mode name |
| 2 | accent: second hand, gauge arcs, key highlight |
| 3 | hour and minute hands, hub |
| 4 | rings, spokes, ticks |

To add a theme, add a `ColorOption` with a new `id` and a matching
`theme_*` string in `res/values/strings.xml`.

## Typography

Letters are set in Libre Baskerville (bold for the outer ring, italic for the
inner ring, regular for the date and complications). Sharps and flats are not
in that font, so they are rendered from Bravura Text into small white PNGs
(`res/drawable/acc_*.png`) and placed inline in the text via `InlineImage`,
whose `color` attribute follows the theme. Both fonts are under the SIL Open
Font License; see `licenses/`.

## Generator scripts

`watchface.xml` and the images are produced by the scripts in `tools/`. They
compute label positions, ticks and spokes from the radii above, and spell the
relative modes from scale degrees so enharmonic keys come out right (for
example G♭ major's Locrian is F, F♯ major's is E♯). Edit the XML directly for
small tweaks; re-run the scripts to move rings, change fonts or add modes.

```bash
powershell -ExecutionPolicy Bypass -File tools/Generate-Assets.ps1
```

```bash
powershell -ExecutionPolicy Bypass -File tools/Generate-WatchFaceXml.ps1
```

## Build

Requires Android Studio (its bundled JDK is used) and the Android SDK.

```bash
./gradlew :watchface:assembleDebug
```

The APK lands in `watchface/build/outputs/apk/debug/`.

Validate the XML against the WFF schema before building (the validator jar is
published at <https://github.com/google/watchface/releases>):

```bash
java -jar wff-validator.jar 5 watchface/src/main/res/raw/watchface.xml
```

## Run on the emulator

Format version 5 needs a Wear OS image based on Android 17 (API 37); the
Wear OS 6.1 image refuses to load the face. Create a round AVD from
`system-images;android-37.0;android-wear-signed;x86_64`, then:

```bash
adb install -r watchface/build/outputs/apk/debug/watchface-debug.apk
adb shell am broadcast -a com.google.android.wearable.app.DEBUG_SURFACE --es operation set-watchface --es watchFaceId com.mikehildner.co5watchface
```

## Run on the watch

1. On the watch: Settings, About watch, Software, tap Software version seven
   times to enable Developer options.
2. Developer options, turn on ADB debugging and Wireless debugging, then
   Pair new device. Note the IP:port and pairing code shown.
3. On the PC:

```bash
adb pair <ip>:<pairing-port>
adb connect <ip>:<port>
```

Then use the same `adb install` and `am broadcast` commands as for the
emulator, adding `-s <ip>:<port>` if the emulator is also running.

Tips learned on a Galaxy Watch9:

- The watch drops Wi-Fi while the phone is connected over Bluetooth, and
  newer One UI Watch has no "Wi-Fi always on" setting. Turn Bluetooth off on
  the phone while you work, and keep the watch display awake.
- The connect port changes every time wireless debugging restarts. Find the
  current one with `adb mdns services` (look for `_adb-tls-connect`).
- The watch does not answer ping, so test reachability with TCP or mDNS.

## Notes

- `AndroidManifest.xml` declares WFF version 5 and `minSdk` is 36. Older
  watches cannot install the face.
- The preview image (`res/drawable/preview.png`) is what the watch face
  picker shows. Replace it with a screenshot of the running face after visual
  changes.
- Galaxy Watch quirk: anything placed inside a `ListOption` is evaluated once
  when the face loads (against the preview time) and never refreshed, so
  time-driven content must not live there. Content under a `BooleanOption`
  updates live, which is why the hourly cycle is gated by a boolean setting
  rather than being an option of the Inner ring list. The Wear OS emulator
  does not show this difference.
- Wear OS remembers complication choices by slot position across reinstalls.
  To make new slot defaults apply on a watch that already had the face,
  uninstall first.
