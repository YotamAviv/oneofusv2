These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation

## Android emulator
# Start from GNOME Terminal, not the Emacs shell: Emacs exports LIBGL_ALWAYS_SOFTWARE=1,
# which overrides -gpu host and gives a black emulator window.
# -no-snapshot-load: a snapshot saved under software rendering keeps the window black.
# For video, use Pixel_3a_API_35 (the capture rig expects its 1080x2220 screen).
~/Android/Sdk/emulator/emulator -avd Pixel_3a_API_35 -gpu host -no-snapshot-load -no-boot-anim > /tmp/emulator.log 2>&1 &
# Others: Pixel_7a_API_35, Pixel_7, Pixel_6a_API_35, Pixel_5_API_34, Nexus_5_API_35

# Check: must name the AMD GPU, not llvmpipe
grep "GPU Renderer" /tmp/emulator.log

# Stop
adb emu kill

git rev-list --count HEAD

adb shell pm clear net.oneofus.app

flutter run -d emulator-5554

python3 -m http.server 8766 --directory web

firebase --project=one-of-us-net deploy --only hosting
firebase --project=one-of-us-net deploy --only functions
firebase --project=one-of-us-net deploy --only firestore:rules
