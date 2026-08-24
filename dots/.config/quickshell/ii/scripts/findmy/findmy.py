#!/usr/bin/env python3
"""findmy.py - unofficial Google Find My / Find Hub *people* location daemon.

Reads the live locations of everyone sharing their location with a Google
account (Google Location Sharing, the same data as the "Find people" tab),
keeps trails (movement history), tracks areas of interest (AOI), caches the
session cookies, and exposes everything as JSON state files consumed by the
Quickshell widget.

It talks to the undocumented internal RPC behind the "Find people" tab
(google.com/maps/rpc/locationsharing/read), reverse-engineered by the
MIT-licensed `locationsharinglib` project (github.com/costastf/locationsharinglib).
This is NOT an official Google API - it can break at any time. Use it only on
accounts you control and in line with Google's Terms of Service.

State layout (FINDMY_STATE_DIR, default ~/.local/state/quickshell/findmy):
    cookies.txt   session cookies (chmod 600)
    aois.json     areas of interest
    state.json    current snapshot (written atomically, read by the widget)
    control.json  commands from CLI/widget to the daemon
    daemon.log    daemon logging

Subcommands:
    serve [--interval N] [--trail-max N]   run the polling daemon
    login                                   open browser for login (+ cookie import)
    logout                                  forget cookies and location data
    refresh                                 force an immediate poll
    aoi add <name> <lat> <lng> <radius_km>  add an area of interest
    aoi rm <name>                           remove an area of interest
    aoi list                                print areas of interest
    trail clear                             wipe all trails
    status                                  print the current state.json
"""

import argparse
import json
import logging
import math
import os
import secrets
import shutil
import signal
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

RPC_URL = "https://www.google.com/maps/rpc/locationsharing/read"
# Fixed request params used by the Maps frontend ("pb" is map rendering state).
RPC_PARAMS = {
    "authuser": 2,
    "hl": "en",
    "gl": "us",
    "pb": (
        "!1m7!8m6!1m3!1i14!2i8413!3i5385!2i6!3x4095"
        "!2m3!1e0!2sm!3i407105169!3m7!2sen!5e1105!12m4"
        "!1e68!2m2!1sset!2sRoadmap!4e1!5m4!1e4!8m2!1e0!"
        "1e1!6m9!1e12!2i2!26m1!4b1!30m1!"
        "1f1.3953487873077393!39b1!44e1!50e0!23i4111425"
    ),
}
VALID_COOKIE_NAMES = {"__Secure-1PSID", "__Secure-3PSID"}
LOGIN_URL = "https://www.google.com/android/find/people"
STATE_VERSION = 1

LOG = logging.getLogger("findmy")


def state_dir() -> Path:
    override = os_environ("FINDMY_STATE_DIR")
    if override:
        return Path(override)
    xdg = os_environ("XDG_STATE_HOME")
    base = Path(xdg) if xdg else Path.home() / ".local" / "state"
    return base / "quickshell" / "findmy"


def os_environ(key: str) -> str:
    import os
    return os.environ.get(key, "")


class FindMyError(Exception):
    pass


class SessionError(FindMyError):
    """Session is missing or rejected by Google."""


def parse_rpc_body(text: str) -> list:
    # Body is xssi-prefixed: )]}'\n<json array>
    return json.loads(text.split("'", 1)[1])


def load_netscape_cookies(path: Path) -> List[Dict[str, str]]:
    cookies = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) < 7:
            continue
        domain = fields[0]
        if domain.startswith("#HttpOnly_"):
            domain = domain[len("#HttpOnly_"):]
        cookies.append({"name": fields[5], "value": fields[6], "domain": domain, "path": fields[2]})
    return cookies


def write_netscape_cookies(cookies: List[Dict[str, str]], path: Path) -> None:
    lines = ["# Netscape HTTP Cookie File"]
    for c in cookies:
        lines.append("\t".join([".google.com", "TRUE", c.get("path", "/"), "TRUE", "0", c["name"], c["value"]]))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    try:
        path.chmod(0o600)
    except OSError:
        pass


class AuthManager:
    """Keeps a valid cookie session, importing from the browser if needed."""

    def __init__(self, cookies_path: Path):
        self.cookies_path = cookies_path
        self.session: Any = None
        self._last_browser_try = 0.0
        self._login_opened_at = 0.0

    @property
    def has_cookie_file(self) -> bool:
        return self.cookies_path.is_file()

    def _load_session(self) -> Any:
        if not HAS_REQUESTS:
            raise FindMyError("requests is not installed (shell venv deps out of date)")
        cookies = load_netscape_cookies(self.cookies_path)
        names = {c["name"] for c in cookies}
        if not names & VALID_COOKIE_NAMES:
            raise FindMyError("cookie file missing __Secure-1PSID/__Secure-3PSID")
        session = requests.Session()
        for c in cookies:
            session.cookies.set(name=c["name"], value=c["value"], domain=c["domain"], path=c["path"])
        return session

    def validate(self, session: Any) -> bool:
        try:
            if not HAS_REQUESTS:
                return False
            resp = session.get(RPC_URL, params=RPC_PARAMS, timeout=15)
            if not resp.ok:
                return False
            data = parse_rpc_body(resp.text)
            return data[6] != "GgA="  # "GgA=" marks a signed-out session
        except (IndexError, TypeError, ValueError, Exception):
            return False

    def import_from_browsers(self) -> bool:
        """Try to pull google.com cookies from installed browsers. Returns True on success."""
        try:
            import browser_cookie3
        except ImportError:
            LOG.warning("browser_cookie3 not installed; cannot auto-extract cookies")
            return False
        loaders = [
            ("chrome", lambda: browser_cookie3.chrome(domain_name=".google.com")),
            ("chromium", lambda: browser_cookie3.chromium(domain_name=".google.com")),
            ("brave", lambda: browser_cookie3.brave(domain_name=".google.com")),
        ]
        cookies: List[Dict[str, str]] = []
        for name, fn in loaders:
            try:
                cj = fn()
                rows = {c.name: {"name": c.name, "value": c.value, "path": c.domain_specified_path or "/", "domain": c.domain} for c in cj}
                if not rows:
                    continue
                found = [rows[n] for n in VALID_COOKIE_NAMES if n in rows]
                if found:
                    cookies = found
                    LOG.info("imported cookies from %s", name)
                    break
            except Exception as err:  # noqa: BLE001 - browsers do all kinds of things
                LOG.debug("browser %s failed: %s", name, err)
        if not cookies:
            return False
        write_netscape_cookies(cookies, self.cookies_path)
        try:
            return self.validate(self._load_session())
        except FindMyError:
            return False

    def open_login(self) -> None:
        """Open the browser to the Find people page so the user can (re-)sign in."""
        if time.monotonic() - self._login_opened_at < 120:
            return  # avoid spamming window opens
        self._login_opened_at = time.monotonic()
        try:
            subprocess_detached(["xdg-open", LOGIN_URL])
        except Exception as err:  # noqa: BLE001
            LOG.warning("could not open browser: %s", err)

    def ensure(self, allow_browser: bool = True) -> bool:
        """Returns True if a valid session is loaded into self.session."""
        if self.cookies_path.is_file():
            try:
                session = self._load_session()
                if self.validate(session):
                    self.session = session
                    return True
            except FindMyError:
                pass
            LOG.info("cookie file present but session invalid")
            self.cookies_path.unlink(missing_ok=True)
        if not allow_browser:
            return False
        # Try importing live browser cookies at most once every 10 seconds
        now = time.monotonic()
        if now - self._last_browser_try < 10:
            return False
        self._last_browser_try = now
        if self.import_from_browsers():
            try:
                self.session = self._load_session()
                return True
            except FindMyError:
                pass
        return False


def subprocess_detached(argv: List[str]) -> None:
    import subprocess
    subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


# --- RPC -----------------------------------------------------------------

def fetch_people(session: Any) -> List[Dict[str, Any]]:
    if not HAS_REQUESTS:
        raise FindMyError("requests is not installed (shell venv deps out of date)")
    resp = session.get(RPC_URL, params=RPC_PARAMS, timeout=20)
    if not resp.ok:
        raise FindMyError(f"HTTP {resp.status_code}: {resp.text[:200]}")
    data = parse_rpc_body(resp.text)
    people = []
    for entry in data[0] if (data and data[0]) else []:
        try:
            people.append({
                "id": entry[6][0],
                "avatar": entry[6][1],
                "full_name": entry[6][2],
                "nickname": entry[6][3],
                "lat": entry[1][1][2],
                "lng": entry[1][1][1],
                "updated_ms": entry[1][2],
                "accuracy_m": entry[1][3],
                "address": entry[1][4],
                "country_code": entry[1][6],
                "charging": bool(entry[13][0]) if entry[13][0] is not None else None,
                "battery": entry[13][1],
            })
        except (IndexError, TypeError):
            continue
    return people


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


# --- persistence ----------------------------------------------------------

def atomic_write_json(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=path.name + ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(obj, fh, ensure_ascii=False)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)


def read_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


# --- daemon ----------------------------------------------------------------

def write_control(state: Path, action: str, **kwargs: Any) -> None:
    """Queue a command for the daemon (used by the CLI / widget)."""
    actions = read_json(state / "control.json", [])
    actions.append(dict(action=action, **kwargs))
    atomic_write_json(state / "control.json", actions)


def take_control_actions(path: Path) -> List[Dict[str, Any]]:
    actions = read_json(path, [])
    if actions:
        atomic_write_json(path, [])
    return actions


def load_aois(state: Path) -> List[Dict[str, Any]]:
    return read_json(state / "aois.json", [])


def save_aois(state: Path, aois: List[Dict[str, Any]]) -> None:
    atomic_write_json(state / "aois.json", aois)


class Daemon:
    """Polling daemon: auth, fetch, trails, AOI events, state writing."""

    def __init__(self, state: Path, interval: int, trail_max: int):
        self.state = state
        self.interval = max(10, interval)
        self.trail_max = max(50, trail_max)
        self.auth = AuthManager(state / "cookies.txt")
        self.people: List[Dict[str, Any]] = []
        self.prev_by_id: Dict[str, Dict[str, Any]] = {}
        self.trails: Dict[str, List[Dict[str, Any]]] = {}
        self.aois: List[Dict[str, Any]] = []
        self.events: List[Dict[str, Any]] = []
        self.last_action = ""
        self.last_action_ok = True
        self.last_action_msg = ""
        self.authenticated = False
        self.authenticating = False
        self.auth_error = ""

    # --------------------------------------------------------------- control
    def process_control(self) -> None:
        actions = take_control_actions(self.state / "control.json")
        for act in actions:
            kind = act.get("action")
            try:
                if kind == "login":
                    self.auth.open_login()
                    self.authenticating = True
                    self.last_action_msg = "browser opened for login"
                elif kind == "logout":
                    (self.state / "cookies.txt").unlink(missing_ok=True)
                    self.auth.session = None
                    self.authenticated = False
                    self.authenticating = False
                    self.people = []
                    self.trails = {}
                    self.events = []
                    self.last_action_msg = "logged out"
                elif kind == "refresh":
                    self.last_action_msg = "refresh requested"
                elif kind == "reconfig":
                    if act.get("interval") is not None:
                        self.interval = max(10, int(act["interval"]))
                    if act.get("trailMax") is not None:
                        self.trail_max = max(50, int(act["trailMax"]))
                    self.last_action_msg = f"reconfigured ({self.interval}s/{self.trail_max}p)"
                elif kind == "aoi_add":
                    self.aois.append({
                        "id": secrets.token_hex(4),
                        "name": str(act["name"])[:64],
                        "lat": float(act["lat"]),
                        "lng": float(act["lng"]),
                        "radius_km": max(0.1, float(act.get("radiusKm", 1))),
                    })
                    save_aois(self.state, self.aois)
                    self.last_action_msg = f"aoi '{act['name']}' added"
                elif kind == "aoi_rm":
                    target = str(act["name"])
                    self.aois = [a for a in self.aois
                                 if a["id"] != target and a["name"] != target]
                    save_aois(self.state, self.aois)
                    self.last_action_msg = "aoi removed"
                elif kind == "trail_clear":
                    self.trails = {}
                    self.last_action_msg = "trails cleared"
                else:
                    self.last_action_msg = f"unknown action {kind}"
                self.last_action_ok = True
            except Exception as err:  # noqa: BLE001
                self.last_action_ok = False
                self.last_action_msg = f"{kind}: {err}"
            self.last_action = kind


    # ---------------------------------------------------------------- state
    def snapshot_people(self) -> List[Dict[str, Any]]:
        out = []
        for p in self.people:
            inside = []
            for a in self.aois:
                if haversine_km(p["lat"], p["lng"], a["lat"], a["lng"]) <= a["radius_km"]:
                    inside.append(a["id"])
            out.append({
                "id": p["id"],
                "name": p["full_name"] or p["nickname"] or "Unknown",
                "nickname": p["nickname"],
                "lat": p["lat"],
                "lng": p["lng"],
                "updated_ms": p["updated_ms"],
                "accuracy_m": p["accuracy_m"],
                "address": p["address"],
                "country": p["country_code"],
                "charging": p["charging"],
                "battery": p["battery"],
                "avatar": p["avatar"],
                "inside": inside,
            })
        return out

    def write_state(self, error: str = "") -> None:
        state_obj = {
            "version": STATE_VERSION,
            "authenticated": self.authenticated,
            "authenticating": self.authenticating,
            "authError": error or self.auth_error,
            "lastUpdated": int(time.time() * 1000),
            "pollIntervalSec": self.interval,
            "trailMaxPoints": self.trail_max,
            "people": self.snapshot_people(),
            "trails": self.trails,
            "aois": self.aois,
            "events": self.events[-60:],
            "lastAction": self.last_action,
            "lastActionOk": self.last_action_ok,
            "lastActionMsg": self.last_action_msg,
        }
        atomic_write_json(self.state / "state.json", state_obj)

    def _update_trails(self) -> None:
        dist_min = 0.0005  # ~55m
        time_gap_ms = 10 * 60 * 1000
        for p in self.people:
            pid = p["id"]
            trail = self.trails.get(pid, [])
            if trail:
                last = trail[-1]
                moved = abs(last["lat"] - p["lat"]) > dist_min or abs(last["lng"] - p["lng"]) > dist_min
                stale = p["updated_ms"] - last["ts"] > time_gap_ms
                if not moved and not stale:
                    continue
            trail.append({"lat": p["lat"], "lng": p["lng"], "ts": p["updated_ms"]})
            self.trails[pid] = trail[-self.trail_max:]

    def _update_aoi_events(self) -> None:
        snapshot = self.snapshot_people()
        for a in self.aois:
            for p in snapshot:
                inside_now = a["id"] in p["inside"]
                was = self.prev_by_id.get(p["id"], {}).get("inside") or []
                if inside_now == (a["id"] in was):
                    continue
                self.events.append({
                    "ts": int(time.time() * 1000),
                    "type": "enter" if inside_now else "leave",
                    "person": p["name"],
                    "personId": p["id"],
                    "aoi": a["name"],
                    "aoiId": a["id"],
                })
        self.prev_by_id = {p["id"]: p for p in snapshot}

    # ------------------------------------------------------------------ tick
    def tick(self) -> None:
        if not self.authenticated:
            if not self.auth.ensure(allow_browser=True):
                self.authenticating = True
                self.auth_error = "no valid session"
                self.auth.open_login()  # first-run / re-login UX; throttled
                self.write_state()
                return
            self.authenticated = True
            self.authenticating = False
            self.auth_error = ""
        try:
            self.people = fetch_people(self.auth.session)
        except FindMyError as err:
            if "401" in str(err) or "403" in str(err):
                self.authenticated = False
                self.auth_error = str(err)
            else:
                self.write_state(str(err))
            return
        self._update_trails()
        self._update_aoi_events()
        self.write_state()

    def run(self) -> None:
        self.aois = load_aois(self.state)
        while True:
            self.process_control()
            self.tick()
            for _ in range(max(1, self.interval)):
                time.sleep(1)
                if (self.state / "control.json").exists():
                    break


# --- CLI --------------------------------------------------------------------

def ensure_pid(state: Path) -> bool:
    """True if we became the running daemon (exit otherwise)."""
    pid_path = state / "daemon.pid"
    try:
        pid = int(pid_path.read_text().strip())
        os.kill(pid, 0)
        return False  # another daemon is alive
    except (ValueError, OSError):
        pass
    pid_path.write_text(str(os.getpid()))
    return True


def drop_pid(state: Path) -> None:
    (state / "daemon.pid").unlink(missing_ok=True)


def cmd_serve(args: argparse.Namespace) -> int:
    state = state_dir()
    state.mkdir(parents=True, exist_ok=True)
    if not ensure_pid(state):
        print("findmy daemon is already running")
        return 1

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            logging.FileHandler(state / "daemon.log"),
            logging.StreamHandler(sys.stderr),
        ],
    )

    def _stop(_sig, _frame):
        drop_pid(state)
        sys.exit(0)

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    Daemon(state, interval=args.interval, trail_max=args.trail_max).run()
    return 0


def cmd_login(_args: argparse.Namespace) -> int:
    write_control(state_dir(), "login")
    print("login requested (browser will open on next daemon tick)")
    return 0


def cmd_logout(_args: argparse.Namespace) -> int:
    write_control(state_dir(), "logout")
    print("logout requested")
    return 0


def cmd_refresh(_args: argparse.Namespace) -> int:
    write_control(state_dir(), "refresh")
    print("refresh requested")
    return 0


def cmd_aoi(args: argparse.Namespace) -> int:
    state = state_dir()
    if args.aoi_command == "add":
        name = args.name
        lat = float(args.lat)
        lng = float(args.lng)
        radius = float(args.radius_km)
        write_control(state, "aoi_add", name=name, lat=lat, lng=lng, radiusKm=radius)
        # Keep aois.json in sync even if the daemon is down.
        aois = load_aois(state)
        aois.append({"id": secrets.token_hex(4), "name": name, "lat": lat, "lng": lng, "radius_km": radius})
        save_aois(state, aois)
        print(f"aoi '{name}' queued")
    elif args.aoi_command == "rm":
        write_control(state, "aoi_rm", name=args.name)
        aois = [a for a in load_aois(state) if a["id"] != args.name and a["name"] != args.name]
        save_aois(state, aois)
        print("aoi removal queued")
    elif args.aoi_command == "list":
        for a in load_aois(state):
            print(f"{a['name']} ({a['lat']},{a['lng']}) r={a['radius_km']}km id={a['id']}")
    return 0


def cmd_reconfig(args: argparse.Namespace) -> int:
    write_control(state_dir(), "reconfig", interval=args.interval, trailMax=args.trail_max)
    print("reconfig requested")
    return 0


def cmd_trail_clear(_args: argparse.Namespace) -> int:
    state = state_dir()
    write_control(state, "trail_clear")
    snap = read_json(state / "state.json", None)
    if isinstance(snap, dict) and snap.get("trails"):
        snap["trails"] = {}
        atomic_write_json(state / "state.json", snap)
    print("trails cleared")
    return 0


def cmd_status(_args: argparse.Namespace) -> int:
    state = state_dir()
    snap = read_json(state / "state.json", None)
    if not isinstance(snap, dict):
        print("no state yet (daemon not run?)")
        return 1
    print(json.dumps(snap, indent=2, ensure_ascii=False))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="findmy", description="Google Find My / Find Hub people location daemon")
    sub = parser.add_subparsers(dest="command")

    serve = sub.add_parser("serve", help="run the polling daemon")
    serve.add_argument("--interval", type=int, default=60, help="poll interval in seconds (min 10)")
    serve.add_argument("--trail-max", type=int, default=300, help="max trail points per person")

    sub.add_parser("login", help="open browser for login and import cookies")
    sub.add_parser("logout", help="forget cookies and location data")
    sub.add_parser("refresh", help="force an immediate poll")

    aoi = sub.add_parser("aoi", help="manage areas of interest")
    aoi.add_argument("aoi_command", choices=["add", "rm", "list"])
    aoi.add_argument("name", nargs="?", default="")
    aoi.add_argument("lat", nargs="?", default="")
    aoi.add_argument("lng", nargs="?", default="")
    aoi.add_argument("radius_km", nargs="?", default="1")

    sub.add_parser("trail", help="manage trails")
    sub.add_parser("status", help="print current state.json")

    rc = sub.add_parser("reconfig", help="change the daemon poll interval / trail cap")
    rc.add_argument("--interval", type=int, default=None)
    rc.add_argument("--trail-max", type=int, default=None)
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "serve":
        return cmd_serve(args)
    if args.command == "login":
        return cmd_login(args)
    if args.command == "logout":
        return cmd_logout(args)
    if args.command == "refresh":
        return cmd_refresh(args)
    if args.command == "aoi":
        return cmd_aoi(args)
    if args.command == "trail":
        return cmd_trail_clear(args)
    if args.command == "status":
        return cmd_status(args)
    if args.command == "reconfig":
        return cmd_reconfig(args)
    build_parser().print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
