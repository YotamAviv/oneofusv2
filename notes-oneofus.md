These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation

Better looking, easier navigation (easier for integration tests, too, if possible)
- refresh on every page, left of pulsing dot - same height
- small ONE-OF-US.NET icon on top left on every page (other than home) to go home - same height as pulsing dot
- IMPORT / EXPORT styled like PEOPLE, SERVICES
- About page
  - remove shield
  - remove ONE-OF-US.NET
  - move build number to bottom

Take 2:
- remove Logo from every screen (what I just asked for). Instead, add a home icon to the left of the refresh - make that bring you home.
- IMPORT / EXPORT, PEOPLE, and SERVICES look good on those pages, and so:
  - make the other screen top items be at that exact same height (dot, home, refresh, logo)
  - card page: Logo and ONE-OF-US.NET. Keep same font, but adjust the height maybe
  - title the about screen in the same style and location as on the other screens (IMPORT / EXPORT, PEOPLE), and have it say ONE-OF-US.NET
Don't bother running tests

No key page:
- remove shield icon and ONE-OF-US.net
- add Logo and ONE-OF-US.NET in the top left , same as on card identity page
- 3 buttons
  - CREATE NEW IDENTITY KEY
  - IMPORT IDENTITY KEY
  - CLAIM (REPLACE) IDENTITY KEY


Bugs:
- refresh takes me to home

- delegate screen
  - shows nerdster.org twice.
  - what's the check for? (revoked? add tooltip?)

- import / export
  - display "identity" instead of "one-of-us.net". Make sure that it's stored correctly (one-of-us.net) to be compatible and that import and export work.


List

- Look and navigation

- Vouch (trust)

- People screen:
  - edit
  - clear
  - block

- delegate screen
  Consider displaying "Yotam@nerdster.org"
  - revokeAt "<since always>" or at specific statement token.

- Welcome screen / no key screen
offer to:
  - import
  - replace
  - create

- advanced..
  - claim identity key ("replace", must revokeAt "<since always>")
  - claim delegate key

- tech
  - common package
    - Jsonish
    - FakeFirestore support (and Direct, why not) (might be working)
    - renames
      - s / ContentStatement / NerdsterStatement

Dropped functionality (from legacy phone app)
- Replace key
- Create delegate
- Replace with specific revokeAt

Plan