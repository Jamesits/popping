#!/usr/bin/env bash
# Install a commit-msg hook that appends Co-Authored-By: trailers to every
# commit unless the commit already credits that co-author (matched by email).
#
# Usage:
#   ./popping.sh [options] <preset|"Name <email>">...
#
# Options:
#   --global      Store co-authors in ~/.gitconfig (hook still installed per repo)
#   --list        List available presets
#   --show        Show configured co-authors
#   --clear       Remove all configured co-authors
#   --uninstall   Remove the hook (restores any hook it replaced)
#   -h, --help    Show this help
#
# Examples:
#   ./popping.sh claude-opus-5-5
#   ./popping.sh claude-sonnet-5-5 gpt-5-codex
#   ./popping.sh "Jane Doe <jane@example.com>"
set -Eeuo pipefail

CONFIG_KEY="popping.trailer"
HOOK_MARKER="# managed-by: popping"

ANTHROPIC_EMAIL="noreply@anthropic.com"
OPENAI_EMAIL="noreply@openai.com"

# preset id | display name | email
PRESETS="
claude|Claude|$ANTHROPIC_EMAIL
claude-fable-5-1|Claude Fable 5.1|$ANTHROPIC_EMAIL
claude-opus-5-5|Claude Opus 5.5|$ANTHROPIC_EMAIL
claude-sonnet-5-5|Claude Sonnet 5.5|$ANTHROPIC_EMAIL
claude-haiku-4-5|Claude Haiku 4.5|$ANTHROPIC_EMAIL
claude-opus-4-5|Claude Opus 4.5|$ANTHROPIC_EMAIL
claude-sonnet-4-5|Claude Sonnet 4.5|$ANTHROPIC_EMAIL
claude-opus-4-1|Claude Opus 4.1|$ANTHROPIC_EMAIL
claude-opus-4|Claude Opus 4|$ANTHROPIC_EMAIL
claude-sonnet-4|Claude Sonnet 4|$ANTHROPIC_EMAIL
claude-3-7-sonnet|Claude 3.7 Sonnet|$ANTHROPIC_EMAIL
claude-3-5-sonnet|Claude 3.5 Sonnet|$ANTHROPIC_EMAIL
claude-3-5-haiku|Claude 3.5 Haiku|$ANTHROPIC_EMAIL
codex|Codex|$OPENAI_EMAIL
gpt-5-codex|Codex (GPT-5-Codex)|$OPENAI_EMAIL
gpt-5-codex-mini|Codex (GPT-5-Codex-Mini)|$OPENAI_EMAIL
gpt-5.1-codex|Codex (GPT-5.1-Codex)|$OPENAI_EMAIL
gpt-5.1-codex-mini|Codex (GPT-5.1-Codex-Mini)|$OPENAI_EMAIL
gpt-5.1-codex-max|Codex (GPT-5.1-Codex-Max)|$OPENAI_EMAIL
gpt-5.2-codex|Codex (GPT-5.2-Codex)|$OPENAI_EMAIL
gpt-5.3-codex|Codex (GPT-5.3-Codex)|$OPENAI_EMAIL
gpt-5|Codex (GPT-5)|$OPENAI_EMAIL
gpt-5.1|Codex (GPT-5.1)|$OPENAI_EMAIL
gpt-5.2|Codex (GPT-5.2)|$OPENAI_EMAIL
codex-mini-latest|Codex (codex-mini-latest)|$OPENAI_EMAIL
o3|Codex (o3)|$OPENAI_EMAIL
o4-mini|Codex (o4-mini)|$OPENAI_EMAIL
"

die() { echo "error: $*" >&2; exit 1; }

usage() { sed -n '2,/^set -Eeuo/{/^set -Eeuo/d;s/^# \{0,1\}//;p}' "$0"; }

list_presets() {
  echo "$PRESETS" | while IFS='|' read -r id name email; do
    [ -n "$id" ] && printf '  %-20s %s <%s>\n' "$id" "$name" "$email"
  done
}

resolve() {
  local arg=$1 line
  if [[ $arg == *"<"*"@"*">" ]]; then
    echo "$arg"
    return
  fi
  line=$(echo "$PRESETS" | grep -m1 "^${arg}|" || true)
  [ -n "$line" ] || die "unknown preset '$arg' (see --list, or pass \"Name <email>\")"
  IFS='|' read -r _ name email <<<"$line"
  echo "$name <$email>"
}

write_hook() {
  cat <<'HOOK'
#!/usr/bin/env bash
# managed-by: popping
# Appends configured Co-Authored-By trailers (git config popping.trailer)
# unless a Co-Authored-By trailer with the same email is already present.
set -Eeuo pipefail
msg_file=$1

# Run the hook this one replaced, if any.
chained="$(dirname "$0")/commit-msg.pre-popping"
if [ -x "$chained" ]; then "$chained" "$@"; fi

[ "${SKIP_COAUTHOR:-}" = 1 ] && exit 0

# Leave empty messages alone so git can abort the commit as usual.
grep -qv '^[[:space:]]*\(#.*\)\{0,1\}$' "$msg_file" || exit 0

existing=$(git interpret-trailers --parse <"$msg_file" \
  | grep -i '^co-authored-by:' | grep -io '<[^>]*>' | tr '[:upper:]' '[:lower:]' || true)

git config --get-all popping.trailer 2>/dev/null | while IFS= read -r who; do
  [ -n "$who" ] || continue
  email=$(echo "$who" | grep -io '<[^>]*>' | tr '[:upper:]' '[:lower:]' || true)
  if [ -n "$email" ] && grep -qxF "$email" <<<"$existing"; then
    continue
  fi
  git interpret-trailers --in-place --if-exists addIfDifferent \
    --trailer "Co-Authored-By: $who" "$msg_file"
done
HOOK
}

scope=--local
action=add
args=()
while [ $# -gt 0 ]; do
  case $1 in
    --global) scope=--global ;;
    --list) echo "Presets:"; list_presets; exit 0 ;;
    --show) action=show ;;
    --clear) action=clear ;;
    --uninstall) action=uninstall ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) args+=("$1") ;;
  esac
  shift
done

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
hooks_dir=$(git rev-parse --git-path hooks)
hook="$hooks_dir/commit-msg"
backup="$hooks_dir/commit-msg.pre-popping"

case $action in
  show)
    git config "$scope" --get-all "$CONFIG_KEY" || echo "(none configured in $scope scope)"
    exit 0 ;;
  clear)
    git config "$scope" --unset-all "$CONFIG_KEY" || true
    echo "Cleared co-authors ($scope)."
    exit 0 ;;
  uninstall)
    if [ -f "$hook" ] && grep -qF "$HOOK_MARKER" "$hook"; then
      rm "$hook"
      [ -f "$backup" ] && mv "$backup" "$hook"
      echo "Removed hook from $hook."
    else
      echo "No managed hook at $hook."
    fi
    exit 0 ;;
esac

[ ${#args[@]} -gt 0 ] || { usage; exit 1; }

# Install the hook, preserving any unrelated existing hook.
mkdir -p "$hooks_dir"
if [ -f "$hook" ] && ! grep -qF "$HOOK_MARKER" "$hook"; then
  [ -e "$backup" ] && die "$backup already exists; resolve it manually"
  mv "$hook" "$backup"
  echo "Existing commit-msg hook kept as $backup (still runs first)."
fi
write_hook >"$hook"
chmod +x "$hook"

for a in "${args[@]}"; do
  trailer=$(resolve "$a")
  if git config "$scope" --get-all "$CONFIG_KEY" 2>/dev/null | grep -qxF "$trailer"; then
    echo "Already configured: $trailer"
  else
    git config "$scope" --add "$CONFIG_KEY" "$trailer"
    echo "Added: Co-Authored-By: $trailer"
  fi
done

echo "Hook installed at $hook. Skip once with: SKIP_COAUTHOR=1 git commit ..."
