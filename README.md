# omarchy-herdr-notify

Desktop notifications for [herdr](https://herdr.dev/) agents on
[Omarchy](https://omarchy.org/) — **that you can click to get to the agent**.

## Why

herdr knows when a coding agent stops and waits for you, and it can raise a
desktop notification about it (`ui.toast.delivery = "system"`). But it sends
that notification through `notify-send` with no action attached — the stored
notification has an empty `execArgv` — so clicking it does nothing except
dismiss it. You still have to find the agent yourself, possibly on another
Hyprland workspace, in another herdr workspace, in another pane.

This replaces that notification with one that carries a click action.

## What you get

**A notification you can click.** When an agent transitions into `blocked`,
you get an Omarchy notification naming the workspace and what the agent was
doing. Clicking it raises the terminal running herdr — switching Hyprland
workspace if needed — and focuses the pane that is waiting.

**A herdr update watcher** (optional). On distros where herdr comes from a
package repo, herdr's own `herdr update` is the wrong tool: upstream says to
use it "only for installs managed by Herdr's own installer". So you wait for
the repo instead, and this tells you once when the update lands.

## Requirements

- Omarchy (for `omarchy-notification-send`) and Hyprland (for `hyprctl`)
- herdr, with its socket API reachable — the default
- `python3`
- `pacman-contrib`, for the optional update watcher's `checkupdates`

## Install

```bash
git clone https://github.com/dbarke/omarchy-herdr-notify.git
cd omarchy-herdr-notify
./install.sh
```

It symlinks `bin/*` into `~/.local/bin` and installs the systemd user units, so
`git pull` updates what runs.

Then set the one config value in `~/.config/herdr/config.toml`:

```toml
[ui.toast]
delivery = "herdr"
```

and `herdr server reload-config`. Leaving it at `"system"` means herdr keeps
sending its own unclickable notifications alongside these, so you get two of
everything. `"herdr"` keeps an in-app toast, which also gives herdr's
`open_notification_target` binding (`prefix+o`) something to open.

## The pieces

### `herdr-agent-watch`

A systemd user service polling `herdr agent list` every 3 seconds. It notifies
on the **transition into** `blocked`, never on the standing state — otherwise
it would re-notify every 3 seconds for as long as an agent waits. Agents
already blocked when it starts are recorded rather than announced, so a
restart is quiet.

Poll interval is `HERDR_WATCH_INTERVAL` (seconds). To notify on a different
state, change `TRIGGER` — `"idle"` would tell you when an agent has finished
rather than when it needs you.

### `herdr-goto <pane-id>`

The click action, and usable on its own (`herdr-goto w5:p1`). Two moves are
needed, because focusing a pane inside herdr does nothing if herdr's own
window is not in front:

1. Find the terminal window running the herdr **client** and raise it with
   `hyprctl dispatch focuswindow`. The client is identified by its cmdline
   being exactly `herdr` — the server's is `/usr/bin/herdr server` — and the
   window is its parent process. Matching on pid rather than window title
   means this survives herdr restarts and any `ui.window_title` setting.
2. `herdr agent focus <pane-id>`.

### `herdr-update-check`

Notifies once when a herdr update reaches the package repo. `checkupdates`
syncs into a temporary database, so it needs no root and never touches system
state. A state file under `~/.local/state/herdr-update-check/` records the
version already announced, so a daily timer does not become a daily nag.

Runs daily via `herdr-update-check.timer`, with `Persistent=true` so it catches
up after the machine was off.

## Uninstall

```bash
systemctl --user disable --now herdr-agent-watch.service herdr-update-check.timer
rm ~/.local/bin/herdr-{goto,agent-watch,update-check}
rm ~/.config/systemd/user/herdr-{agent-watch.service,update-check.service,update-check.timer}
systemctl --user daemon-reload
```

## License

MIT — see [LICENSE](LICENSE).
