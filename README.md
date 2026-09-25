# Circle of Fifths watch face

An analog Wear OS watch face built with the declarative
[Watch Face Format](https://developer.android.com/training/wearables/wff) (WFF).
The dial is a circle of fifths: the twelve major keys sit where the hour
numerals would be (C at 12, G at 1, D at 2 ...) with their relative minors on an
inner ring. There is no Kotlin or Java code; the whole face is
`watchface/src/main/res/raw/watchface.xml` plus a few PNG hand images.

## Layout

| Radius (px, 450 canvas) | Element |
| --- | --- |
| 206 to 222 | minute ticks, hour ticks every fifth |
| 203 | outer ring |
| 184 | major keys |
| 165 | middle ring |
| 143 | relative minors |
| 120 | inner ring |
| inside | date window at 3 o'clock; complication slots at 12, 9 and 6 o'clock |

Complication slot defaults: 12 o'clock battery gauge, 9 o'clock step count,
6 o'clock heart rate. All three accept short text, ranged value, icon and small
image data. The user picks any installed data source in the on-watch editor, or
clears a slot. Slots are 64 px wide, so pick sources that render a number or an
icon rather than long text.

## Themes

Themes live in the `ColorConfiguration` block at the top of `watchface.xml`.
Each `ColorOption` is a list of five colours referenced by index:

| Index | Used for |
| --- | --- |
| 0 | major keys |
| 1 | relative minors, date, complication text |
| 2 | accent: second hand and gauge arcs |
| 3 | hour and minute hands, hub |
| 4 | rings, spokes, ticks |

To add a theme, add a `ColorOption` with a new `id` and a matching
`theme_*` string in `res/values/strings.xml`.

## Build

Requires Android Studio (its bundled JDK is used) and the Android SDK.

```bash
./gradlew :watchface:assembleDebug
```

The APK lands in `watchface/build/outputs/apk/debug/`.

Validate the XML against the WFF schema before building (the validator jar is
published at <https://github.com/google/watchface/releases>):

```bash
java -jar wff-validator.jar 2 watchface/src/main/res/raw/watchface.xml
```

## Run on the emulator

Create a Wear OS AVD once (Device Manager in Android Studio, or `avdmanager`),
then:

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

Tips learned on a Galaxy Watch8:

- The watch drops Wi-Fi while the phone is connected over Bluetooth, and
  newer One UI Watch has no "Wi-Fi always on" setting. Turn Bluetooth off on
  the phone while you work, and keep the watch display awake.
- The connect port changes every time wireless debugging restarts. Find the
  current one with `adb mdns services` (look for `_adb-tls-connect`).
- The watch does not answer ping, so test reachability with TCP or mDNS.

## Generator scripts

`watchface.xml` and the hand images were produced by the scripts in `tools/`.
They compute the label positions, ticks and spokes from the radii listed
above. Edit the XML directly for small changes; re-run the scripts when you
want to move rings or re-space labels:

```bash
powershell -ExecutionPolicy Bypass -File tools/Generate-WatchFaceXml.ps1
```

```bash
powershell -ExecutionPolicy Bypass -File tools/Generate-Assets.ps1
```

## Notes

- `AndroidManifest.xml` declares WFF version 2 (Wear OS 5, API 34+). Bump the
  `com.google.wear.watchface.format.version` property and `minSdk` to use
  newer features such as ambient transitions (v4, Wear OS 6).
- The preview image (`res/drawable/preview.png`) is what the watch face
  picker shows. Replace it with a screenshot of the running face after visual
  changes.
- Musical sharps and flats are the Unicode glyphs U+266F and U+266D; keep the
  XML saved as UTF-8.
