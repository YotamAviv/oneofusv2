
Edit Statement / Establish New Statement

## Prerequisites
- show crypto
  - statements
  - keys
- display keys
  - blue / green (identity / delegate)
  - crossed out (revoked)
  - solid / outline (have private key / don't)

# Requirements

## Fundamntals simple
- trust new person
- create and associate delegate

## Basic Maintenance
- update names, comments
- clear vouches
- revoke, clear delegates

## Help the user Stay out of trouble
- don't encourage trusting delegates, blocking friends, etc..
- keep private keys in secure storage in sync with delegate association
- don't allow typing in domains for delegation

## Advanced maintenance
- block bad keys
- claim lost key
- claim lost delegate

## Make it possible to get out of trouble
The user may have gotten into trouble, done something wrong by accident such as:
- delegate a friend
- claim the wrong key
- etc...
These are all examples of statements he regrets.

If he can find the statement, he can clear it.

He may have found the key when trying to do something we don't allow (trusting a blocked key, replacing a delegate key, etc..)
When scanning to trust, block, claim identity, claim delegate, we already have **warn but allow**

If he can't easily find the statement, he should find the key.
He may need to find a QR code on the Nerdster, look through for short identifiers, who knows..
TODO: CONSIDER: a special **clear key**.
- Be shown what he previously said about it and clear that, whatever it is

# Required, recommended, optional fields
- vouch
  - moniker
  - comment (optional (he can know the story by the moniker he used))
- delegate
  - domain
  - (revokeAt)
- block
  - comment (recommended, include text)
- replace
  - comment (recommended, include text)
  - revokeAt = "<since always>"

# UI Plan

## Fundamntals simple
- card page scanner
  sign in and/or create associate delegate
  trust new person

## Basic maintenance
- edit any statement type where it lives
  - people screen, delegates screen, blocks, replaces
  don't show fields that we don't allow
  - allow ["UPDATE", "CANCEL"] only

## Advanced maintenance
- block bad keys
Add scan button to blocks screen
Challenges:
- already [trusted, delegated, replaced]!?
  **Warn but allow**

- claim lost key
Challenges:
- already [trusted, delegated, replaced]!?
  **Warn but allow**

- claim lost key
Challenges:
- already [trusted, delegated, replaced]!?
  **Warn but allow**

- claim lost delegate
Challenges:
- already [trusted, delegated, replaced]!?
  **Warn but allow**

**Warn but allow**
- displays a different warning for every combination [old verb, new verb], has text locations for moniker, domain, time, comment
  - future: warn about stating stuff about subjects of your trusted people.
- requires a checkbox to confirm that you get it


# UI Spec

EditStatement dialog
- verb disposition required
- existing statement optional
- Use TextFieldEditor for
  - moniker
  - domain
- Use TextBoxEditor for 
  - comment
- Use DelegateRevokeAt for delegate verb
  - the UI we have is good
- Use UseDelegateRevokeAt for replace verb

Use those different editor widget types to plop into the EditStatement dialog.
Those different widgets establish the value of their single responsiblity.

# Testing Strategy

Put these rules in const Maps and Lists

Use 1 or 2 integration tests to carry out something
- Claim a delegate key that you've blocked
  - must see warning and confirm that you get it
- Attempt new trust user you've already trusted
- Attempt new trust of your delegate key
- 