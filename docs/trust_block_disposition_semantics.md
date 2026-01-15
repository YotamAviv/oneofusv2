# Trust / Block Disposition Semantics Specification

This document defines the behavior and state transitions for interpersonal dispositions (Trust, Block, and Clear).

## Verbs and Definitions

Trust / block is supposed to apply to keys being used as identities, presumably those of humans.
They do not have "domain".

### Validation always applies.
| Verb | Meaning | Requirements |
| :--- | :--- | :--- |
| **TRUST** | Subject is "human, capable of acting in good faith". Appears in PEOPLE screen
- moniker required
- comment optional
| **BLOCK** | Subject key is in the category of "Bots, spammers, bad actors, careless, confused, ..".
- no moniker (not allowed to name non-humans)
- comment optional
| **CLEAR** | "Say nothing." Nullifies previous statements about this subject. | None |
- no fields at all as clear statements are only there to overwrite previous statements (singular disposition), and we clear them from our collections as well.


### Discovery (Scan)
When a new key is scanned via QR:
If it's not a new key, that is, if we've already stated something about it (necessarily a trust or a block), then show it in the Trust/Block/Clear dialog prefilled with the fields we used and allow the user to change it in any way they want (trust to block, block to trust, or either of those to clear).
All validations apply.

If it is a new key, then assume the user wants to trust this key.
Do allow the user to express a block instead.
Do not offer to clear.
All validations apply.

### Management on the PEOPLE screen
The keys on the PEOPLE are there because they're necessarily trusted.
We do not show keys the user has blocked on that screen.

If the user clicks the block icon, then they're only allowed to block.
If the user clicks the edit icon, then they can edit moniker and comment but can't change the verb.
If the user clicks the clear icon, then they can only clear. Do show the user the existing moniker and comment used, but only allow clear (not edit the exiting trust, not change the existing trust to block).
Do not allow "submit" whatever the verb may be unless a change is being made (updated moniker, comment, or verb).
All validations apply.

## Fundamentals
- We only have the latest statement by a key about a subject.
We don't need to sort or make these distinct. We already have only distinct Issuer-Subject pairs.
- `clear` statements are used to leverage our singular dispostion and are then cleared themselves. They are to used to make it as though nothing was ever stated at all.
