#!/usr/bin/env python3
"""Dev server for CodePlay.

Serves the playable game at /, offers the single-file offline build as a forced
download at /download (so it can be saved to a phone or desktop), the tracked
project tree as a zip at /download-project for pushing to GitHub, and just the
Godot project at /download-godot for opening in the Godot editor.
"""
import http.server
import os
import subprocess
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STANDALONE = os.path.join(ROOT, "dist", "CodePlay.html")
DOWNLOADS_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CodePlay downloads</title>
<style>
  body { margin:0; padding:24px; background:#0b1020; color:#e8eef7;
         font:14px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; }
  h1 { font-size:20px; margin:0 0 4px; }
  p  { color:#93a2bd; margin:0 0 20px; }
  a  { display:block; margin:0 0 12px; padding:14px 16px; border:2px solid #5b6d8c;
       border-radius:4px; background:#171e2e; color:#e8eef7; text-decoration:none; }
  a:hover { border-color:#f2c14e; background:#1c2740; }
  b { display:block; color:#f2c14e; }
  span { color:#93a2bd; font-size:12px; }
</style>
</head>
<body>
<h1>CodePlay downloads</h1>
<p>Tap a box to save the file.</p>
<a download href="/download-godot"><b>Godot project (GDScript)</b><span>CodePlay-godot.zip - open it in the Godot editor</span></a>
<a download href="/download-project"><b>Whole project (web + Godot)</b><span>CodePlay-repo.zip - for pushing to GitHub</span></a>
<a download href="/download"><b>Single-file offline game</b><span>CodePlay.html - plays from your phone with no server</span></a>
</body>
</html>
"""

PORT = int(os.environ.get("PORT", "3000"))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path in ("/downloads", "/dl"):
            return self._send_bytes(DOWNLOADS_PAGE.encode("utf-8"), "text/html; charset=utf-8", "")
        if path in ("/download", "/CodePlay.html"):
            return self._send_file(STANDALONE, "text/html; charset=utf-8", "CodePlay.html")
        if path in ("/gd", "/dl-godot"):
            return self._send_zip(["godot"], "CodePlay-godot.zip")
        if path in ("/repo", "/dl-project"):
            return self._send_zip([], "CodePlay-repo.zip")
        if path in ("/download-project", "/CodePlay-repo.zip"):
            return self._send_zip([], "CodePlay-repo.zip")
        if path in ("/download-godot", "/CodePlay-godot.zip"):
            return self._send_zip(["godot"], "CodePlay-godot.zip")
        super().do_GET()

    def _send_bytes(self, data, content_type, download_name=""):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        if download_name:
            self.send_header("Content-Disposition", 'attachment; filename="%s"' % download_name)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_file(self, filename, content_type, download_name):
        try:
            with open(filename, "rb") as fh:
                data = fh.read()
        except OSError:
            self.send_error(404, "Not found")
            return
        self._send_bytes(data, content_type, download_name)

    def _send_zip(self, paths, download_name):
        """Zip the tracked tree straight from git, so ignored files never leak in."""
        try:
            data = subprocess.run(
                ["git", "archive", "--format=zip", "HEAD"] + list(paths),
                cwd=ROOT, capture_output=True, check=True,
            ).stdout
        except (OSError, subprocess.CalledProcessError) as exc:
            self.send_error(503, "Could not build project zip: %s" % exc)
            return
        self._send_bytes(data, "application/zip", download_name)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    with http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler) as httpd:
        httpd.serve_forever()
