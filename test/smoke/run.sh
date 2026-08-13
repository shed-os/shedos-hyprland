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

# Answering a completion query must cost nothing: a verb that reaches its real
# work to say what flags it takes has already done the work. `keybindings` did
# — its completion flags fell through to the dialog — and neither the exit code
# nor the empty output says so, because a GTK application that cannot open a
# display still exits 0 with nothing on stdout. What says so is the compositor
# call the dialog makes before it gets there, so the completion queries below
# run with a compositor that records being asked.
stub=$(mktemp -d -t shedos-smoke.XXXXXX)
trap 'rm -rf -- "$stub"' EXIT
asked=$stub/asked.log
cat > "$stub/hyprctl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$asked"
exit 1
STUB
chmod +x "$stub/hyprctl"

# The verbs whose declaration says they answer completions with nothing. Read
# from the declarations rather than listed here, so a verb that changes its
# mind changes one file.
declares_silence() {
    local decl=$repo_root/tree/usr/share/shedman/verbs.d/$1.toml
    grep -qE '^completes[[:space:]]*=[[:space:]]*false' "$decl"
}

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
        : > "$asked"
        out=$(PATH="$stub:$PATH" timeout 10 "$path" "$mode" 2>/dev/null); rc=$?
        if (( rc != 0 )); then
            _fail "${name}${mode//-/_}" "rc=$rc"
        elif [[ -s $asked ]]; then
            _fail "${name}${mode//-/_}" "asked the compositor: $(tr '\n' ' ' < "$asked")"
        elif declares_silence "$name" && [[ -n ${out//[[:space:]]/} ]]; then
            _fail "${name}${mode//-/_}" "declares completes = false and answered: $out"
        else
            _ok "${name}${mode//-/_}"
        fi
    done
done

echo
echo "Summary: $pass passed, $fail failed"
(( fail == 0 )) || { printf '  %s\n' "${failures[@]}"; exit 1; }
exit 0
