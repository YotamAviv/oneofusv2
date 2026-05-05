# Delegate Disposition Semantics Specification

This document defines the behavior and state transitions for delegate / delegate with revokeAt / clear.

## Verbs and Definitions

Delegates are keys authorized to act on behalf of an identity for a specific **domain**.
Unlike people (who are identified by monikers), delegates are identified strictly by their domain.

### Validation always applies.
| Verb | Meaning | Requirements |
| :--- | :--- | :--- |
| **DELEGATE** | Subject (delegate key) represents me on a specific domain. Appears in SERVICES screen. | - domain required<br>- revokeAt allowed, meaningful, and complicated<br>- no moniker allowed |
| **CLEAR** | "Say nothing." Nullifies previous statements about this delegate. | None |
- no fields at all as clear statements are only there to overwrite previous statements (singular disposition), and we clear them from our collections as well.

## How revoking delegate keys works
We have singular dispostion.
To express that you're revoking a delegate, you state that this delegate represents you on that service and you also include a revokeAt statement token (which can be "<since always>").
Doing that will hide (singular dispostion) any former statement by you about this delegate key.

## Discovery (Seamless Sign-In / Deep Link)
This topic is covered elsewhere.
Signing in will not bring up the edit delegation dialog.

## Displaying your delegate keys on the SERVICES screen
Show all keys for which your identity key has delegated (verb="delegate", subject=delegate key) whether or not there's also a revokeAt in that statement.
It is possible for users to end up with multiple delegate keys (revoked or not) for the same domain.

For delegate keys that have been delegated using a statement that does not contain "revokeAt":
- show a **blue key** icon in the top right.
If the delegate statement does contain "revokeAt":
- show a **blue crossed out key** icon in the top right.

Statements that delegate (use the verb "delegate") are restricted as follows:
- domain: required
- revokeAt: optional and complicated
- moniker: not allowed, no such thing
- comment: don't show anything related to comment.

Display the domain where the moniker is for trusting people.

The "revokeAt" value is the statement token of the last valid statement signed by that key.
If there is no statement token matching the "revokeAt" value, then services should consider that delegate key revoked entirely.
Since the string "<since always>" is not going to match any statement tokens, we use that to explicitly revoke a delegate key entirely.
And so a delegate key is either active, revoked entirely, or partially revoked.
We'll display both revoked entirely, or partially revoked the same way: **blue crossed out key** icon in the top right

## Editing / Clearing delegate keys
We'll display 
- a gears icon to edit a delegate key (state a new delegate statement about it).
- Similar functionality to the PEOPLE trust clear, but the semantics are different.

When a user clicks on the gears icon to edit:
- (domain remains fixed. It should be should be shown but cannot be changed)
- the current revocations status should be displayed

Active: (revokeAt is not in the statement)
Fully Revoked: (revokeAt == "<since always>")
Revoked at Last Valid Statement: (revokeAt != null && revokeAt != "<since always>")

In case of "Revoked at Last Valid Statement":
- display the value of revokeAt using a small, fixed width font
- display a QR scan icon to scan that value using your phone.

In case of "Fully Revoked" or "Active":
- do not show the revokeAt value, collapse or hide that section entirely.

The user should be able to freely switch among these 3 states.
He should be alowed to choose "Revoked at Last Valid Statement" without using the QR scan functionality to get a value in there.
If the scanner finds a string, use that string.
If the scanner finds a JSON string, tokenize that JSON to a string and use that.

Processing and validating the revokeAt value:
1) If the scanned value looks like JSON, accept it, compute the token for that JSON, and use that for revokeAt.
2) If the scanned value looks sha1-ish (like "7e8a5966b9ebc0df106d439c11512ce51baa513f"), accept it and use that for revokeAt.
Otherwise, reject that value. Do not allow "Revoked at Last Valid Statement" without a sha1-ish revokeAt value.
