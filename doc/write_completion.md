# Waiting for write completion in the identity app

Channel infrastructure, the layer inventory, and the deferred redesign are documented in
`nerdster/doc/channel_architecture.md` ("Waiting for write completion"). This file records
only the identity-app bug that led there.

## The bug

A new user signed into the Nerdster on Chrome Android (delegate key A), then again on
Chrome desktop. The desktop sign-in created a second delegate key — delegate keys are
per-device, so `Keys.delegate(domain)` found none in desktop storage and offered to rotate
— and the Nerdster then showed "Delegate key not associated". Reloading a few times
cleared it.

Cause: a write/read race. `SignInService.signIn` awaited `channel.push(...)` for the
`delegate` statement and then immediately POSTed the session (identity key + delegate key
pair) to the service. But `_CachedSource.push` completed its future as soon as it had
signed locally and injected into its cache — the network write to `write.one-of-us.net`
was awaited *after* the completer fired. So the service was handed a delegate key while
that key's `delegate` statement was still in flight, looked the statement up, didn't find
it, and reported it unassociated.

The Nerdster side is not at fault: on sign-in it does reload fresh from one-of-us.net
(`_onSignInStateChanged` → `refresh()` clears the channel roots, and `export.js` sets
`Cache-Control: no-cache`). The only thing papering over the race was the fixed
`Future.delayed(300ms)` in `SignInSession.listen`, which a cold-started write CF outlasts.

This was a regression, not an original gap. Before `6b960ef` ("Sync oneofus_common from
nerdster: optimistic writes, fanout, excludeTypes parity") `_CachedSource.push` did
`final statement = await _writer.push(...)` and only then completed, so
`await channel.push(...)` meant the write had landed. That commit moved
`completer.complete(statement)` ahead of the network write to keep the Nerdster responsive
under rapid repeated writes, and `SignInService`, which relied on the old semantics, was
not adjusted.

`app_shell._executePush` relied on it too: its comment asserting "the write is already
committed by the time `_executePush` returns" became false at the same commit, so
`loadAllData()` could race the write.

## The fix

`ChannelFactory(fireChoice, optimisticWrites: false)` in `Config.initChannelFactory`, so
every push in this app returns only once the write has landed and throws if it failed.
`SignInService` then cannot POST the session ahead of the `delegate` statement.

This is a deliberate exception to the channel layer's design principle 3 ("the caller
never waits for the network"), which exists for the Nerdster's rapid repeated writes.
See `nerdster/doc/channel_architecture.md` for the exception, its rationale, and the
plan that would remove the need for it.

Because `push()` now waits, the refresh icon has to start spinning when the publish
starts rather than when the follow-up `loadAllData()` starts — otherwise the app sits
idle for a whole write round-trip after the user taps PUBLISH. `_isPublishing` in
`app_shell` covers the write and the refresh as one span, and disables the refresh
button for its duration. The full-screen blocking spinner is unchanged: it still appears
only when there is no data yet.

Not covered: the delegate write inside `SignInService.signIn`. It is interleaved with
dialogs that wait on the user ("Create Delegate Key?", "ROTATE KEY"), so a spinner
bracketing the whole call would misreport waiting-on-user as waiting-on-network, and
there is no hook around just the write.
