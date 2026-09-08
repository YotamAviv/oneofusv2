# Two kinds of blocking, and why they are not the same act

The brief for two videos, written down because the distinction is the whole point
and it is easy to shoot something that blurs it. Yotam, 8 Sep 2026; this file is
his instruction written up, not a summary of what has been built.

The storyboards are `video/oneofus_block_alt.yaml` and
`video/nerdster_affinity_alt.yaml` — SEPARATE FILES, on purpose. Both videos start
from the same world (the state `crypto_teaser` leaves), and neither follows the
other. Two sections in one file would break that twice over: `sections.py`
restores each section from the one BEFORE it in its file, so the second would
start from a world where Eyal is already blocked, and `--assemble` joins a file's
sections in order into one video.

---

## The distinction

**The identity network answers one question: is this a person?** Not whether they
are pleasant, or right, or worth listening to. A vouch says "I know this human".
A block says "this is not a human I will stand behind" — a bot, a spammer, a
stolen key, a fake.

**An affinity network answers a different question: do I want to hear from them?**
That is a matter of taste, and taste is per context. You might trust somebody to
rent your room and not to fix your car or recommend music.

Blocking on the identity network because you disagree with somebody is a category
error, and the first video says so out loud while doing it. The second video shows
the thing you should have done instead.

The mechanism is shared, which is what makes this worth two videos rather than
one: both are signed statements on the same open network, readable by anybody.
The difference is what they *claim*.

---

## Video 1 — identity blocking (`oneofus_block`)

Already shot. What this brief adds to it:

1. **The reason is "poor hygiene".** Typed into the REASON field on the app's New
   Block dialog, so the block has a stated motive and the motive is visibly not
   about humanity.
2. **Say that it is reprehensible.** The identity network is for knowing who is
   human — not who is nice, and not who we like. We do not block people there for
   disagreeing with us. That is what affinity networks are for, and it is the
   next video.
3. **Say why the block happens on the phone.** The Nerdster does not hold the
   identity key and therefore *cannot* express an identity vouch or block. It can
   only hand the intention to the app that does. This is not a UI choice; it is
   the architecture.

## Video 2 — affinity blocking (`nerdster_affinity`)

Not yet shot. The whole sequence, in order:

1. **Block Tom for the `<nerdster>` context.** Done in NodeDetails, which is
   where follow contexts are changed.

   "Talks too much" is the reason, and it is said in the NARRATION ONLY. The
   follow editor has no comment field: `_saveChanges` calls
   `ContentStatement.make` without one, and Yotam's call is that comments are
   excessive on a follow statement. Do not add one to the Nerdster to make this
   line land -- say it out loud instead.
2. **Say that this one is NOT reprehensible.** The demo is using the identity
   network to *name* Tom — that part is the identity layer doing its job — and
   then saying, separately, that it is not interested in his opinions.
3. **Say that this is a Nerdster thing, not an identity-network thing.** And then
   the honest complication: it is all public anyway, so other apps can see that
   the demo blocked Tom for a general-interest follow context. Publishing where
   everyone can read it is the point of the network, not a leak in it.
4. **The Nerdster refreshes itself**, and a lot of content disappears.
5. **Switch the follow context control at the top from `<nerdster>` to
   `<identity>`.** The content comes back. `<identity>` is "follow everyone who is
   a person" — which we probably do not want most of the time. Existing and being
   human does not mean we care what you say.
6. **Pick Eyal and express an explicit `<nerdster>` follow for him.**
7. **Use the follow-network picker at the top of the graph view** to show two
   things at once: we follow Eyal *directly* in `<nerdster>`, and we still know he
   is human two hops away through Tom — even though Tom is no longer in our
   `<nerdster>` network. Tom is still a person; we just stopped listening.
8. **Back to the content view.** On the `<nerdster>` follow network we see Eyal's
   contributions and not Tom's.
9. **Close on a card** about decentralization and about building follow networks
   on top of an identity network: you may trust a guy to rent your room but not to
   fix your car or recommend music.

---

## Why this is two videos and not one

They could be one, and it would be worse. Video 1 ends on a wrong act stated
plainly as wrong; that is a strong place to stop, and it sets up a question. Video
2 answers it. Splicing them makes one long video whose first half is a mistake the
viewer has to hold in mind while the second half unwinds it.
