#!/usr/bin/env python3
"""Put a cut on YouTube, with the title, description and chapters it was built with.

    python3 tools/video/youtube.py auth
    python3 tools/video/youtube.py upload tools/video/out/intro_<stamp>.mp4
    python3 tools/video/youtube.py privacy <videoId> unlisted
    python3 tools/video/youtube.py show <videoId>

`upload` reads <video>.youtube.json, which `sections.py --assemble` writes from
the storyboard's `youtube:` block plus the chapter times of that cut. Nothing is
typed twice, and a description can never describe a different cut than the one
it is uploaded with.

WHY THIS TALKS TO THE API BY HAND. The official client is four pip packages for
three HTTP calls, and this has to run on whatever python is in front of it years
from now. Everything here is stdlib.

CREDENTIALS, and none of them in the repo:

    ~/.config/oneofus/youtube_client.json   the OAuth client, downloaded from
                                            Google Cloud (APIs & Services ->
                                            Credentials -> Desktop app), after
                                            enabling "YouTube Data API v3"
    ~/.config/oneofus/youtube_token.json    written by `auth`, holds the refresh
                                            token. Treat it as a password.

`auth` opens a browser, so run it yourself once -- it cannot be done over a
pipe. Everything after it is unattended.

THE ONE THING THAT WILL SURPRISE YOU. Google locks videos uploaded through an
unaudited API project to private, and neither this script nor YouTube Studio can
make them public until the project passes an audit. So `upload` defaults to
private and says so; flipping it to public is a click in Studio. Everything else
-- title, description, chapters, tags, unlisting the previous cut -- is done
here.

QUOTA. An upload costs 1600 units of the default 10,000/day, so about six a day.
A `privacy` change costs 50.
"""
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

CONFIG = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'oneofus'
CLIENT = CONFIG / 'youtube_client.json'
TOKEN = CONFIG / 'youtube_token.json'
# youtube.upload alone cannot read a video back or change its privacy, and both
# are wanted here -- `privacy` is how the previous cut stops being the one people
# find. The full scope covers all three.
SCOPE = 'https://www.googleapis.com/auth/youtube'
API = 'https://www.googleapis.com/youtube/v3'
UPLOAD = 'https://www.googleapis.com/upload/youtube/v3/videos'


def die(msg):
    sys.exit(f'{msg}\n')


def client():
    if not CLIENT.exists():
        die(f'no OAuth client at {CLIENT}.\n'
            'Make one in Google Cloud: enable "YouTube Data API v3", then\n'
            'APIs & Services -> Credentials -> Create credentials -> OAuth client\n'
            'ID -> Desktop app, download the JSON, and save it there.')
    d = json.loads(CLIENT.read_text())
    # The console hands out {"installed": {...}} for a desktop client and
    # {"web": {...}} for the other kind. Take either rather than making someone
    # find out which they downloaded.
    d = d.get('installed') or d.get('web') or d
    for k in ('client_id', 'client_secret'):
        if k not in d:
            die(f'{CLIENT} has no {k} -- that is not an OAuth client file.')
    return d


def post_form(url, fields):
    body = urllib.parse.urlencode(fields).encode()
    req = urllib.request.Request(url, data=body, method='POST')
    req.add_header('Content-Type', 'application/x-www-form-urlencoded')
    return json.loads(urllib.request.urlopen(req).read())


def access_token():
    """A live access token, refreshed if need be."""
    if not TOKEN.exists():
        die(f'not authorised yet. Run:  python3 {sys.argv[0]} auth')
    tok = json.loads(TOKEN.read_text())
    c = client()
    got = post_form(c.get('token_uri', 'https://oauth2.googleapis.com/token'), {
        'client_id': c['client_id'],
        'client_secret': c['client_secret'],
        'refresh_token': tok['refresh_token'],
        'grant_type': 'refresh_token',
    })
    return got['access_token']


def api(method, url, params=None, body=None, token=None):
    token = token or access_token()
    if params:
        url = f'{url}?{urllib.parse.urlencode(params)}'
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header('Authorization', f'Bearer {token}')
    if data:
        req.add_header('Content-Type', 'application/json')
    try:
        return json.loads(urllib.request.urlopen(req).read() or b'{}')
    except urllib.error.HTTPError as e:
        # The API says WHY in the body and nothing useful in the status line.
        # Losing that costs an hour of guessing at "400 Bad Request".
        die(f'{method} {url} -> {e.code}\n{e.read().decode(errors="replace")}')


def cmd_auth():
    """The one step that needs a person: consent, once, in a browser."""
    c = client()
    code = {}

    class Catch(BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            code.update({k: v[0] for k, v in q.items()})
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(b'<h3>Done. Close this tab and go back to the terminal.</h3>')

        def log_message(self, *a):
            pass

    server = HTTPServer(('127.0.0.1', 0), Catch)
    redirect = f'http://127.0.0.1:{server.server_port}'
    url = 'https://accounts.google.com/o/oauth2/v2/auth?' + urllib.parse.urlencode({
        'client_id': c['client_id'],
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': SCOPE,
        # Without both of these Google hands back an access token and no refresh
        # token, and every later run wants the browser again.
        'access_type': 'offline',
        'prompt': 'consent',
    })
    print(f'Approve it here (opening a browser):\n\n  {url}\n')
    webbrowser.open(url)
    server.handle_request()
    if 'code' not in code:
        die(f'no code came back: {code}')
    got = post_form(c.get('token_uri', 'https://oauth2.googleapis.com/token'), {
        'client_id': c['client_id'],
        'client_secret': c['client_secret'],
        'code': code['code'],
        'redirect_uri': redirect,
        'grant_type': 'authorization_code',
    })
    if 'refresh_token' not in got:
        die('Google returned no refresh token. Revoke this app at\n'
            'https://myaccount.google.com/permissions and run auth again.')
    CONFIG.mkdir(parents=True, exist_ok=True)
    TOKEN.write_text(json.dumps({'refresh_token': got['refresh_token']}, indent=2) + '\n')
    TOKEN.chmod(0o600)
    print(f'saved {TOKEN}')


def cmd_upload(video, privacy='private'):
    video = Path(video)
    if not video.exists():
        die(f'{video} is not there.')
    meta_file = video.with_suffix('.youtube.json')
    if not meta_file.exists():
        die(f'{meta_file.name} is missing. It is written by\n'
            f'  python3 tools/video/sections.py --assemble {video.stem.split("_")[0]}\n'
            'from the storyboard\'s youtube: block -- so the description and the '
            'chapters belong to THIS cut.')
    meta = json.loads(meta_file.read_text())
    token = access_token()

    # Resumable, because a 30MB PUT over a flaky line that fails at 90% is worth
    # nothing, and because this is the endpoint that reports quota errors before
    # the bytes go rather than after.
    body = {
        'snippet': {'title': meta['title'], 'description': meta['description'],
                    'categoryId': meta.get('categoryId', '28')},  # 28 = Science & Technology
        'status': {'privacyStatus': privacy, 'selfDeclaredMadeForKids': False},
    }
    data = json.dumps(body).encode()
    size = video.stat().st_size
    mime = mimetypes.guess_type(video.name)[0] or 'video/mp4'
    req = urllib.request.Request(
        UPLOAD + '?' + urllib.parse.urlencode(
            {'uploadType': 'resumable', 'part': 'snippet,status'}),
        data=data, method='POST')
    req.add_header('Authorization', f'Bearer {token}')
    req.add_header('Content-Type', 'application/json')
    req.add_header('X-Upload-Content-Length', str(size))
    req.add_header('X-Upload-Content-Type', mime)
    try:
        start = urllib.request.urlopen(req)
    except urllib.error.HTTPError as e:
        die(f'starting the upload -> {e.code}\n{e.read().decode(errors="replace")}')
    session = start.headers['Location']
    if not session:
        die('no upload session came back.')

    print(f'uploading {video.name} ({size / 1e6:.1f} MB) as "{meta["title"]}"...')
    with video.open('rb') as f:
        put = urllib.request.Request(session, data=f, method='PUT')
        put.add_header('Authorization', f'Bearer {token}')
        put.add_header('Content-Type', mime)
        put.add_header('Content-Length', str(size))
        try:
            got = json.loads(urllib.request.urlopen(put).read())
        except urllib.error.HTTPError as e:
            die(f'uploading -> {e.code}\n{e.read().decode(errors="replace")}')

    vid = got['id']
    print(f'\n  https://youtu.be/{vid}   ({got["status"]["privacyStatus"]})')
    if got['status']['privacyStatus'] == 'private' and privacy != 'private':
        print('  It came back PRIVATE anyway: an unaudited API project cannot\n'
              '  publish. Flip it in YouTube Studio.')
    print(f'\n  the old cut:  python3 {sys.argv[0]} privacy <oldId> unlisted')
    return vid


def cmd_privacy(vid, status):
    if status not in ('private', 'unlisted', 'public'):
        die(f'privacy is private, unlisted or public -- not {status}')
    # READ IT FIRST. videos.update replaces the whole `status` part, so sending
    # only privacyStatus silently clears the rest of it.
    got = api('GET', f'{API}/videos', {'part': 'status', 'id': vid})
    if not got.get('items'):
        die(f'no video {vid} on this account.')
    st = got['items'][0]['status']
    st['privacyStatus'] = status
    api('PUT', f'{API}/videos', {'part': 'status'}, {'id': vid, 'status': st})
    print(f'https://youtu.be/{vid} is now {status}')


def cmd_show(vid):
    got = api('GET', f'{API}/videos', {'part': 'snippet,status', 'id': vid})
    if not got.get('items'):
        die(f'no video {vid} on this account.')
    it = got['items'][0]
    print(f"{it['snippet']['title']}   ({it['status']['privacyStatus']})\n")
    print(it['snippet']['description'])


def main():
    a = sys.argv[1:]
    if not a or a[0] in ('-h', '--help'):
        print(__doc__)
        return
    cmd, rest = a[0], a[1:]
    if cmd == 'auth':
        cmd_auth()
    elif cmd == 'upload':
        if not rest:
            die('upload needs a video path.')
        cmd_upload(rest[0], rest[1] if len(rest) > 1 else 'private')
    elif cmd == 'privacy':
        if len(rest) != 2:
            die('privacy needs <videoId> <private|unlisted|public>')
        cmd_privacy(*rest)
    elif cmd == 'show':
        if not rest:
            die('show needs a videoId.')
        cmd_show(rest[0])
    else:
        die(f'no command "{cmd}". Try auth, upload, privacy, show.')


if __name__ == '__main__':
    main()
