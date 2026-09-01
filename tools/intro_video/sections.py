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
import argparse, json, subprocess, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOC = HERE.parent.parent / 'doc' / 'intro_video' / 'sections.yaml'
CUES = HERE / 'cues'

# What annotate.js reads, and nothing else.
CUE_KEYS = ('prompter', 'zooms', 'beats')


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


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--list', action='store_true')
    p.add_argument('--cues', metavar='ID')
    p.add_argument('--check', action='store_true')
    p.add_argument('--card', metavar='ID', help="render this section's card")
    args = p.parse_args()
    doc, sections = load()

    if args.card:
        s = sections.get(args.card)
        if s is None:
            sys.exit(f"no section '{args.card}'. Try --list.")
        card = s.get('card')
        if not card:
            sys.exit(f"section '{args.card}' has no card")
        if 'words' in card:
            sys.exit(f"section '{args.card}' wants a word-by-word card; "
                     "card.js does not do those yet")
        out = HERE / 'out' / f"card_{args.card}.mp4"
        cmd = ['node', str(HERE / 'card.js'), str(out),
               str(card.get('hold', 2.0))] + [str(l) for l in card['lines']]
        print(' '.join(cmd))
        subprocess.run(cmd, check=True)
        return

    if args.list or not (args.cues or args.check):
        for name, video in doc['videos'].items():
            ids = video['sections']
            print(f"\n{name}: {video['title']}   ({len(ids)} sections)")
            for i, sid in enumerate(ids, 1):
                s = sections.get(sid)
                if s is None:
                    print(f"  {i:2}. {sid}  -- NOT IN sections:")
                    continue
                extras = [k for k in ('card', 'flash', 'announce', 'actions',
                                      'defer', 'todo') if s.get(k)]
                cues = [f'{len(s[k])} {k}' for k in CUE_KEYS if s.get(k)]
                print(f"  {i:2}. {s['title']}")
                print(f"      {s['status']:9} build={s['build']:14} "
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
