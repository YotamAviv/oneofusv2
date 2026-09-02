#!/usr/bin/env python3
"""Read the sections doc, and write what the tools eat.

    python3 sections.py --list             what exists, and its state
    python3 sections.py --cues nerdster    writes cues/nerdster.json
    python3 sections.py --cues all         writes one for every built section
    python3 sections.py --check            cues/ matches the doc
    python3 sections.py --card preamble    renders that section's card to out/

doc/intro_video/sections.yaml is where the copy lives, because a person editing
what the video says should not have to edit JSON, and because prose wants
comments and line breaks that JSON has no room for. annotate.js still eats
cues/*.json; this is the step between.

prompter, beats and zooms become cue files, which is what annotate.js reads.
Cards are rendered straight from here by card.js -- the card in the preamble is
the one screen in the video made of nothing but words, and its words had been
sitting in a shell script rather than in the doc that is supposed to hold them.

The rest (flashes, actions, announce, defer, todo) is for people, and for
whoever builds those sections next.
"""
import argparse, json, os, re, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOC = HERE.parent.parent / 'doc' / 'intro_video' / 'sections.yaml'
CUES = HERE / 'cues'

# What annotate.js reads, and nothing else. Cards are in here because a card at
# a mark is spliced into the take exactly as a beat is -- only a card rendered
# on its own, outside any take, goes through --card.
CUE_KEYS = ('prompter', 'zooms', 'beats', 'cards')


def load():
    try:
        import yaml
    except ImportError:
        sys.exit('needs PyYAML:  pip install pyyaml')
    doc = yaml.safe_load(DOC.read_text())
    sections = {s['id']: s for s in doc['sections']}
    return doc, sections


def cue_file(section):
    """The cue file for one section, or None if it has nothing to annotate."""
    cues = {k: section[k] for k in CUE_KEYS if section.get(k)}
    if not cues:
        return None
    out = {'_comment': [
        f"Generated from doc/intro_video/sections.yaml -- section '{section['id']}'.",
        "Edit the copy THERE, not here, and run:",
        f"  python3 tools/intro_video/sections.py --cues {section['id']}",
    ]}
    out.update(cues)
    return out


def write_cues(section, quiet=False):
    data = cue_file(section)
    if data is None:
        if not quiet:
            print(f"  {section['id']}: nothing to annotate")
        return None
    path = CUES / f"{section['id']}.json"
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    counts = ', '.join(f'{len(data[k])} {k}' for k in CUE_KEYS if k in data)
    print(f"  {path.relative_to(HERE)}  ({counts})")
    return path


def render_card(sid, card, out):
    """One card to a clip. `words:` arrive one at a time; `lines:` is a heading
    and the rest."""
    if 'words' in card:
        args = ['--words'] + [str(w) for w in card['words']]
    elif 'lines' in card:
        args = [str(l) for l in card['lines']]
    else:
        sys.exit(f"'{sid}' has a card with neither words: nor lines:")
    run(['node', 'card.js', out, card['hold']] + args)


def run(cmd, **kw):
    print('  ' + ' '.join(str(c) for c in cmd))
    subprocess.run([str(c) for c in cmd], check=True, cwd=HERE, **kw)


def newest_take(stem):
    """The take a shoot script just wrote -- the raw one, not its derivatives."""
    made = [p for p in (HERE / 'out').glob(f'{stem}_*.mp4')
            if not re.search(r'_(taps|composited|annotated)', p.name)]
    if not made:
        sys.exit(f"{stem} left no take in out/ -- did the shoot fail?")
    return max(made, key=lambda p: p.stat().st_mtime)


def mark_seconds(video, mark):
    """Where a mark lands in the trimmed take, asked of lib/marks.js so the
    definition of that lives in exactly one place."""
    return subprocess.run(
        ['node', '-e', """
        const { loadMarks, TRIM_PAD } = require('./lib/marks');
        const m = loadMarks(process.argv[1]);
        const v = m[process.argv[2]];
        if (typeof v !== 'number') {
          console.error(`no mark "${process.argv[2]}" in that take`); process.exit(1);
        }
        console.log((v - TRIM_PAD).toFixed(2));
        """, str(video), mark],
        cwd=HERE, check=True, capture_output=True, text=True).stdout.strip()


def build(section):
    """Shoot a section and finish it, in the one order that works.

    Compositing precedes annotation: annotation splices cards and beats into the
    timeline and everything after them moves, while the composite resolves its
    window against the marks as recorded. Getting that backwards puts the footage
    seconds away from where it belongs and shows the emulator's rendered room
    instead, which is not obvious from the output -- it just looks wrong.

    Nothing here has a default. A section that does not say what it needs stops.
    """
    sid = section['id']
    out = HERE / 'out' / f'section_{sid}.mp4'
    how = section['build']

    if how == 'card':
        cards = section.get('cards')
        if not cards or len(cards) != 1:
            sys.exit(f"'{sid}' builds as a card but has "
                     f"{len(cards or [])} of them; it needs exactly one")
        render_card(sid, cards[0], out)
        print(f'\n  {out.relative_to(HERE)}')
        return

    if how.endswith('.sh'):
        # A section whose shape is its own -- the preamble joins three takes and
        # a card. The script takes its output path and owns the rest.
        run(['./' + how, out])
        print(f'\n  {out.relative_to(HERE)}')
        return

    if not how.endswith('.js'):
        sys.exit(f"'{sid}' has build: {how} -- expected 'card', a .js shoot "
                 "script, or a .sh that takes an output path")

    stem = how[len('shoot_'):-len('.js')] if how.startswith('shoot_') else how[:-3]
    run(['node', how])
    take = newest_take(stem)
    run(['node', 'overlay_taps.js', take])
    cur = take.with_name(take.stem + '_taps.mp4')

    comp = section.get('composite')
    if comp:
        for k in ('footage', 'window', 'hold', 'fade'):
            if k not in comp:
                sys.exit(f"'{sid}' composite is missing '{k}'")
        nxt = cur.with_name(cur.stem + '_composited.mp4')
        run(['./composite_scan.sh', cur, comp['footage'], comp['window'], nxt],
            env={**os.environ, 'HOLD': str(comp['hold']), 'FADE': str(comp['fade'])})
        cur = nxt

    if cue_file(section):
        run(['node', 'annotate.js', f'cues/{sid}.json', cur])
        cur = cur.with_name(cur.stem + '_annotated.mp4')

    trim = section.get('trim')
    if trim is None:
        sys.exit(f"'{sid}' does not say what to trim to. Every take opens with a "
                 "sync flash and a launch; `trim: <mark>` says where the section "
                 "actually starts.")
    at = mark_seconds(cur, trim)
    print(f'  trim to {trim} at {at}s')
    run(['ffmpeg', '-y', '-v', 'error', '-ss', at, '-i', cur,
         '-c:v', 'libx264', '-crf', '19', '-preset', 'medium', '-pix_fmt', 'yuv420p', out])
    print(f'\n  {out.relative_to(HERE)}')


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--list', action='store_true')
    p.add_argument('--cues', metavar='ID')
    p.add_argument('--check', action='store_true')
    p.add_argument('--card', metavar='ID', help="render this section's card")
    p.add_argument('--build', metavar='ID', help='shoot and finish a section')
    args = p.parse_args()
    doc, sections = load()

    if args.build:
        s = sections.get(args.build)
        if s is None:
            sys.exit(f"no section '{args.build}'. Try --list.")
        build(s)
        return

    if args.card:
        s = sections.get(args.card)
        if s is None:
            sys.exit(f"no section '{args.card}'. Try --list.")
        cards = s.get('cards')
        if not cards:
            sys.exit(f"section '{args.card}' has no cards")
        if len(cards) != 1:
            sys.exit(f"section '{args.card}' has {len(cards)} cards; --card renders a "
                     "section whose card IS the section. A card that lands inside a "
                     "take is spliced by annotate.js from the cue file instead.")
        card = cards[0]
        render_card(args.card, card, HERE / 'out' / f"card_{args.card}.mp4")
        return

    if args.list or not (args.cues or args.check):
        for name, video in doc['videos'].items():
            ids = video['sections']
            print(f"\n{name}   ({len(ids)} sections)")
            for i, sid in enumerate(ids, 1):
                s = sections.get(sid)
                if s is None:
                    print(f"  {i:2}. {sid}  -- NOT IN sections:")
                    continue
                extras = [k for k in ('flash', 'announce', 'actions',
                                      'defer', 'todo') if s.get(k)]
                cues = [f'{len(s[k])} {k}' for k in CUE_KEYS if s.get(k)]
                print(f"  {i:2}. {sid:22} {s['status']:9} build={s['build']:14} "
                      f"{', '.join(cues + extras)}")
        orphans = set(sections) - {i for v in doc['videos'].values() for i in v['sections']}
        if orphans:
            print(f"\nnot in any video: {', '.join(sorted(orphans))}")
        return

    if args.check:
        bad = 0
        for sid, s in sections.items():
            want = cue_file(s)
            path = CUES / f'{sid}.json'
            if want is None:
                continue
            have = json.loads(path.read_text()) if path.exists() else None
            if have != want:
                print(f"  {sid}: cues/{sid}.json is out of date")
                bad += 1
        print('cues match the doc' if not bad else f'{bad} out of date -- run --cues all')
        sys.exit(1 if bad else 0)

    CUES.mkdir(exist_ok=True)
    if args.cues == 'all':
        for s in sections.values():
            write_cues(s, quiet=True)
    else:
        s = sections.get(args.cues)
        if s is None:
            sys.exit(f"no section '{args.cues}'. Try --list.")
        write_cues(s)


if __name__ == '__main__':
    main()
