#!/bin/bash
set -e

# ============================================================================
# release.sh - Semantic Versioning Release Script
# ============================================================================
#
# Reads conventional commits since the last tag, determines version bump,
# updates version in project files, generates CHANGELOG.md, commits, tags,
# and pushes to trigger GitHub Actions build.
#
# Usage:
#   ./release.sh              # Auto-detect bump type from commits
#   ./release.sh --patch      # Force patch bump  (x.y.Z)
#   ./release.sh --minor      # Force minor bump  (x.Y.0)
#   ./release.sh --major      # Force major bump  (X.0.0)
#   ./release.sh --dry-run    # Preview without making changes
#
# Commit message convention (Conventional Commits):
#   feat: ...     → minor bump
#   fix: ...      → patch bump
#   perf: ...     → patch bump
#   refactor: ... → patch bump
#   docs: ...     → patch bump (included in changelog)
#   BREAKING CHANGE in footer or feat!:/fix!: → major bump
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

DRY_RUN=false
FORCE_BUMP=""

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=true ;;
        --patch)    FORCE_BUMP="patch" ;;
        --minor)    FORCE_BUMP="minor" ;;
        --major)    FORCE_BUMP="major" ;;
        -h|--help)
            sed -n '/^# Usage:/,/^# =====/p' "$0" | head -n -1 | sed 's/^# //'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Run './release.sh --help' for usage."
            exit 1
            ;;
    esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────

get_current_version() {
    # Read from the latest git tag, fallback to 0.0.0
    local tag
    tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -z "$tag" ]]; then
        echo "0.0.0"
    else
        echo "${tag#v}"
    fi
}

bump_version() {
    local version="$1"
    local bump_type="$2"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"

    case "$bump_type" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "${major}.$((minor + 1)).0" ;;
        patch) echo "${major}.${minor}.$((patch + 1))" ;;
    esac
}

# ── Analyze commits ─────────────────────────────────────────────────────────

analyze_commits() {
    local current_version="$1"
    local last_tag=""

    if git rev-parse "v${current_version}" >/dev/null 2>&1; then
        last_tag="v${current_version}"
    fi

    local log_range
    if [[ -n "$last_tag" ]]; then
        log_range="${last_tag}..HEAD"
    else
        log_range="HEAD"
    fi

    local has_breaking=false
    local has_feat=false
    local has_fix=false

    # Collect commits grouped by type
    FEAT_COMMITS=()
    FIX_COMMITS=()
    PERF_COMMITS=()
    REFACTOR_COMMITS=()
    DOCS_COMMITS=()
    OTHER_COMMITS=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        # Check for BREAKING CHANGE
        if [[ "$line" =~ BREAKING[[:space:]]CHANGE ]] || [[ "$line" =~ ^[a-z]+\!: ]]; then
            has_breaking=true
        fi

        # Extract type and description
        if [[ "$line" =~ ^feat(\(.+\))?\!?:[[:space:]]*(.*) ]]; then
            has_feat=true
            FEAT_COMMITS+=("${BASH_REMATCH[2]}")
        elif [[ "$line" =~ ^fix(\(.+\))?\!?:[[:space:]]*(.*) ]]; then
            has_fix=true
            FIX_COMMITS+=("${BASH_REMATCH[2]}")
        elif [[ "$line" =~ ^perf(\(.+\))?\!?:[[:space:]]*(.*) ]]; then
            has_fix=true
            PERF_COMMITS+=("${BASH_REMATCH[2]}")
        elif [[ "$line" =~ ^refactor(\(.+\))?\!?:[[:space:]]*(.*) ]]; then
            REFACTOR_COMMITS+=("${BASH_REMATCH[2]}")
        elif [[ "$line" =~ ^docs(\(.+\))?\!?:[[:space:]]*(.*) ]]; then
            DOCS_COMMITS+=("${BASH_REMATCH[2]}")
        elif [[ "$line" =~ ^(build|ci|chore|style|test)(\(.+\))?\!?:[[:space:]]*(.*) ]]; then
            # These don't appear in changelog by default
            :
        else
            OTHER_COMMITS+=("$line")
        fi
    done < <(git log "$log_range" --pretty=format:"%s" 2>/dev/null)

    # Determine bump type
    if [[ -n "$FORCE_BUMP" ]]; then
        echo "$FORCE_BUMP"
    elif $has_breaking; then
        echo "major"
    elif $has_feat; then
        echo "minor"
    elif $has_fix; then
        echo "patch"
    elif [[ ${#REFACTOR_COMMITS[@]} -gt 0 ]] || [[ ${#DOCS_COMMITS[@]} -gt 0 ]] || [[ ${#OTHER_COMMITS[@]} -gt 0 ]]; then
        echo "patch"
    else
        echo ""
    fi
}

# ── Generate changelog entry ────────────────────────────────────────────────

generate_changelog_entry() {
    local version="$1"
    local date
    date=$(date +%Y-%m-%d)

    local entry=""
    entry+="## [${version}](../../releases/tag/v${version}) (${date})"$'\n'
    entry+=""$'\n'

    if [[ ${#FEAT_COMMITS[@]} -gt 0 ]]; then
        entry+="### ✨ Features"$'\n\n'
        for msg in "${FEAT_COMMITS[@]}"; do
            entry+="- ${msg}"$'\n'
        done
        entry+=""$'\n'
    fi

    if [[ ${#FIX_COMMITS[@]} -gt 0 ]]; then
        entry+="### 🐛 Bug Fixes"$'\n\n'
        for msg in "${FIX_COMMITS[@]}"; do
            entry+="- ${msg}"$'\n'
        done
        entry+=""$'\n'
    fi

    if [[ ${#PERF_COMMITS[@]} -gt 0 ]]; then
        entry+="### ⚡ Performance"$'\n\n'
        for msg in "${PERF_COMMITS[@]}"; do
            entry+="- ${msg}"$'\n'
        done
        entry+=""$'\n'
    fi

    if [[ ${#REFACTOR_COMMITS[@]} -gt 0 ]]; then
        entry+="### ♻️ Refactors"$'\n\n'
        for msg in "${REFACTOR_COMMITS[@]}"; do
            entry+="- ${msg}"$'\n'
        done
        entry+=""$'\n'
    fi

    if [[ ${#DOCS_COMMITS[@]} -gt 0 ]]; then
        entry+="### 📖 Documentation"$'\n\n'
        for msg in "${DOCS_COMMITS[@]}"; do
            entry+="- ${msg}"$'\n'
        done
        entry+=""$'\n'
    fi

    echo "$entry"
}

# ── Update version in project files ─────────────────────────────────────────

update_version_in_files() {
    local old_version="$1"
    local new_version="$2"

    echo "   📝 Updating version: ${old_version} → ${new_version}"

    # Extract major.minor for CFBundleShortVersionString
    local short_version="${new_version}"

    # Calculate build number: major*10000 + minor*100 + patch
    local major minor patch
    IFS='.' read -r major minor patch <<< "$new_version"
    local build_number=$((major * 10000 + minor * 100 + patch))

    # 1. Update HimiRecorder/Info.plist
    if [[ -f "HimiRecorder/Info.plist" ]]; then
        sed -i '' "s|<string>${old_version}</string>\(.*CFBundleShortVersionString\)\{0\}|<string>${short_version}</string>|" "HimiRecorder/Info.plist" 2>/dev/null || true
        # More precise: replace the value after CFBundleShortVersionString
        python3 -c "
import re, sys
with open('HimiRecorder/Info.plist', 'r') as f:
    content = f.read()
content = re.sub(
    r'(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*(</string>)',
    r'\g<1>${short_version}\2',
    content
)
content = re.sub(
    r'(<key>CFBundleVersion</key>\s*<string>)[^<]*(</string>)',
    r'\g<1>${build_number}\2',
    content
)
with open('HimiRecorder/Info.plist', 'w') as f:
    f.write(content)
"
        echo "      ✓ HimiRecorder/Info.plist"
    fi

    # 2. Update build.sh (the inline Info.plist)
    if [[ -f "build.sh" ]]; then
        python3 -c "
import re
with open('build.sh', 'r') as f:
    content = f.read()
content = re.sub(
    r'(<key>CFBundleShortVersionString</key>\s*\t<string>)[^<]*(</string>)',
    r'\g<1>${short_version}\2',
    content
)
content = re.sub(
    r'(<key>CFBundleVersion</key>\s*\t<string>)[^<]*(</string>)',
    r'\g<1>${build_number}\2',
    content
)
with open('build.sh', 'w') as f:
    f.write(content)
"
        echo "      ✓ build.sh"
    fi
}

# ── Update CHANGELOG.md ─────────────────────────────────────────────────────

update_changelog() {
    local entry="$1"

    if [[ ! -f "CHANGELOG.md" ]]; then
        cat > "CHANGELOG.md" << 'HEADER'
# Changelog

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

HEADER
    fi

    # Insert new entry after the header (after the first blank line following "commit guidelines")
    local tmpfile
    tmpfile=$(mktemp)

    python3 -c "
import sys

entry = '''${entry}'''

with open('CHANGELOG.md', 'r') as f:
    content = f.read()

# Find insertion point: after the header block
marker = 'commit guidelines.'
idx = content.find(marker)
if idx != -1:
    idx = content.find('\n', idx)
    if idx != -1:
        # Skip blank lines after marker
        while idx + 1 < len(content) and content[idx + 1] == '\n':
            idx += 1
        content = content[:idx + 1] + '\n' + entry + content[idx + 1:]
else:
    # No header found, prepend
    content = entry + '\n' + content

with open('CHANGELOG.md', 'w') as f:
    f.write(content)
"
    echo "      ✓ CHANGELOG.md"
}

# ── Main ─────────────────────────────────────────────────────────────────────

echo ""
echo "🚀 Himi Recorder - Release Script"
echo "─────────────────────────────────────"

# Ensure we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not a git repository."
    exit 1
fi

# Ensure working tree is clean (except for untracked files)
if [[ -n "$(git diff --cached --name-only)" ]]; then
    echo "❌ You have staged changes. Please commit or stash them first."
    exit 1
fi

CURRENT_VERSION=$(get_current_version)
echo "📌 Current version: v${CURRENT_VERSION}"

# Analyze commits
BUMP_TYPE=$(analyze_commits "$CURRENT_VERSION")

if [[ -z "$BUMP_TYPE" ]]; then
    echo ""
    echo "ℹ️  No releasable commits found since v${CURRENT_VERSION}."
    echo "   Commit messages should start with: feat:, fix:, perf:, refactor:, docs:"
    echo ""
    exit 0
fi

NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$BUMP_TYPE")

echo "📊 Bump type: ${BUMP_TYPE}"
echo "🆕 New version: v${NEW_VERSION}"
echo ""

# Show what will be included
CHANGELOG_ENTRY=$(generate_changelog_entry "$NEW_VERSION")
echo "── Changelog Preview ──"
echo "$CHANGELOG_ENTRY"
echo "───────────────────────"
echo ""

if $DRY_RUN; then
    echo "🏃 Dry run complete. No changes were made."
    exit 0
fi

# Apply changes
echo "📦 Applying changes..."
update_version_in_files "$CURRENT_VERSION" "$NEW_VERSION"
update_changelog "$CHANGELOG_ENTRY"

# Git commit and tag
echo ""
echo "📝 Committing..."
git add HimiRecorder/Info.plist build.sh CHANGELOG.md
git commit -m "chore(release): v${NEW_VERSION}"

echo "🏷️  Tagging v${NEW_VERSION}..."
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"

# Push
echo "🚀 Pushing to remote..."
git push
git push origin "v${NEW_VERSION}"

echo ""
echo "✅ Released v${NEW_VERSION}!"
echo ""
echo "   GitHub Actions will now build and create the release."
echo "   Check: https://github.com/$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:\/]\(.*\)\.git/\1/' 2>/dev/null || echo '<owner>/<repo>')/actions"
echo ""
