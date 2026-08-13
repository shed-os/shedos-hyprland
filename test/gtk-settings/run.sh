#!/usr/bin/env bash
# The GTK settings ship six times and are written down once. Four of those
# copies were tracked separately before this repository existed — two here and
# two in shedos-system — and the only thing keeping them equal was that nobody
# had edited one of them yet.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)

pass=0; fail=0; failures=()
_ok()   { printf 'ok: %s\n' "$1"; pass=$((pass + 1)); }
_fail() { printf 'FAIL: %s — %s\n' "$1" "$2" >&2; failures+=("$1"); fail=$((fail + 1)); }

want=(
    etc/gtk-3.0/settings.ini
    etc/gtk-4.0/settings.ini
    etc/skel/.config/gtk-3.0/settings.ini
    etc/skel/.config/gtk-4.0/settings.ini
    usr/share/shedos/hyprland/defaults/.config/gtk-3.0/settings.ini
    usr/share/shedos/hyprland/defaults/.config/gtk-4.0/settings.ini
)

# G1: one source, and the repository tracks no second copy of it. Asked of git
# rather than of the directory, which after a local build also holds the six
# the build just wrote.
mapfile -t found < <(cd "$repo_root" && git ls-files '*settings.ini' | sort)
if [[ ${#found[@]} -eq 1 && ${found[0]} == gtk/settings.ini ]]; then
    _ok G1_one_source
else
    _fail G1_one_source "settings.ini in the tree: ${found[*]}"
fi

# G2: the six destinations the package writes it to, read out of the PKGBUILD
# rather than restated here, so a destination dropped from the build is a
# destination this suite goes red about.
mapfile -t got < <(
    bash -c 'source "$1" > /dev/null 2>&1; printf "%s\n" "${_gtk_settings[@]}"' \
        _ "$repo_root/PKGBUILD" | sort
)
mapfile -t sorted_want < <(printf '%s\n' "${want[@]}" | sort)
if [[ "${got[*]}" == "${sorted_want[*]}" ]]; then
    _ok G2_six_destinations
else
    _fail G2_six_destinations "the PKGBUILD installs it to: ${got[*]}"
fi

echo
echo "gtk-settings: $pass/$((pass + fail)) passed"
if (( fail > 0 )); then printf '  %s\n' "${failures[@]}" >&2; exit 1; fi
exit 0
