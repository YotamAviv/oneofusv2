# Language Inventory — Concepts, Phrases, Buzzwords

Extracted from [index.html](../../web/index.html), [talk.html](../../web/talk.html) (tech talk
teleprompter), and [phone_talk.html](../../web/phone_talk.html) (phone demo teleprompter).

Raw material for the intro video's bubbles, VO, and text cards — see
[script.md](script.md).

**How to rank.** Fill the `Rank` column: **M** = must have (the video fails without it),
**O** = optional (use if it fits the cut), **L** = later (save for the shorts series or the
website), **N** = no (cut it). Add notes in the last column as you go.

Source key: `I` = index.html, `T` = talk.html, `P` = phone_talk.html.

---

## A. Taglines and one-liners

The compressed stuff. Card and bubble candidates.

| Rank | Line | Src | Note |
| --- | --- | --- | --- |
| | "The Internet liberated lies and pornography. Crypto on the web can liberate trust." | I, T | Extended form on I: "Let's litter the Interweb with signed, authentic content instead." T's variant says "trust and reputation" |
| | "A network of the people, by the people, for the people." | I | Site tagline |
| | "I am who your network says I am. Everywhere." | I, P | P pairs it: "You are who my network says you are. / I am who your network says I am." |
| | "People not accounts" | I, T | |
| | "The Nerdster is public as the moon." | P | |
| | "The network must be ours." | P | |
| | "Not ONE-OF-US.NET's, not mine. Ours, yours!" | I | |
| | "Our own = everybody's, anybody's. Decentralized = yours." | T | |
| | "You're the center of your network." | I | |
| | "No dictators, but you dictate who grounds you to reality." | I | |
| | "Bottom line: You gotta believe." | T | |
| | "Get a crypto key, get recognized. Just in case.." | T | |
| | "Litter the Internet with statements signed by our own keys." | P, I, T | Recurs in all three |
| | "Digital signatures work. ChatGPT can't steal your Bitcoin." | I | The "why trust crypto" one-liner |

## B. Melodramatic expressions (the branded buzzwords)

T explicitly calls these out as a set: "Melodramatic expressions."

| Rank | Term | Src | Meaning as used |
| --- | --- | --- | --- |
| | **"Liberated Trust"** | I, P, T | Signed content is distributed and portable; verifiable no matter who serves it |
| | **"First Amendment 2.0"** / "Freedom of Speech 2.0" | I, P, T | Public key distribution is an *ability* to speak authentically, not a requirement |
| | **"Democracy 2.0"** | I, P, T | Decentralized organization; no center, no hierarchy |

## C. Core mechanism concepts

The things the video has to actually *show*, not just say.

| Rank | Concept | Src | Shortest phrasing found |
| --- | --- | --- | --- |
| | **Vouch** | all | "Sign other folks' public keys using your private key." / "human, capable, acting in good faith" |
| | **Identity layer** | T, P | Sign a statement referencing someone's public key with your private key; publish it where all your key's statements can be found |
| | **Delegate layer / delegate key** | T, P | "It wouldn't work out well to give 100's of services your private identity key." Disposable pair, published as representing you, handed to the service |
| | **Point of View (PoV)** | all | "Decentralized from your Point of View, not spam detection or moderation by a service" |
| | **Trust modes** (permissive / standard / strict) | T | `permissive: '1'`, `standard: '1-1-2'`, `strict: '1-2-2-3'` |
| | **Signature chain / whitelisted content** | T | "Complete cryptographic digital signature chain from your identity key to all the whitelisted content" |
| | **Interpreted vs. raw statement** | P, T | The FYI toggle — "what it means" vs. "what it actually is" |
| | **FYI mode** | T | "Feature exists specifically for this educational demo" |
| | **Block / follow the person, not the account** | T, P | "follow Andrew *the person*" — "Any service can find, validate, and honor that" |
| | **Revoke a delegate key** | T | "The demo phone sort of gave the Nerdster an account, not the other way around" |
| | **Invitation (remote vouch)** | T, P | For when you're not in the same room |
| | **Conflict detection** | T, I | "just starts building and notifies when encountering conflicts" |
| | **Moniker** | T | "poor choices for monikers (eg. Mom, Wife)" |

## D. The "no accounts" cluster

Repeats everywhere; probably deserves one crisp form rather than four.

| Rank | Line | Src |
| --- | --- | --- |
| | "You don't have an account with ONE-OF-US.NET. If anything, you have an account with those who vouched for you." | I, T |
| | "You don't have an account with Nerdster.org. If anything, it has an account with you." | I, T |
| | "No account. No password." | script |
| | "What we didn't do: pick a username, password; authenticate with a service to do something as ourselves." | T |
| | "Only keys we own and control." | P |
| | "No special access." — "The Nerdster doesn't know what's used to sign in. ONE-OF-US.NET doesn't know or restrict what reads signed content it's published." | I |
| | "All 3 apps are not connected, have no special access to each others' data." | T, P |

## E. The "why should I care" arguments

Concrete, non-technical, audience-facing.

| Rank | Argument | Src | Note |
| --- | --- | --- | --- |
| | **The Uber/Lyft driver** — 4.7 on one, 4.9 on the other. "He's one guy!" | I | The single best concrete argument in the corpus |
| | **The Airbnb host** — "If I enjoy my stay at your Airbnb, who's a good host: you or your Airbnb account?" | P | Same argument, tighter |
| | **The stranger's car** — "Do you want to get in a stranger's car because he has 4.8 stars, or because your own network trusts him?" | P (deferred) | Marked DEFER in source; strong for video |
| | **Incognito farmers' market** (Jones comic) — "If everyone went using incognito windows, no one would know who's who or who's even a person." | I | |
| | **"X is never going to leverage Facebook's network, right?"** | P | |
| | **They want this but can't do it** — "They can't do it because they don't get along" / "each seeks dominance" | I, T | Answers "why hasn't this happened already?" |

## H. Social / cultural aspirations

The soft end. Highest risk of sounding preachy on video; also the most memorable.

| Rank | Line | Src |
| --- | --- | --- |
| | **"Out:** central censorship, powerful silos, algorithmic manipulation, low attention span, psychotic derangement, max vitriol. **In:** connection, compassion, understanding, growth, peace, prosperity, joy." | I | Card-shaped as-is |
| | "Would you be more open to listening to folks you disagree with if you recognized they were, after all, 'one of us'?" | I |
| | "What about if they were six degrees removed (but through IRL human connections)?" | I |
| | "If all of us had the choice to say something as an account or as ourselves — would you devalue what accounts say?" | I |
| | "Restraint, Reputation, Civility, Respect, Truth.." | I |
| | "Respectful, authentic online social experience" | T |
| | "I am not my phone number, my email address, my Facebook account, my browsing history, my purchases, my prescription medications.. I'm the guy you met on that river trip." | I | **"You, IRL"** |
| | "Our network already exists. We're not trying to build it — just writing it down authentically." | I |
| | "In case you're disrespected by folks you do respect, then that might be on you. Shape up." | I |
| | "(nerd save us ;)" | I | House voice |

## I. The hard-problem admission

Credibility move — the corpus is unusually willing to say what doesn't work yet.

| Rank | Line | Src |
| --- | --- | --- |
| | "Given a pile of vouches, some legitimate, some bogus, who's legit? Tough problem." | T |
| | "How can we expect them to solve spam and disinformation for us if we don't help them differentiate ourselves from bots?" | T |
| | "It's easier starting with you, for your PoV. But it's still hard." | T |
| | "The Nerdster: puny and weak (not the killer app)" / "rudimentary" / "a starting point" | T, I |
| | "Serious services will compete on how well they compute the network." | T |
| | "Anyone can mint a thousand keys." | script |

## J. Product framing

| Rank | Item | Src |
| --- | --- | --- |
| | **ONE-OF-US.NET phone app** — "Simple and complete, capable of building humanity's identity network" / "builds network, sufficient (for starters;)" | I, T |
| | **Nerdster** — "demo / proof of concept / reference implementation", "public as the moon" | I, P |
| | **HabloTengo** — "Share contact info privately with your trusted network" | I, T |
| | "Open, closed, private, or public as the moon — the network underneath is the same." | script |
| | "The Nerdster doesn't have to have its own messenger — we have plenty of those — as long as we know who's who." | P |
| | "All 3 are demos for the paradigm. But they're usable." | P |
| | "Like someone's post? Check if they're on HabloTengo. Follow them on X, send a DM. They're ONE-OF-US." | P |
| | **Call to action:** vouch for someone / get vouched / do something on the Nerdster | I |
| | "Wanted: marketing help, marketing lead. Promote, shape, entirely rebrand; nothing is off the table." | I |

---

## Notes on the corpus

- **"Heterogeneous" is on the way out.** talk.html carries `s/heterogeneous/open` as an
  editing note; index.html still uses it in the open-web section. Pick one for the video —
  "open" is the safer word for a general audience.
- **"Crypto" is ambiguous.** Every use here means public-key cryptography, but a cold viewer
  hears cryptocurrency. The Bitcoin line ("ChatGPT can't steal your Bitcoin") leans into the
  confusion deliberately; everything else may need "cryptographic" spelled out once.
- **Three registers coexist:** technical (delegate keys, signature chains), plainspoken (the
  Uber driver), and manifesto (Democracy 2.0, the liberation line). The video can carry at
  most two. Which two is the ranking decision that matters most.
- **The comics have no video equivalent yet.** They're the corpus's funniest material and
  currently live only as static images on the site.
