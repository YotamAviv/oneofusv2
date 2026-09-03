#!/usr/bin/env python3
"""Read the storyboards, and write what the tools eat.

    python3 sections.py --list             what exists, and its state
    python3 sections.py --cues nerdster    writes cues/nerdster.json
    python3 sections.py --cues all         writes one for every built section
    python3 sections.py --check            cues/ matches the doc
    python3 sections.py --card preamble    renders that section's card to out/

video/*.yaml is where the copy lives -- one file per video -- because a person
editing what the video says should not have to edit JSON, and because prose
wants comments and line breaks that JSON has no room for. annotate.js still
eats cues/*.json; this is the step between. The schema is in video/README.md.

prompter, beats and zooms become cue files, which is what annotate.js reads.
Cards are rendered straight from here by card.js -- the card in the preamble is
the one screen in the video made of nothing but words, and its words had been
sitting in a shell script rather than in the doc that is supposed to hold them.

The rest (flashes, actions, announce, defer, todo) is for people, and for
whoever builds those sections next.
"""
import argparse, hashlib, json, os, re, shutil, subprocess, sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
VIDEOS = HERE.parent.parent / 'video'
CUES = HERE / 'cues'

# What annotate.js reads, and nothing else. Cards are in here because a card at
# a mark is spliced into the take exactly as a beat is -- only a card rendered
# on its own, outside any take, goes through --card.
CUE_KEYS = ('prompter', 'zooms', 'beats', 'cards', 'flashes')

# How long a section's title holds before its footage starts.
TITLE_SECONDS = '1.0'


def load():
    """Every storyboard in video/, and every section in them, by id.

    Ids have to be unique across files because the cue files they generate share
    one directory. This used to resolve a duplicate silently -- last one wins --
    and a whole section went missing behind another that happened to sort later.
    Refuse instead, and say where both are.
    """
    try:
        import yaml
    except ImportError:
        sys.exit('needs PyYAML:  pip install pyyaml')
    videos, sections, seen = [], {}, {}
    files = sorted(VIDEOS.glob('*.yaml'))
    if not files:
        sys.exit(f'no storyboards in {VIDEOS}')
    for f in files:
        doc = yaml.safe_load(f.read_text())
        # Every file in video/ is a whole video: a mapping with a title and a
        # list of sections. Anything else here is a scratch file that someone
        # parked in the wrong directory -- a bare list of removed sections did
        # exactly that -- and without this the loader died on a TypeError deep
        # inside itself that said nothing about which file was at fault.
        if not isinstance(doc, dict) or 'sections' not in doc:
            sys.exit(f'{f.relative_to(HERE.parent.parent)} is not a video: every '
                     f'file in video/ needs a top-level `sections:` (this one is '
                     f'a {type(doc).__name__}). Move scratch files out of video/.')
        doc['file'] = f
        videos.append(doc)
        for s in doc['sections']:
            sid = s['id']
            if sid in seen:
                sys.exit(f"duplicate section id '{sid}': in {seen[sid].name} "
                         f"and {f.name}. Ids are shared across all of video/ "
                         f"because cues/ is one directory.")
            seen[sid] = f
            sections[sid] = s
    return videos, sections


def cue_file(section):
    """The cue file for one section, or None if it has nothing to annotate."""
    cues = {k: section[k] for k in CUE_KEYS if section.get(k)}
    if not cues:
        return None
    # Which edge the prompter sits on. It defaults to the bottom, and covers the
    # bottom 300px of the frame -- which is where an app puts its bottom bar. A
    # section that taps something down there has to move the prompter, or the
    # control and its tap indicator are both behind the band. annotate.js
    # refuses to build such a section rather than burying the tap silently.
    if section.get('prompter_at'):
        cues['prompter_at'] = section['prompter_at']
    out = {'_comment': [
        f"Generated from video/ -- section '{section['id']}'.",
        "Edit the copy THERE, not here, and run:",
        f"  python3 tools/video/sections.py --cues {section['id']}",
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


def check_device():
    """The three ways this emulator rots, checked before a take rather than
    diagnosed after one.

    Each of these has cost a debugging session already: an orphaned screenrecord
    left by a failed take, /data filling up because those orphans accumulate, and
    Chrome tabs piling up until the encoder is starved (which is what the 26.5s
    recording ceiling turned out to be -- doc/video/capture_manual.md §10).

    Orphans are killed, because that is cleanup. Low disk stops the build,
    because carrying on and failing later is how the last two were found.
    """
    def adb(*a):
        return subprocess.run(['adb', *a], capture_output=True, text=True).stdout.strip()

    pids = [x for x in adb('shell', 'pgrep', 'screenrecord').split() if x]
    if pids:
        print(f'  killing {len(pids)} orphaned screenrecord(s) from a failed take')
        subprocess.run(['adb', 'shell', 'pkill', '-INT', 'screenrecord'],
                       capture_output=True)

    df = adb('shell', 'df', '/data')
    free_pct = None
    for line in df.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 5 and parts[4].endswith('%'):
            free_pct = 100 - int(parts[4].rstrip('%'))
    if free_pct is not None:
        print(f'  /data: {free_pct}% free')
        if free_pct < 5:
            sys.exit('/data is nearly full. Takes will fail in confusing ways -- '
                     'clear out old recordings before shooting.')


def build_dir(sid):
    """A fresh, stamped directory for one build of one section.

    Everything that build makes lives here: the take, its marks, the
    intermediates, the scratch, the finished section and the manifest. The stamp
    is on the directory rather than on each file, so a lineage carries one date
    and derived names stay readable.
    """
    d = HERE / 'out' / sid / datetime.now().strftime('%Y%m%d-%H%M%S')
    if d.exists():
        sys.exit(f'{d} already exists -- two builds in the same second?')
    d.mkdir(parents=True)
    return d


def newest_take(where, stem):
    """The take a shoot script just wrote -- the raw one, not its derivatives."""
    made = [p for p in where.glob(f'{stem}*.mp4')
            if not re.search(r'_(taps|composited|annotated)', p.name)]
    if not made:
        sys.exit(f'{stem} left no take in {where} -- did the shoot fail?')
    return max(made, key=lambda p: p.stat().st_mtime)


# --- state, so the sections can run as a sequence ---------------------------
#
# The video is meant to play as one continuous story: the likes made in
# `nerdster` should still be there, unchanged, when `crypto_teaser` and
# `close_account` film them. Two things carry that state, and both are now
# saveable and restorable:
#
#   the phone  -- the keyring, over the app's filming-only export/import deep
#                 links (app_state.sh). The delegate key matters especially:
#                 a DIFFERENT delegate orphans every rating the old one signed.
#   the network -- the statement streams, which are append-only hash chains, so
#                 a snapshot of the head plus truncate --keep rewinds exactly
#                 (snapshot_statements.js).
#
# A successful shoot saves both into its own build directory, so every complete
# build carries the state of the world as it left it.
#
# WHAT THIS DOES NOT DO YET, and it is the interesting half. Several takes RESET
# things on purpose so that they can be re-shot in isolation:
#
#   shoot_vouch.js      wipes the app, to get a phone with no keys on it
#   shoot_signin.sh     truncates the delegate statements and mints a new key
#   shoot_nerdster.sh   truncates what it published last time, because a card it
#                       has already reacted to has no React button left
#
# Those resets are exactly what breaks continuity, and removing them needs each
# take to start from the previous section's state instead -- which is what the
# save below makes possible, but nothing yet consumes. Restoring is a deliberate
# act for now: `--restore <section>`.
def state_files(where):
    return (where / 'state.keys.json',
            where / 'state.statements.json',       # the identity, on one-of-us.net
            where / 'state.nerdster.json')         # its delegate, on nerdster.org


def save_state(section, where):
    """Record the phone and the network as this section left them.

    TWO STREAMS, not one. The identity's own statements live on one-of-us.net;
    the RATINGS -- the likes, the dismiss, the snooze that the video is actually
    about -- are published by the DELEGATE, into nerdster.org, under a token
    minted fresh at every sign-in. Snapshotting only the identity's stream
    preserved none of the history the sections build up, which showed as
    `crypto_teaser` opening the published statements and finding exactly one.
    """
    sid = section['id']
    keys, stmts, nerd = state_files(where)
    try:
        subprocess.run(['./app_state.sh', 'save', str(keys)], check=True, cwd=HERE)
    except (subprocess.CalledProcessError, OSError) as e:
        print(f'  (state: could not save the keyring -- {e})')
    token = demo_identity_token()
    for path_, args in ((stmts, ['--token', token, '--project', 'oneofus']),
                        (nerd, ['--delegate-of', token, '--domain', 'nerdster.org',
                                '--project', 'nerdster'])):
        try:
            out = subprocess.run(['node', 'snapshot_statements.js', *args, '--prod'],
                                 check=True, cwd=HERE, capture_output=True, text=True)
            path_.write_text(out.stdout)
        except (subprocess.CalledProcessError, OSError) as e:
            # A delegate that does not exist yet is normal early in the running
            # order; a broken snapshot of one that does is not, and says so.
            print(f'  (state: no snapshot for {path_.name} -- '
                  f'{getattr(e, "stderr", "") or e})'.strip())
    print(f'  state saved for {sid}')


def demo_identity_token():
    keys = json.loads((HERE / 'demo_identity.json').read_text())
    return next(iter(keys['demoTokens'].values()))


def restore_state(sid):
    """Put the phone and the network back to how a section left them.

    The phone first and the network last: the app reads the network on its next
    launch, so doing it the other way round leaves the app holding what it read
    before the rewind.
    """
    builds = sorted((HERE / 'out' / sid).glob('*/state.keys.json'))
    if not builds:
        sys.exit(f'no saved state for {sid}. Only builds shot since this existed '
                 'have any -- shoot it, or pick another section.')
    where = builds[-1].parent
    keys, stmts, nerd = state_files(where)
    print(f'  restoring from {where.relative_to(HERE)}')
    subprocess.run(['./app_state.sh', 'restore', str(keys)], check=True, cwd=HERE)
    token = demo_identity_token()
    for path_, args in (
            (stmts, ['--token', token, '--project', 'oneofus']),
            (nerd, ['--delegate-of', token, '--domain', 'nerdster.org',
                    '--project', 'nerdster'])):
        if not path_.exists():
            continue
        head = json.loads(path_.read_text())['streams']['statements']['head']
        if not head:
            print(f'  ({path_.name}: empty stream, nothing to rewind to)')
            continue
        subprocess.run(['node', 'truncate_statements.js', *args, '--prod',
                        '--keep', head], check=True, cwd=HERE,
                       env={**os.environ, 'I_MEAN_IT': 'yes'})


def write_manifest(section, where, video, take=None):
    """Say that this build finished, and what it was made of. WRITTEN LAST.

    Its existence is the definition of a complete build: --assemble looks for
    manifests, not for videos, so a build that died partway leaves nothing that
    can be mistaken for a section. The cue hash is what catches the quiet
    failure -- a section built before the copy changed still plays, and still
    says the old words.
    """
    sid = section['id']
    cues = CUES / f'{sid}.json'
    m = {
        'section': sid,
        'built': datetime.now().isoformat(timespec='seconds'),
        'video': str(video.relative_to(HERE)),
        'duration': float(subprocess.run(
            ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
             '-of', 'csv=p=0', str(video)],
            check=True, capture_output=True, text=True).stdout.strip()),
        'build': section['build'],
        'cues': cue_digest(sid),
        'take': str(take.relative_to(HERE)) if take else None,
    }
    path = where / f'{sid}.section.json'
    path.write_text(json.dumps(m, indent=2) + chr(10))
    return m


def cue_digest(sid):
    """A fingerprint of the copy a section was built from, or None if it has no
    cues. Compared later to spot a section older than the words it should say."""
    f = CUES / f'{sid}.json'
    if not f.exists():
        return None
    return hashlib.sha256(f.read_bytes()).hexdigest()[:16]


def end_seconds(annotated, at, after, head):
    """Where a section should STOP, in the annotated video's own timeline.

    `until:` names a point in the take. Splices at or before it are part of the
    section, so their holds count towards where it ends -- which is how a closing
    card becomes the last thing on screen instead of something the take carries
    on past. Their real lengths come from the timeline annotate.js writes, since
    a word-by-word card's is measured rather than declared.
    """
    t = float(mark_seconds(annotated, at)) + (after or 0)
    tl = annotated.with_name(annotated.stem + '.timeline.json')
    if not tl.exists():
        sys.exit(f'{tl.name} is missing -- annotate.js writes it, so this take '
                 'was annotated by an older version. Re-annotate.')
    held = sum(sp['hold'] for sp in json.loads(tl.read_text())['splices']
               if sp['t'] <= t + 0.001)
    return round(t + held - head, 3)


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


def drop_if_empty(where):
    """Remove a build directory that a failed build left with nothing in it.

    NOT error handling -- the failure still propagates untouched. It is only that
    build_dir() has to make the directory before the build can write into it, so
    a shoot that dies on its first step leaves a stamped directory holding
    nothing. Four of those piled up in out/crypto_teaser/ before anyone looked.

    A PARTIAL directory is kept. Half-written intermediates and the scratch that
    goes with them are the evidence you read to find out why a take failed, and
    stamped paths mean they are never in the way of the next attempt.
    """
    try:
        if not any(where.iterdir()):
            where.rmdir()
            print(f'  removed empty {where.relative_to(HERE)}')
    except OSError:
        pass


def previous_section(sid):
    """The section before this one in its video's running order."""
    videos, _ = load()
    for doc in videos:
        ids = [s['id'] for s in doc['sections']]
        if sid in ids:
            i = ids.index(sid)
            return ids[i - 1] if i > 0 else None
    return None


def build(section, continue_from_previous=True):
    """Shoot a section, and clear up after it if it leaves nothing behind.

    THE SECTIONS RUN AS A SEQUENCE. Before shooting, the world is put back to
    how the PREVIOUS section left it -- the phone's keyring and both statement
    streams. That is what makes the video continuous: the ratings made in
    `nerdster` are still there, unchanged, when `crypto_teaser` opens the
    published statements and when `close_account` watches one disappear.

    It also replaces the resets those takes used to do for themselves. Rewinding
    to the previous section's head removes what THIS section published last time
    -- so a card it already reacted to has its React button back -- while
    leaving everything earlier sections published alone. `--all` did the first
    job by doing the second one too.
    """
    where = build_dir(section['id'])
    if continue_from_previous:
        prev = previous_section(section['id'])
        if prev and list((HERE / 'out' / prev).glob('*/state.keys.json')):
            print(f'  continuing from {prev}')
            restore_state(prev)
        elif prev:
            print(f'  ({prev} has no saved state; starting from whatever is on '
                  'the device)')
    try:
        _build(section, where)
    except BaseException:
        drop_if_empty(where)
        raise


def recut(section):
    """Re-finish a section's newest take in a build of its own.

    The take is COPIED into a new stamped directory rather than being finished
    in place: the old build stays exactly as it shipped, so the two can be put
    side by side, and a re-cut that fails leaves the good one alone.
    """
    sid = section['id']
    how = section['build']
    # A .sh section's post-production is overlay_taps then annotate -- a strict
    # subset of finish() -- so it can be re-cut like any other, as long as it
    # shot ONE take of its own. build_preamble.sh joins three takes and a card
    # and has no `<id>.mp4` to re-cut; it says so below rather than here,
    # because the take is what decides.
    stem = (how[len('shoot_'):-len('.js')] if how.startswith('shoot_')
            else how[:-3] if how.endswith('.js') else sid)
    takes = sorted((HERE / 'out' / sid).glob(f'*/{stem}.mp4'))
    if not takes:
        sys.exit(f"no take to re-cut in out/{sid}/ -- nothing matches {stem}.mp4. "
                 "Shoot it first with --build.")
    src = takes[-1]
    where = build_dir(sid)
    print(f'  re-cutting {src.relative_to(HERE)}')
    try:
        take = where / src.name
        shutil.copy2(src, take)
        marks = src.with_suffix('.marks.json')
        if not marks.exists():
            sys.exit(f'{src.relative_to(HERE)} has no {marks.name} beside it; '
                     'the take cannot be cut without its marks.')
        shutil.copy2(marks, where / marks.name)
        finish(section, where, take)
    except BaseException:
        drop_if_empty(where)
        raise


def _build(section, where):
    """Shoot a section and finish it, in the one order that works.

    Compositing precedes annotation: annotation splices cards and beats into the
    timeline and everything after them moves, while the composite resolves its
    window against the marks as recorded. Getting that backwards puts the footage
    seconds away from where it belongs and shows the emulator's rendered room
    instead, which is not obvious from the output -- it just looks wrong.

    Nothing here has a default. A section that does not say what it needs stops.
    """
    sid = section['id']
    # NOT <id>.mp4. A shoot script names its take after itself, so for every
    # section whose id matches its take -- vouch, nerdster, crypto_teaser -- the
    # finished section was written straight over the raw footage it came from.
    # The take was gone by the end of its own build, which surfaced later as
    # find_flash reporting "no clear flash": it was reading the annotated,
    # trimmed section and looking for a sync flash that had been cut off.
    out = where / 'section.mp4'
    how = section['build']
    # Everything the build shells out to writes in here, so a section's take,
    # intermediates, scratch and finished video stay together and nothing needs
    # to guess where anything went.
    env = {**os.environ, 'BUILD_DIR': str(where)}

    if how == 'card':
        cards = section.get('cards')
        if not cards or len(cards) != 1:
            sys.exit(f"'{sid}' builds as a card but has "
                     f"{len(cards or [])} of them; it needs exactly one")
        render_card(sid, cards[0], out)
        write_manifest(section, where, out)
        print(f'\n  {out.relative_to(HERE)}')
        return

    if how.endswith('.sh'):
        # A section whose shape is its own -- the preamble joins three takes and
        # a card. The script takes its output path and owns the rest.
        check_device()
        run(['./' + how, out], env=env)
        save_state(section, where)
        write_manifest(section, where, out)
        print(f'\n  {out.relative_to(HERE)}')
        return

    if not how.endswith('.js'):
        sys.exit(f"'{sid}' has build: {how} -- expected 'card', a .js shoot "
                 "script, or a .sh that takes an output path")

    stem = how[len('shoot_'):-len('.js')] if how.startswith('shoot_') else how[:-3]
    check_device()
    run(['node', how], env=env)
    # RIGHT AFTER THE CAMERA, not after post-production: this is the state the
    # world is in because of the take, and --recut must not overwrite it with
    # whatever the device happens to hold days later.
    save_state(section, where)
    finish(section, where, newest_take(where, stem))


def finish(section, where, take):
    """Everything after the camera: taps, composite, annotation, trim, manifest.

    Split out from the shoot so a take can be re-cut without being re-shot.
    Post-production is where most of the mistakes are, and they are not always
    visible when they happen: a sync flash read off the take's dim opening put
    every tap and highlight in `invite` 5.4s out of place on footage that was
    perfect. Reshooting to fix a cut also costs the state the take ran against,
    which for several sections cannot be reproduced without reshooting sign-in.
    """
    sid = section['id']
    out = where / 'section.mp4'
    env = {**os.environ, 'BUILD_DIR': str(where)}
    run(['node', 'overlay_taps.js', take])
    cur = take.with_name(take.stem + '_taps.mp4')

    comp = section.get('composite')
    if comp:
        for k in ('footage', 'window', 'hold', 'fade'):
            if k not in comp:
                sys.exit(f"'{sid}' composite is missing '{k}'")
        nxt = cur.with_name(cur.stem + '_composited.mp4')
        run(['./composite_scan.sh', cur, comp['footage'], comp['window'], nxt],
            env={**env, 'HOLD': str(comp['hold']), 'FADE': str(comp['fade'])})
        cur = nxt

    if cue_file(section):
        run(['node', 'annotate.js', f'cues/{sid}.json', cur])
        cur = cur.with_name(cur.stem + '_annotated.mp4')

    trim = section.get('trim')
    if trim is None:
        sys.exit(f"'{sid}' does not say what to trim to. Every take opens with a "
                 "sync flash and a launch; `trim: <mark>` says where the section "
                 "actually starts, and `trim: none` says it starts where "
                 "overlay_taps left it.")
    if trim == 'none':
        # overlay_taps has already cut the head to the sync flash, and for some
        # sections that IS the start. Said out loud rather than left blank, so
        # the difference between "starts here" and "nobody decided" stays
        # visible -- the .sh sections used to trim by saying nothing.
        run(['ffmpeg', '-y', '-v', 'error', '-i', cur, '-c:v', 'libx264', '-crf', '19',
             '-preset', 'medium', '-pix_fmt', 'yuv420p', out])
        write_manifest(section, where, out, take)
        print(f'\n  {out.relative_to(HERE)}')
        return
    at = mark_seconds(cur, trim)
    print(f'  trim to {trim} at {at}s')
    cut = []
    until = section.get('until')
    if until:
        keep = end_seconds(cur, until, section.get('until_after'), float(at))
        if keep <= 0:
            sys.exit(f"'{sid}' until: {until} lands before trim: {trim}")
        print(f'  end at {until}+{section.get("until_after") or 0} -- keeping {keep}s')
        cut = ['-t', str(keep)]
    run(['ffmpeg', '-y', '-v', 'error', '-ss', at, '-i', cur, *cut,
         '-c:v', 'libx264', '-crf', '19', '-preset', 'medium', '-pix_fmt', 'yuv420p', out])
    write_manifest(section, where, out, take)
    print(f'\n  {out.relative_to(HERE)}')


def newest_build(sid):
    """The most recent COMPLETE build of a section, or None.

    Complete means a manifest, which is written last and only on success. A
    build that crashed leaves a directory full of half-finished files and no
    manifest, and is therefore invisible here rather than something to be
    quietly stepped over.
    """
    found = []
    for m in sorted((HERE / 'out' / sid).glob('*/*.section.json')):
        try:
            d = json.loads(m.read_text())
        except json.JSONDecodeError:
            sys.exit(f'{m} is not readable JSON. A build wrote it badly; delete it.')
        if not (HERE / d['video']).exists():
            sys.exit(f"{m} names a video that is not there: {d['video']}")
        found.append((m.parent.name, d))
    return max(found, default=None, key=lambda f: f[0])


def title_clip(section, dest):
    """One second of the section's title, to open it with.

    Rendered by card.js, the same thing that renders a card section, so a title
    and a card look like the same video rather than two different ones.
    """
    title = section.get('title')
    if not title:
        sys.exit(f"'{section['id']}' has no title:. Every section needs one -- it "
                 "opens the section on screen and names its YouTube chapter.")
    run(['node', 'card.js', dest, TITLE_SECONDS, title, '--no-fade'])
    return dest


def assemble(videos, name, extra, stale_ok=False):
    """Join a video's sections in order, and refuse if any of them is missing.

    THIS DOES NOT ASSEMBLE WHAT IT CAN. A cut with sections silently left out
    looks finished and is not, which is exactly what happened when a partial
    join got called "intro_preview" and reported as a result. Say what is
    missing and stop.
    """
    doc = next((d for d in videos if d['file'].stem == name), None)
    if doc is None:
        sys.exit(f"no video '{name}' in {VIDEOS}. Try --list.")

    chosen, missing, stale = [], [], []
    for sec in doc['sections']:
        sid = sec['id']
        got = newest_build(sid)
        if got is None:
            missing.append(sid)
            continue
        stamp, man = got
        if man.get('cues') != cue_digest(sid):
            stale.append(f"{sid} (built {man['built']} from older copy)")
        chosen.append((sid, stamp, man))

    for line in stale:
        print(f'  STALE    {line}')
    if missing or (stale and not stale_ok):
        for sid in missing:
            print(f'  MISSING  {sid}: no complete build in out/{sid}/')
        sys.exit(f"\n{name} is not ready: {len(missing)} section(s) unbuilt, "
                 f"{len(stale)} built before the copy changed."
                 + ('\n  --stale-ok assembles anyway, with the older words.'
                    if stale and not missing else ''))
    if stale:
        print(f'  --stale-ok: assembling with {len(stale)} section(s) that say '
              'what they said before the copy changed.')

    stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    out = HERE / 'out' / f'{name}_{stamp}.mp4'
    work = out.with_suffix('.work')
    if work.exists():
        sys.exit(f'{work} already exists -- two assemblies in the same second?')
    work.mkdir(parents=True)

    # EVERY SECTION OPENS WITH ITS TITLE, for a second. It says what the next
    # stretch is about, and it gives the YouTube chapter something to start on --
    # a chapter that begins mid-sentence reads as a mistake.
    sections = {s['id']: s for d in videos for s in d['sections']}
    clips, at, bounds, ff = [], 0.0, [], [';FFMETADATA1']
    for sid, sstamp, man in chosen:
        card = title_clip(sections[sid], work / f'title_{sid}.mp4')
        # One line for the chapter, whatever the card does. A title may break
        # across lines on screen -- "HabloTengo!\nLet's talk" -- but a newline in
        # a chapter name splits the YouTube list in two and it stops parsing.
        chapter = ' '.join(sections[sid]['title'].split())
        held = float(subprocess.run(
            ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
             '-of', 'csv=p=0', str(card)],
            check=True, capture_output=True, text=True).stdout.strip())
        clips += [card, HERE / man['video']]
        # The chapter starts at the TITLE, not after it.
        end = at + held + man['duration']
        bounds.append({'section': sid, 'title': chapter,
                       'build': sstamp, 'start': round(at, 3), 'end': round(end, 3)})
        ff += ['[CHAPTER]', 'TIMEBASE=1/1000', f'START={int(at * 1000)}',
               f'END={int(end * 1000)}', f'title={chapter}']
        at = end
    meta = out.with_suffix('.chapters')
    meta.write_text(chr(10).join(ff) + chr(10))

    # What YouTube wants: one line per chapter in the description, "M:SS Title",
    # and the first one has to be 0:00 or it ignores the lot.
    def hhmmss(t):
        t = int(t)
        return f'{t // 3600}:{t // 60 % 60:02d}:{t % 60:02d}' if t >= 3600 \
               else f'{t // 60}:{t % 60:02d}'
    out.with_suffix('.youtube.txt').write_text(
        chr(10).join(f"{hhmmss(b['start'])} {b['title']}" for b in bounds) + chr(10))

    run(['./assemble.sh', out, extra or 'soundtrack.mp3'] + clips)
    run(['ffmpeg', '-y', '-v', 'error', '-i', out, '-i', meta,
         '-map_metadata', '1', '-codec', 'copy', out.with_name(out.stem + '_chaptered.mp4')])
    os.replace(out.with_name(out.stem + '_chaptered.mp4'), out)

    out.with_suffix('.sections.json').write_text(
        json.dumps({'video': name, 'built': stamp, 'sections': bounds}, indent=2) + chr(10))

    print(f'\n  {out.relative_to(HERE)}   {at:.1f}s, {len(chosen)} sections')
    for b in bounds:
        print(f"    {b['start']:7.2f}  {b['section']:22} {b['title']}")
    print(f"\n  chapters for YouTube: {out.with_suffix('.youtube.txt').relative_to(HERE)}")


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--list', action='store_true')
    p.add_argument('--cues', metavar='ID')
    p.add_argument('--check', action='store_true')
    p.add_argument('--card', metavar='ID', help="render this section's card")
    p.add_argument('--build', metavar='ID', help='shoot and finish a section')
    p.add_argument('--no-restore', action='store_true',
                   help='do not continue from the previous section (shoot standalone)')
    p.add_argument('--restore', metavar='ID',
                   help='put the phone and the network back to how a section left them')
    p.add_argument('--recut', metavar='ID',
                   help='re-finish the newest take of a section, without reshooting')
    p.add_argument('--assemble', metavar='VIDEO',
                   help='join a video\'s sections, newest complete build of each')
    p.add_argument('--soundtrack', metavar='MP3', help='music bed for --assemble')
    p.add_argument('--stale-ok', action='store_true',
                   help='assemble even where a section predates its copy')
    args = p.parse_args()
    videos, sections = load()

    if args.assemble:
        assemble(videos, args.assemble, args.soundtrack, args.stale_ok)
        return

    if args.restore:
        if args.restore not in sections:
            sys.exit(f"no section '{args.restore}'. Try --list.")
        restore_state(args.restore)
        return

    if args.recut:
        s = sections.get(args.recut)
        if s is None:
            sys.exit(f"no section '{args.recut}'. Try --list.")
        recut(s)
        return

    if args.build:
        s = sections.get(args.build)
        if s is None:
            sys.exit(f"no section '{args.build}'. Try --list.")
        build(s, continue_from_previous=not args.no_restore)
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
        # Into the build directory when one is set, so a card rendered as part of
        # a larger section lands with the rest of that build rather than in a
        # shared out/ where the next build would overwrite it.
        dest = Path(os.environ['BUILD_DIR']) if os.environ.get('BUILD_DIR') else HERE / 'out'
        render_card(args.card, card, dest / f"card_{args.card}.mp4")
        return

    if args.list or not (args.cues or args.check):
        for doc in videos:
            ids = [s['id'] for s in doc['sections']]
            print(f"\n{doc['title']}   ({doc['file'].name}, {len(ids)} sections)")
            for i, sid in enumerate(ids, 1):
                s = sections[sid]
                extras = [k for k in ('flash', 'announce', 'actions',
                                      'defer', 'todo') if s.get(k)]
                cues = [f'{len(s[k])} {k}' for k in CUE_KEYS if s.get(k)]
                print(f"  {i:2}. {sid:22} {s['status']:9} build={s['build']:22} "
                      f"{', '.join(cues + extras)}")
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
