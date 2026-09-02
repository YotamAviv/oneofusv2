# attic — reverted filming machinery

Kept because it solved a real problem and might again, not because it is in use.

## filmKeymeid.patch

Made the Nerdster's `https://one-of-us.net/...` sign-in button hand off over
`keymeid://` while keeping its label, so a **desktop** browser could reach the
ONE-OF-US.NET app running inside an Android emulator — the only transport that
crosses that boundary.

**Why it was removed.** Filming moved into the Android emulator: Chrome and the
identity app now run on the same device, so the real universal link works and no
substitution is needed. Worse, it was actively harmful — it recorded
`SignInMethod.keymeid`, and block/clear later reuse whichever transport was used
to sign in, so it would have baked a wrong value into demo state.

**What replaced it.** A device setting, not a code change. The AVD build is
debug-signed, so app-link verification fails (`pm get-app-links` shows state
`1024`), but Android still lets you approve a handler by hand:

    adb shell pm set-app-links-user-selection --user 0 \
      --package net.oneofus.app true one-of-us.net

That yields the genuine universal-link flow with the correct `SignInMethod`, and
lives in the filming rig rather than in shipped code.

**If you need it again** — say for a desktop-browser rig — apply with:

    git apply tools/video/attic/filmKeymeid.patch    # from the nerdster repo

Touches `packages/nerdster_common/lib/ui/sign_in_dialog.dart`,
`lib/ui/sign_in_widget.dart`, `bin/serve_web.sh`. Note `packages/` is meant to be
identical across all three repos.
