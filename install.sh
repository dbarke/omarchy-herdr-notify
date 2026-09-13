#!/usr/bin/env bash
#
# Symlink the scripts into ~/.local/bin and install the systemd user units.
# Symlinks rather than copies, so `git pull` here updates what runs.

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bindir="${XDG_BIN_HOME:-$HOME/.local/bin}"
unitdir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

mkdir -p "$bindir" "$unitdir"

for script in "$repo"/bin/*; do
  ln -sfn "$script" "$bindir/$(basename "$script")"
  echo "linked $bindir/$(basename "$script")"
done

for unit in "$repo"/systemd/*; do
  install -m 0644 "$unit" "$unitdir/$(basename "$unit")"
  echo "installed $unitdir/$(basename "$unit")"
done

systemctl --user daemon-reload
systemctl --user enable --now herdr-agent-watch.service
echo "enabled herdr-agent-watch.service"

# The update checker is optional -- it only makes sense on a distro where herdr
# comes from a package repo rather than herdr's own installer.
if command -v checkupdates >/dev/null 2>&1; then
  systemctl --user enable --now herdr-update-check.timer
  echo "enabled herdr-update-check.timer"
else
  echo "skipped herdr-update-check.timer (checkupdates not found; install pacman-contrib)"
fi

cat <<'NOTE'

One config change is still needed, in ~/.config/herdr/config.toml:

    [ui.toast]
    delivery = "herdr"

Leaving it at "system" means herdr also sends its own desktop notifications,
which are not clickable -- you would get two for every event.
Then: herdr server reload-config
NOTE
