# shedos-hyprland

The ShedOS desktop: every dotfile under `/etc/skel/` a new user starts with,
the helpers those dotfiles bind keys to, and the systemd user units that run
the session — waybar, the dock and its drawer, the wallpaper daemon, hypridle,
the night-light timers and the one-shot migrations.

Six verbs ship from here and plug into `shedman`: `browser`, `keybindings`,
`launcher`, `power`, `screenrecord` and `dock`. Each has a declaration under
`/usr/share/shedman/verbs.d/` naming this package and a man page shipped
beside it, which is the contract the pipeline checks against the built package
rather than against this tree.

Everything under `/etc/skel/` is mirrored byte for byte at
`/usr/share/shedos/hyprland/defaults/`. That mirror is the pristine copy
`shedman config --sync` three-way merges a user's file against, so a shipped
default and its mirror can never disagree: `package()` writes both from the
same source.

The GTK settings are one file. It installs six times — the system-wide pair
under `/etc/`, the per-user pair under `/etc/skel/`, and the two in the
defaults mirror — because those six copies have to say the same thing and
keeping six of them in the tree is how they stop.

The desktop reads its colours from `/etc/shedos/themes/current/`, which
shedos-theme-engine renders; the hooks that reload waybar, kitty and the
wallpaper after a theme apply ship from here and run from there.
