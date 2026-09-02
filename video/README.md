# The videos, as sections

This directory is the **copy** — what each video says, in order, and what is on
screen while it says it. It is source, not documentation: `sections.py` reads it
and generates `tools/video/cues/*.json`, which `annotate.js` eats.

The prose *about* making videos — rigs, gotchas, what a shoot script costs to
write — is in [../doc/video/](../doc/video/), and
[capture_manual.md](../doc/video/capture_manual.md) is the one to read first.

| file | video |
| --- | --- |
| [intro.yaml](intro.yaml) | the short one: Our Own Open Decentralized Identity Network |
| [how_it_works.yaml](how_it_works.yaml) | the longer one, where things get shown slowly |

```bash
python3 tools/video/sections.py --list            what exists, and its state
python3 tools/video/sections.py --cues <id>       writes cues/<id>.json
python3 tools/video/sections.py --cues all        every section that has cues
python3 tools/video/sections.py --check           cues/ matches these files
python3 tools/video/sections.py --card <id>       renders a section that IS a card
python3 tools/video/sections.py --build <id>      shoots and finishes a section
```

**One file per video, and the order of `sections:` is the running order.** Section
ids must be unique across every file here, because the cue files they generate
share one directory. `sections.py` refuses duplicates rather than picking a
winner — it used to pick one silently, and a section went missing for a day.

A section belongs to one video. If one is ever wanted in two, do not copy it:
that is the point at which these files need a shared third one, and a duplicate
would drift within a week.

## Four things can be on screen

| key | what it does |
| --- | --- |
| `prompter` | the running commentary along the bottom, scrolling as the take goes |
| `beats` | the video **stops** — pause bars, everything dimmed but one spotlit thing, and a bubble pointing at it |
| `cards` | the video **stops** and a screen of text takes over. Same act as a beat, different still. `lines:` renders the first large and the rest smaller; `words:` makes them arrive one at a time and stay. A section whose card *is* the section (no take) has exactly one, and `--card` renders it. |
| `zooms` | a punch-in, for the moments made of small text |
| `flash` | a buzzword, bright, then gone. **Not built yet.** |

## Saying when

All of them say WHEN the same way, so a card can land anywhere in a section:
`t: 0` is its start, a late mark is its end, any mark is somewhere between.

**WHEN is a mark the take recorded, not a number of seconds** — `at: tap_publish`.
Reshooting moves every number and none of the names. `after:` offsets from the
mark; a plain `t:` still works where nothing suitable is named. The marks a take
records are in its `tools/video/out/<stamp>.marks.json`.

Two things about marks are worth knowing before trusting one:

- **A mark must come from the thing it names.** A mark set by a blind sleep after
  a tap, rather than by the wait that detects the result, sits later than the
  event — and every cue anchored on it inherits the error.
- **`annotate.js` refuses any cue past the end of the take.** It used to drop
  prompter lines and zooms in silence, which is how a section was built and
  shipped without its closing line.

## The unfriendly part

A beat's `anchor` and `spotlight`, and a zoom's `to`, are **pixel coordinates on
a particular take**. They are the one thing in these files that isn't
human-friendly. Set them once by looking at a frame; remeasure when the app's
layout moves. They cannot be written before there is a take to measure.

## Status

`status:` is for people, not for the tools: `to_build`, `built`, or `blocked`
with a note saying why. Everything else a section can carry — `actions`,
`announce`, `defer`, `todo` — is also for people, and for whoever builds the
section next.
