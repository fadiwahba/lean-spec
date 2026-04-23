#!/usr/bin/env bash
#
# lib/prd-parser.sh — extract feature sections from a project-level PRD.md.
#
# Feeds /lean-spec:decompose-prd. Matches the canonical shape produced by
# /lean-spec:brainstorm (i.e. templates/PRD.md):
#
#   ## 4. Features
#
#   ### 4.1 Add Task Input
#   <body>
#
#   ### 4.2 Stats Bar
#   <body>
#
# But is forgiving: it also accepts `## Features` (no number) and `###` sub-
# sections with or without a numeric prefix.
#
# Functions:
#   list_feature_slugs <prd-path>        → emits one slug per line
#   feature_scope <prd-path> <slug>      → emits the opening paragraph of the
#                                           feature section (trimmed)
#   feature_section_title <prd-path> <slug> → emits the full heading text

# Slugify a heading into a kebab-case slug suitable for a directory name.
# Handles "4.1 Add Task Input" → "add-task-input".
_slugify() {
  local s="$1"
  # strip leading numbering like "4.1 " or "1) "
  s=$(echo "$s" | sed -E 's/^[0-9]+(\.[0-9]+)*[[:space:]]+//; s/^[0-9]+\)[[:space:]]+//')
  # lowercase
  s=$(echo "$s" | tr '[:upper:]' '[:lower:]')
  # replace non-alphanumeric with single hyphens, trim
  s=$(echo "$s" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  echo "$s"
}

# Extract the "Features" section of a PRD: everything from `## <N>. Features`
# (or `## Features`) until the next `## ` heading.
_extract_features_block() {
  local prd="$1"
  awk '
    BEGIN { in_features = 0 }
    /^## / {
      if (in_features) exit
      if ($0 ~ /^##[[:space:]]+([0-9]+\.[[:space:]]+)?Features[[:space:]]*$/) in_features = 1
      else in_features = 0
      next
    }
    in_features { print }
  ' "$prd"
}

# Emit one slug per line for each feature sub-section.
list_feature_slugs() {
  local prd="$1"
  [ -f "$prd" ] || return 1
  _extract_features_block "$prd" | awk '/^### / { sub(/^### /, ""); print }' | while IFS= read -r heading; do
    _slugify "$heading"
  done
}

# Emit the full heading text for a given slug (best-match).
feature_section_title() {
  local prd="$1" target_slug="$2"
  [ -f "$prd" ] || return 1
  _extract_features_block "$prd" | awk '/^### / { sub(/^### /, ""); print }' | while IFS= read -r heading; do
    if [ "$(_slugify "$heading")" = "$target_slug" ]; then
      echo "$heading"
      return 0
    fi
  done
}

# Emit the opening paragraph (or first bullet block) of a feature section.
# Stops at the next `### ` or `## ` heading, or the end of the Features block.
feature_scope() {
  local prd="$1" target_slug="$2"
  [ -f "$prd" ] || return 1
  local target_title
  target_title=$(feature_section_title "$prd" "$target_slug")
  [ -z "$target_title" ] && return 1

  _extract_features_block "$prd" | awk -v target="$target_title" '
    /^### / {
      sub(/^### /, "", $0)
      if ($0 == target) { capturing = 1; next }
      if (capturing) exit
    }
    capturing { print }
  ' | sed -E '/^$/d; /^###/q' | head -20
}
