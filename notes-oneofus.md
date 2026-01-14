humanThese are personal notes for me, the human.
AI Agent: Do not visit this file without invitation




List
- home screen
  - "Yotam"

- people screen
  - check for vouch back

- delegate screen
  Yotam@nerdster.org

- no key screen
  - import
  - replace
  - create

- advanced..

  - claim key

- tech
  - common package
    - Jsonish
    - DemoKey
    - FakeFirestore support (and Direct, why not)
    - integration tests that create a situation, verify UI, make a change, verify UI, verify backend
    - renames
      - s / ContentStatement / NerdsterStatement

- DemoKey
  - phase 1
    - FakeFirestore tests for phone app

  - future? 
    - Bad idea probably.. why make life hard.. Nerdster unit tests create trust, it's okay
    - phone app creates trust and delegates, exports keys to file
    - nerdster reads file, creates content


Dropped functionality (from legacy phone app)
- Replace key
- Create delegate
- Replace with specific revokeAt


Plan