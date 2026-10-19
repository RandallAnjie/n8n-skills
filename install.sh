#!/usr/bin/env bash
# Install n8n-skills (and this fork's Feishu / Suno Gateway skills) into Cursor and/or Claude Code.
# Re-running updates. Same flags plus --uninstall removes what this command would install.
#
# Download overrides (for tests / a non-main ref):
#   N8N_SKILLS_SOURCE=/path/to/checkout   skip network, use local skills/
#   N8N_SKILLS_REPO=RandallAnjie/n8n-skills
#   N8N_SKILLS_REF=main
set -euo pipefail

REPO="${N8N_SKILLS_REPO:-RandallAnjie/n8n-skills}"
REF="${N8N_SKILLS_REF:-main}"
SOURCE="${N8N_SKILLS_SOURCE:-}"

TOOL=""
PROJECT=""
USE_PROJECT=0
ONLY=""
UNINSTALL=0

usage() {
  cat <<'EOF'
Usage: install.sh --tool cursor|claude|both [--project [dir]] [--only feishu|suno] [--uninstall]

  --tool cursor|claude|both   Required. Destination tool skill roots.
  --project [dir]             Project install. dir defaults to the current directory.
  --only feishu               Only Feishu skills (folders named feishu-*).
  --only suno                 Only Suno Gateway skills (folders named suno-gateway-*).
  --uninstall                 Remove the selected skills from the same destinations.

Claude Code:  ~/.claude/skills/<name>   or   <repo>/.claude/skills/<name>
Cursor:       ~/.cursor/skills/<name>   or   <repo>/.cursor/skills/<name>

Examples:
  curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor
  curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool claude
  curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor --project
  curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor --only feishu
  curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor --only suno
  curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor --uninstall
  curl -fsSL https://raw.githubusercontent.com/RandallAnjie/n8n-skills/main/install.sh | bash -s -- --tool cursor --only suno --uninstall
EOF
}

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tool)
      [ $# -ge 2 ] || die "--tool needs cursor|claude|both"
      TOOL=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
      shift 2
      ;;
    --tool=*)
      TOOL=$(printf '%s' "${1#--tool=}" | tr '[:upper:]' '[:lower:]')
      shift
      ;;
    --project)
      USE_PROJECT=1
      if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
        PROJECT="$2"
        shift 2
      else
        PROJECT=""
        shift
      fi
      ;;
    --project=*)
      USE_PROJECT=1
      PROJECT="${1#--project=}"
      shift
      ;;
    --only)
      [ $# -ge 2 ] || die "--only needs feishu or suno"
      ONLY=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
      shift 2
      ;;
    --only=*)
      ONLY=$(printf '%s' "${1#--only=}" | tr '[:upper:]' '[:lower:]')
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1 (try --help)"
      ;;
  esac
done

[ -n "$TOOL" ] || die "--tool is required (cursor|claude|both). See --help."
case "$TOOL" in
  cursor|claude|both) ;;
  *) die "--tool must be cursor, claude, or both" ;;
esac

if [ -n "$ONLY" ] && [ "$ONLY" != "feishu" ] && [ "$ONLY" != "suno" ]; then
  die "--only only accepts feishu or suno"
fi

if [ "$USE_PROJECT" -eq 1 ]; then
  if [ -z "$PROJECT" ]; then
    PROJECT=$PWD
  fi
  [ -d "$PROJECT" ] || die "project directory does not exist: $PROJECT"
  PROJECT=$(cd "$PROJECT" && pwd)
  CURSOR_DEST="$PROJECT/.cursor/skills"
  CLAUDE_DEST="$PROJECT/.claude/skills"
else
  CURSOR_DEST="$HOME/.cursor/skills"
  CLAUDE_DEST="$HOME/.claude/skills"
fi

TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

SKILLS_DIR=""
if [ -n "$SOURCE" ]; then
  [ -d "$SOURCE/skills" ] || die "N8N_SKILLS_SOURCE has no skills/: $SOURCE"
  SKILLS_DIR=$(cd "$SOURCE/skills" && pwd)
else
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v tar >/dev/null 2>&1 || die "tar is required"
  TGZ="$TMP/src.tar.gz"
  URL="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz"
  curl -fsSL "$URL" -o "$TGZ"
  mkdir -p "$TMP/extract"
  tar -xzf "$TGZ" -C "$TMP/extract"
  # tarball root is <repo>-<ref>/skills
  SKILLS_DIR=""
  for d in "$TMP/extract"/*/skills; do
    if [ -d "$d" ]; then
      SKILLS_DIR="$d"
      break
    fi
  done
  [ -n "$SKILLS_DIR" ] || die "tarball from $URL has no skills/ directory"
fi

NAMES_FILE="$TMP/names"
: >"$NAMES_FILE"
for d in "$SKILLS_DIR"/*; do
  [ -d "$d" ] || continue
  [ -f "$d/SKILL.md" ] || continue
  name=$(basename "$d")
  if [ "$ONLY" = "feishu" ]; then
    case "$name" in
      feishu-*) ;;
      *) continue ;;
    esac
  elif [ "$ONLY" = "suno" ]; then
    case "$name" in
      suno-gateway-*) ;;
      *) continue ;;
    esac
  fi
  printf '%s\n' "$name" >>"$NAMES_FILE"
done

if [ ! -s "$NAMES_FILE" ]; then
  die "no matching skills found (only=${ONLY:-all})"
fi

count=0
while IFS= read -r _name; do
  count=$((count + 1))
done <"$NAMES_FILE"

apply_to_dest() {
  dest=$1
  if [ "$UNINSTALL" -eq 1 ]; then
    removed=0
    while IFS= read -r name; do
      target="$dest/$name"
      if [ -e "$target" ]; then
        rm -rf "$target"
        removed=$((removed + 1))
      fi
    done <"$NAMES_FILE"
    printf 'uninstalled %s skill(s) from %s\n' "$removed" "$dest"
  else
    mkdir -p "$dest"
    while IFS= read -r name; do
      target="$dest/$name"
      rm -rf "$target"
      cp -R "$SKILLS_DIR/$name" "$target"
    done <"$NAMES_FILE"
    printf 'installed %s skill(s) to %s\n' "$count" "$dest"
  fi
}

case "$TOOL" in
  cursor) apply_to_dest "$CURSOR_DEST" ;;
  claude) apply_to_dest "$CLAUDE_DEST" ;;
  both)
    apply_to_dest "$CURSOR_DEST"
    apply_to_dest "$CLAUDE_DEST"
    ;;
esac
