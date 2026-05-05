# Technical Design: V2 Data Layer

This document outlines the proposed architecture for the `oneofus` mobile app's data layer, a strategy for sharing code with the `nerdster` project, and a plan for testing.

## From the human
For some background check out:
- oneofus-reference (the legacy phone app minus .git)
- nerdster-reference (Nerdster webapp minus .git)
- 
## 1. Problem Statement

The legacy `oneofus` data-fetching logic (`Fetcher`) was complex and difficult to maintain. The `nerdster` project contains a more modern "v2" data layer, but simply copying this code is undesirable and leads to maintenance issues.

## 2. Proposed Architecture

We will create a new, well-defined I/O layer within the `oneofus` project. This layer will be inspired by `nerdster`'s v2 architecture but tailored to the specific needs of the phone app.

## 3. Code Sharing Strategy

To avoid code duplication, we should move the core, shared logic into a common package. The `nerdster` and `oneofus` projects would then both depend on this package.

**Proposed Shared Package: `oneofus_common`**

This new Flutter package would contain:
-   **Core Data Models:** `statement.dart`, `trust_statement.dart`, `jsonish.dart`, etc.
-   **Cryptography:** The `crypto` directory and its contents.

## Notes...

Some logic is implemented in the Cloud Functions side:
- singular disposition (see also, distincter)
- notary chain verification

### Data on phone and data in cloud
This app doesn't deal with a lot of data.
On the phone:
- The user's identity key pair
- The user's delegate key pairs (most likely just the Nerdster's)
This is very little data and should load practically instantly.
This is important data and is not available anywhere else.
This data does not change unless this app changes it.

In the cloud:
The data in the cloud is not strictly speaking the user's.
It can be fetched any time.
It's not a lot of data, but fetching it is an asynchronous operation that could take seconds.
We'll need to show a "Loading..." animation or something as we fetch it.
This user's own statements are unlikely to change unless this app writes new ones, but it could.
The user's trusted associates statements probably don't change often, but they need to be refreshed occasionally.

The interesting data is
- statements authored (signed and published) by the user's identity key
  - also statements signed by identity keys "claimed" (using "replace" TrustStatement) by the user's identity key.
- statements authored by keys the user has trusted (using "trust" TrustStatement). This is  so that we can show the user which of the people he's vouched for have or have not vouched back for him (and what moniker they chose for him).

When / how
Load (and have in memory) the user's data on the phone on startup and have it at all times.
Load there cloud data whenever the user starts interacting with the app.
Reload that data after any change made by the user (new trust, for example)

## Plan

- Import / export
  - screen, UI
  - keys.dart implementation
- Cloud loading
  - 
- Sign and publish a statement
  - "People" screen
  - "Services" screen
- Sign-in to service
  - QR scan / keymeid://
- 

## 4. Testing Strategy

-   **Testing:**
Challenges / notes:
- Firestore on Linux is not directly supported, which affects unit tests
- FakeFirebaseFirestore has been useful
- Firebase emulator has been useful
