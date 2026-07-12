# Flutter dev setup & upgrade notes

Notes on the local Flutter toolchain for the three sibling repos
(`oneofus`, `nerdster`, `hablotengo`). Applies to the shared dev machine.

## Flutter install: user-owned git checkout (not snap)

Flutter runs from a **user-owned git install at `~/bin/flutter`**, activated in
`~/.bashrc`:

```bash
export PATH="$HOME/bin/flutter/bin:$PATH"
```

This shadows the older snap Flutter (`/snap/bin/flutter`). The git install needs
no root, upgrades/downgrades normally (`flutter upgrade`, `git checkout <tag>`),
and pins to any commit. Verify the right one is active:

```bash
which flutter    # -> /home/aviv/bin/flutter/bin/flutter  (NOT /snap/bin)
```

Current version as of 2026-07-12: **Flutter 3.44.6 / Dart 3.12.2**
(upgraded from 3.41.4 / 3.11.1).

## Gotcha: the snap `curl` cannot download the Dart SDK into `~/bin`

`curl` on this machine is a **third-party snap** (`/snap/bin/curl`, AppArmor
profile `snap.curl.curl`; there is no `/usr/bin/curl`). Its confinement **denies
file creation under `~/bin`**:

```
apparmor="DENIED" operation="mknod" profile="snap.curl.curl"
name="/home/aviv/bin/flutter/bin/cache/dart-sdk-linux-x64.zip" comm="curl"
```

It writes fine to `~/` and `~/src/...`; only `~/bin` is blocked. Because
Flutter's Dart-SDK bootstrap (`bin/internal/update_dart_sdk.sh`) shells out to
`curl` to download into `~/bin/flutter/bin/cache`, a **fresh `flutter --version`
or `flutter upgrade` fails** with `curl` exit 23 ("Permission denied"). Once the
Dart SDK exists, everything else (`flutter precache`, `pub get`, builds) uses
Flutter's own unconfined Dart binary and works normally — this only bites the
initial SDK download step.

### Fixes

**Permanent (needs root, recommended):** install a real curl that shadows the
snap (`/usr/bin` precedes `/snap/bin` on PATH):

```bash
sudo apt install curl
# optional: sudo snap remove curl
```

**No root (temporary shim):** `/usr/bin/wget` is unconfined. Drop a `curl`→`wget`
shim into `~/.local/bin` (first on PATH) **only for the duration of an upgrade**,
then delete it — it must not linger, because it breaks plain `curl -s <url>`
health-probes (e.g. the emulator checks in `bin/run_all_tests.sh`) by
mistranslating them to `wget -O ""`:

```bash
cat > ~/.local/bin/curl <<'EOF'
#!/usr/bin/env bash
# TEMP shim: forward Flutter's curl download to unconfined wget. Delete after use.
out=""; url=""; cont=0; tries=3
while [ $# -gt 0 ]; do
  case "$1" in
    --output|-o)        out="$2"; shift 2;;
    --continue-at|-C)   cont=1;   shift 2;;
    --retry)            tries="$2"; shift 2;;
    --location|-L)      shift;;
    --verbose|-v|--silent|-s|--show-error|-S|--fail|-f) shift;;
    http://*|https://*) url="$1"; shift;;
    *)                  shift;;
  esac
done
args=(--tries="$tries" -O "$out"); [ "$cont" -eq 1 ] && args+=(-c)
exec /usr/bin/wget "${args[@]}" "$url"
EOF
chmod +x ~/.local/bin/curl
flutter --version          # downloads the Dart SDK via wget
rm -f ~/.local/bin/curl    # IMPORTANT: remove before running tests
```

## Upgrade fallout: ListTile-in-DecoratedBox assertion (3.44+)

Flutter 3.44 added a debug-mode assertion:

> **ListTile background color or ink splashes may be invisible.** The ListTile is
> wrapped in a DecoratedBox that has a background color... wrap the ListTile in
> its own Material widget, or remove the background color from the intermediate
> DecoratedBox.

It fires whenever a `ListTile` sits under an intermediate `DecoratedBox` /
`Container` that carries its own `color` — the common idiom being a modal sheet
with `backgroundColor: Colors.transparent` plus an inner colored `Container`.
Integration tests fail on *any* uncaught framework exception, so an otherwise
passing flow fails if it opens such a sheet.

**Fix:** make that surface a `Material` (which provides the ink surface) instead
of a colored `Container`; move any `padding` into a `Padding` child:

```dart
// before
Container(
  decoration: const BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
  ),
  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
  child: Column( ... ),
)

// after
Material(
  color: Colors.white,
  elevation: 0,
  clipBehavior: Clip.antiAlias,
  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
  child: Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
    child: Column( ... ),
  ),
)
```

Sites fixed for 3.44.6: `oneofus` hub menu (`lib/ui/app_shell.dart`) and
`nerdster` `lib/ui/dialogs/node_details.dart`. `hablotengo` had no instance.

**Don't over-fix:** sheets that put the color on the sheet's *own* Material via
`showModalBottomSheet(backgroundColor: ...)` (rather than an inner `Container`)
are already correct and must not be changed.

## Android migrator note

The first Android build on 3.44 auto-appends these to `android/gradle.properties`
(benign opt-outs that preserve prior behavior — keep them):

```properties
android.builtInKotlin=false
android.newDsl=false
```
