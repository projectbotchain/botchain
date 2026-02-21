#!/usr/bin/env bash
# Ralph review loop - review completed tasks, apply fixes, archive, commit
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"  # Git repo is in same dir as script
PLAN_FILE="$SCRIPT_DIR/IMPLEMENTATION_PLAN.md"
ARCHIVE_FILE="$SCRIPT_DIR/ARCHIVE2.md"
LOG_DIR="$SCRIPT_DIR/logs"

# Codex configuration (model name based on codex CLI docs/help in this environment)
CODEX_MODEL="${CODEX_MODEL:-gpt-5.3-codex-spark}"
CODEX_REASONING="${CODEX_REASONING:-xhigh}"

mkdir -p "$LOG_DIR"

# Capture associated specs from the current plan before modifications
mapfile -t ASSOCIATED_SPECS < <(grep -oE 'specs/[^` )]+' "$PLAN_FILE" | sort -u || true)

if [[ ! -f "$PLAN_FILE" ]]; then
	echo "Error: $PLAN_FILE not found"
	exit 1
fi

if [[ ! -f "$ARCHIVE_FILE" ]]; then
	cat <<'EOF' >"$ARCHIVE_FILE"
# Implementation Plan Archive
EOF
fi

mapfile -t COMPLETED_ITEMS < <(grep '^- \[x\]' "$PLAN_FILE" || true)

if [[ "${#COMPLETED_ITEMS[@]}" -eq 0 ]]; then
	echo "No completed tasks found in $PLAN_FILE"
	exit 0
fi

ARCHIVE_HEADER_ADDED=0
ARCHIVE_SECTION="## Review Signoff ($(date +%Y-%m-%d)) - SIGNED OFF"

archive_item() {
	local block="$1"
	if [[ "$ARCHIVE_HEADER_ADDED" -eq 0 ]]; then
		printf "\n%s\n\n" "$ARCHIVE_SECTION" >>"$ARCHIVE_FILE"
		ARCHIVE_HEADER_ADDED=1
	fi
	printf "%s\n\n" "$block" >>"$ARCHIVE_FILE"
}

get_item_block() {
	local item="$1"
	awk -v target="$item" '
    BEGIN { found=0 }
    {
      if ($0 ~ /^## /) { h2 = $0 }
      if ($0 ~ /^### /) { h3 = $0 }

      if (!found && $0 == target) {
        found=1;
        print "## Focus context";
        if (h2 != "") print h2;
        if (h3 != "") print h3;
        print $0;
        next;
      }
      if (found) {
        if ($0 ~ /^- \[/ || $0 ~ /^## / || $0 ~ /^# /) {
          exit;
        }
        print $0;
      }
    }
  ' "$PLAN_FILE"
}

remove_item_from_plan() {
	local item="$1"
	awk -v target="$item" '
    BEGIN { in_block=0 }
    {
      if (!in_block && $0 == target) {
        in_block=1;
        next;
      }
      if (in_block) {
        if ($0 ~ /^- \[/ || $0 ~ /^## / || $0 ~ /^# /) {
          in_block=0;
          print $0;
        }
        next;
      }
      print $0;
    }
  ' "$PLAN_FILE" >"${PLAN_FILE}.tmp" && mv "${PLAN_FILE}.tmp" "$PLAN_FILE"
}

for item in "${COMPLETED_ITEMS[@]}"; do
	timestamp=$(date +%Y%m%d-%H%M%S)
	log_file="$LOG_DIR/review-${timestamp}.log"

	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "Reviewing item: $item"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

	cat <<EOF_PROMPT | codex exec \
		--dangerously-bypass-approvals-and-sandbox \
		-m "$CODEX_MODEL" \
		-c "reasoning=$CODEX_REASONING" \
		-C "$REPO_ROOT" \
		- 2>&1 | tee "$log_file"
You are reviewing a completed task from @ralph/IMPLEMENTATION_PLAN.md.

Task line:
$item

Instructions:
1) Review code, tests, and docs relevant to the task. Identify any missing fixes or regressions.
2) Make necessary changes, run relevant tests, and ensure the task is truly complete.
3) Update @ralph/IMPLEMENTATION_PLAN.md if you find issues or need follow-ups.
4) If the task is fully correct, mark it as signed off. Do NOT leave stubs.
5) Do NOT add new tasks unless strictly necessary.
6) Do not archive the task yourself; the outer loop will archive after your review.
7) Commit changes with a clear message ONLY when the task is signed off.

Output only "SIGNED_OFF" when complete, otherwise output "NEEDS_WORK".
EOF_PROMPT

	if grep -q "SIGNED_OFF" "$log_file"; then
		if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
			echo "Changes detected; committing review update."
			git -C "$REPO_ROOT" add -A
			git -C "$REPO_ROOT" commit -m "review: ${item#- [x] }" || true
		fi

		if grep -Fqx -- "$item" "$PLAN_FILE"; then
			block="$(get_item_block "$item")"
			remove_item_from_plan "$item"
			if [[ -n "$block" ]]; then
				archive_item "$block"
			else
				archive_item "$item"
			fi
		else
			archive_item "$item"
		fi

		git -C "$REPO_ROOT" add "$PLAN_FILE" "$ARCHIVE_FILE"
		git -C "$REPO_ROOT" commit -m "archive: ${item#- [x] }" || true
	else
		echo "Item not signed off; leaving in plan: $item"
	fi
done

# If no remaining tasks, archive associated specs captured at start
remaining=$(grep '^- \[ \]' "$PLAN_FILE" | wc -l || true)
completed_left=$(grep '^- \[x\]' "$PLAN_FILE" | wc -l || true)

if [[ "$remaining" -eq 0 && "$completed_left" -eq 0 ]]; then
	for spec in "${ASSOCIATED_SPECS[@]}"; do
		if [[ -f "$REPO_ROOT/$spec" ]]; then
			mkdir -p "$REPO_ROOT/specs/archive"
			mv "$REPO_ROOT/$spec" "$REPO_ROOT/specs/archive/"
		fi
	done
	if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
		git -C "$REPO_ROOT" add -A
		git -C "$REPO_ROOT" commit -m "archive: specs" || true
	fi
fi

echo "Review loop complete."
