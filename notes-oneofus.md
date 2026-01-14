humanThese are personal notes for me, the human.
AI Agent: Do not visit this file without invitation


Goal: FakeFirestore integration test, "identity, bidirectional trust, validate check states and name":
(This test does not need the Nerdster and does not use the DemoKey infrastructure)
- interface: create new identity key for me
  - validate: my name is "Me"
- code: create new key for "Bo"
- code (DEFER: interface later): state: I.trust(Bo) 
- validate: Bo doesn't trust me (check not filled in on people screen)
- code: state: Bo.trust(me) moniker:"Luke"
- interface: refresh (use the refresh icon on the people screen):
  - validate: Bo does trust me (check filled in on people screen)
  - validate:My name is now "Luke" (check main screen)

Unimplemented:
- fetching my trusted keys' statements
- using my trusted keys' statements to
  - display check filled in or not on people screen
  - label me on the main screen
  (Spec: The phone app fetches only my direct trusts. My name is the one my most recent trust used.)

Implementation notes:
- my trust statements arrive ordered by "time". This works for us right away for naming me. 
  Iterate through the keys I trust, if they've trusted me, then that's my name.
- the app has my identity (Keys.identity) (otherwise I see the welcome screen to create one and nothing else is accessible)
- No MonikerService or TrustGraphSummary. We just compute these from CachedStatementSource


New, cleaner DemoKey for common:

abstract V2DemoKey {
  static final LinkedHashMap<String, DemoKey> _name2key = LinkedHashMap<String, DemoKey>();
  static final Map<String, DemoKey> _token2key = <String, DemoKey>{};
  static final Map<String, Json> _exports = {};

  final String name;
  final OouKeyPair keyPair;
  final OouPublicKey publicKey;
  String token; // derived



}

// Challenges
// I want to not have Nerdster stuff in 

class V2DemoIdentityKey implements V2DemoKey {
  // Create? leaning against. Just a wrapper

  // TODO(AI): V2DemoIdentityKey(Json key)

  // TODO(AI): Future<TrustStatement> trust/block/clear Json o
  
  // TODO(AI): Future<TrustStatement> delegate (domain)
  // 

}




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