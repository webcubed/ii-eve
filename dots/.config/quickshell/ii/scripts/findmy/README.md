# findmy — Google Find My / Find Hub "people" daemon

Polls Google Location Sharing (the same data as the **Find people** tab of the
Find My Device / Find Hub app) for everyone who shares their location with the
configured Google account. Keeps trails (history), tracks areas of interest
(AOI), auto-imports session cookies from your browser, and writes everything to
`~/.local/state/quickshell/findmy/state.json` for the sidebar widget
(`SidebarPolicies` → People tab).

Endpoint: the undocumented `google.com/maps/rpc/locationsharing/read` RPC
reverse-engineered by `locationsharinglib` (MIT). Not an official Google API —
may break at any time. Use on your own account only.

## Layout

| file | purpose |
| --- | --- |
| `findmy.py` | daemon + CLI (`serve`, `login`, `logout`, `refresh`, `aoi add\|rm\|list`, `trail`, `reconfig`, `status`) |
| `findmy-venv.sh` | bash wrapper that runs it inside the shell's uv venv |
| `state.json` | snapshot the widget reads (people, trails, aois, events, auth status) |
| `control.json` | command queue from CLI/widget to the daemon |
| `cookies.txt` | session cookies (0600, never commit) |
| `aois.json` | areas of interest |
| `daemon.log` / `daemon.pid` | logging / single-instance lock |

## Auth (login via browser)

1. The daemon opens `google.com/android/find/people` in your browser.
2. Sign in, and make sure the account **shares its own live location** (or has
   people sharing with it). Sharing can be enabled from the Find Hub app or
   Google Maps.
3. The daemon pulls the session cookies out of your browser's cookie DB
   (via `browser_cookie3` — Chrome/Chromium/Brave) and caches them.
4. Press **Login with Browser** again if the browser was already open.

## Widget

- `services/FindMy.qml` — starts/polls the daemon, exposes people/trails/aois.
- `modules/ii/sidebarPolicies/findMy/FindMyPage.qml` — Mapbox map (token set in
  Settings → Find My, stored in the keyring), markers, trails, AOI circles,
  person list, login controls.
- Settings → **Find My** toggles the widget, sets the Mapbox token, polling,
  trails and areas of interest.

The Mapbox token is required for tiles and is stored via `KeyringStorage`
(`secret-tool`), not in the config file.

## Dependency

`browser-cookie3` was added to `sdata/uv/requirements.in` (compiled to
`requirements.txt`). Re-install shell deps once (`eve update` or the installer)
so the daemon can extract browser cookies; `requests` is already present.