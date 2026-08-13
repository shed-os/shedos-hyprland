#!/usr/bin/env bash
# run.sh — contract smoke tests for the verbs this package ships. Asserts the
# cheap invariants every subcommand must honor:
#   - --help-summary prints one nonempty line, exit 0
#   - -h/--help exits 0 and mentions usage
#   - completion contract answers exit 0 and never hang
# Deeper behavior belongs to the dedicated suites; keybindings, screenrecord
# and the dock's own surfaces have theirs. This keeps the dispatcher surface
# from silently rotting, and it is the half of the monolith's smoke suite that
# followed these verbs here.

set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$here/../.." && pwd)

pass=0 fail=0
failures=()
_ok()   { echo "ok: $1"; ((pass++)); }
_fail() { echo "FAIL: $1: $2" >&2; failures+=("$1"); ((fail++)); }

TOOLS=(browser dock keybindings launcher power screenrecord)

for name in "${TOOLS[@]}"; do
    path=$repo_root/tree/usr/libexec/shedman/$name
    if [[ ! -x $path ]]; then
        _fail "${name}_exists" "missing or not executable: $path"
        continue
    fi

    out=$(timeout 10 "$path" --help-summary 2>&1); rc=$?
    if (( rc == 0 )) && [[ -n ${out//[[:space:]]/} ]] && (( $(wc -l <<<"$out") == 1 )); then
        _ok "${name}_help_summary"
    else
        _fail "${name}_help_summary" "rc=$rc out=$out"
    fi

    out=$(timeout 10 "$path" --help 2>&1); rc=$?
    if (( rc == 0 )) && grep -qiE 'usage|shedman' <<<"$out"; then
        _ok "${name}_help"
    else
        _fail "${name}_help" "rc=$rc out=${out:0:120}"
    fi

    for mode in --complete-bash --complete-zsh --complete-fish; do
        timeout 10 "$path" "$mode" >/dev/null 2>&1; rc=$?
        if (( rc == 0 )); then
            _ok "${name}${mode//-/_}"
        else
            _fail "${name}${mode//-/_}" "rc=$rc"
        fi
    done
done

echo
echo "Summary: $pass passed, $fail failed"
(( fail == 0 )) || { printf '  %s\n' "${failures[@]}"; exit 1; }
exit 0
