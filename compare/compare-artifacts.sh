#!/bin/bash
set -e

# Check required environment variables
: "${COMMENT_MARKER:?COMMENT_MARKER is required}"
: "${BASE_SHA_SHORT:?BASE_SHA_SHORT is required}"
: "${PR_SHA:?PR_SHA is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${DIFF_VIEWER_REPO:?DIFF_VIEWER_REPO is required}"
: "${BASE_DIR:?BASE_DIR is required}"
: "${PR_DIR:?PR_DIR is required}"

# Optional environment variables (with default values)
GITIGNORE_PATTERNS="${GITIGNORE_PATTERNS:-}"
BASE_BRANCH_PREFIX="${BASE_BRANCH_PREFIX:-build}"
PR_BRANCH_PREFIX="${PR_BRANCH_PREFIX:-build}"
GITHUB_SERVER_URL="${GITHUB_SERVER_URL:-https://github.com}"

echo "Starting artifact comparison..."
echo "Base: $BASE_SHA_SHORT, PR: $PR_SHA"

# Initialize report file
# Generate commit URLs and compare URL
BASE_COMMIT_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${BASE_SHA_SHORT}"
HEAD_COMMIT_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${PR_SHA}"
COMPARE_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/compare/${BASE_SHA_SHORT}...${PR_SHA}"

cat > summary.md <<EOF
$COMMENT_MARKER
### 🛠 Build Artifacts Diff

{{DIFF_URL}}

**Base**: [\`main@${BASE_SHA_SHORT}\`](${BASE_COMMIT_URL})
**Head**: [\`PR@${PR_SHA}\`](${HEAD_COMMIT_URL})
**Compare**: [${BASE_SHA_SHORT}...${PR_SHA}](${COMPARE_URL})

EOF

# Initialize statistics (will be calculated from Git diff later)
ADDED=0
REMOVED=0
MODIFIED=0

# Format artifacts (run before copying)
if [ -n "$PRE_PUSH_SHELL" ]; then
  echo "--------- [$BASE_DIR] Formatting base artifacts... ---------"
  eval "$PRE_PUSH_SHELL \"$BASE_DIR\""

  echo "--------- [$PR_DIR] Formatting PR artifacts... ---------"
  eval "$PRE_PUSH_SHELL \"$PR_DIR\""
else
  echo "No format command specified, skipping formatting"
fi

# Push to diff-viewer repository
echo "Pushing artifacts to $DIFF_VIEWER_REPO..."
MAIN_BRANCH="${BASE_BRANCH_PREFIX}-${PR_NUMBER}-${BASE_SHA_SHORT}"
PR_BRANCH="${PR_BRANCH_PREFIX}-${PR_NUMBER}"

# Extract host from GITHUB_SERVER_URL (remove https:// prefix)
GITHUB_HOST="${GITHUB_SERVER_URL#https://}"
GITHUB_HOST="${GITHUB_HOST#http://}"

if git clone "https://x-access-token:${GH_TOKEN}@${GITHUB_HOST}/${DIFF_VIEWER_REPO}.git" diff-viewer 2>&1; then
  cd diff-viewer
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"

  echo "Using gitignore patterns:"
  echo "$GITIGNORE_PATTERNS"

  # 1. Create/update base branch
  echo "[BASE] Creating/updating branch: $MAIN_BRANCH"
  git fetch origin

  # Create branch without checking if remote exists
  git checkout -b "$MAIN_BRANCH"

  # Copy base artifacts (already formatted)
  # Remove all files except .git directory
  echo "[BASE] Working Directory: $(pwd)"
  echo "[BASE] Remove existing files except .git"
  find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

  echo "[BASE] Current git status before copy:"
  git status

  # Create .gitignore first (so exclusions take effect before copying)
  > .gitignore
  for pattern in $GITIGNORE_PATTERNS; do
    echo "$pattern" >> .gitignore
  done

  echo "[BASE] Verify directory is empty (except .git and .gitignore)"
  NON_GIT_FILES=$(find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.gitignore' | wc -l)
  if [ "$NON_GIT_FILES" -ne 0 ]; then
    echo "[BASE] ERROR: Directory is not empty before copy"
    find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.gitignore'
    exit 1
  fi

  echo "[BASE] Copying artifacts from ../$BASE_DIR"
  if [ ! -d "../${BASE_DIR}" ]; then
    echo "[BASE] ERROR: Source directory does not exist: ../$BASE_DIR"
    exit 1
  fi

  cp -r "../${BASE_DIR}/." . || {
    echo "[BASE] ERROR: Failed to copy artifacts"
    exit 1
  }

  echo "[BASE] Verify copy completed successfully"
  COPIED_FILES=$(find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.gitignore' | wc -l)
  echo "[BASE] Copied $COPIED_FILES top-level items"
  if [ "$COPIED_FILES" -eq 0 ]; then
    echo "[BASE] WARNING: No files were copied"
  fi

  git add -A
  git status
  if git diff --staged --quiet; then
    echo "[BASE] No changes in main branch artifacts"
  else
    git status
    git commit -m "build: ${GITHUB_REPOSITORY}#${BASE_SHA_SHORT}" --allow-empty
    git push origin "$MAIN_BRANCH" -f
  fi

  # 2. Create/update PR branch
  echo "[PR] Creating/updating branch: $PR_BRANCH from $MAIN_BRANCH"

  # Always create from latest main branch (to avoid comparison with old base)
  git checkout -B "$PR_BRANCH" "$MAIN_BRANCH"

  # Copy PR artifacts (already formatted)
  # Remove all files except .git directory
  echo "[PR] Working Directory: $(pwd)"
  echo "[PR] Remove existing files except .git"
  find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

  # Create .gitignore first (so exclusions take effect before copying)
  > .gitignore
  for pattern in $GITIGNORE_PATTERNS; do
    echo "$pattern" >> .gitignore
  done

  echo "[PR] Verify directory is empty (except .git and .gitignore)"
  NON_GIT_FILES=$(find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.gitignore' | wc -l)
  if [ "$NON_GIT_FILES" -ne 0 ]; then
    echo "[PR] ERROR: Directory is not empty before copy"
    find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.gitignore'
    exit 1
  fi

  echo "[PR] Copying artifacts from ../$PR_DIR"
  if [ ! -d "../${PR_DIR}" ]; then
    echo "[PR] ERROR: Source directory does not exist: ../$PR_DIR"
    exit 1
  fi

  cp -r "../${PR_DIR}/." . || {
    echo "[PR] ERROR: Failed to copy artifacts"
    exit 1
  }

  echo "[PR] Verify copy completed successfully"
  COPIED_FILES=$(find . -mindepth 1 -maxdepth 1 ! -name '.git' ! -name '.gitignore' | wc -l)
  echo "[PR] Copied $COPIED_FILES top-level items"
  if [ "$COPIED_FILES" -eq 0 ]; then
    echo "[PR] WARNING: No files were copied"
  fi

  git add -A
  if git diff --staged --quiet; then
    git commit -m "No changes in PR branch artifacts" --allow-empty
  else
    git commit -m "build: ${GITHUB_REPOSITORY}#${PR_SHA}" --allow-empty
  fi

  # Get accurate statistics from Git diff
  echo "Calculating Git diff statistics between $MAIN_BRANCH and $PR_BRANCH..."
  ADDED=$(git diff --name-status "$MAIN_BRANCH" "$PR_BRANCH" | grep "^A" | wc -l | tr -d ' \n')
  MODIFIED=$(git diff --name-status "$MAIN_BRANCH" "$PR_BRANCH" | grep "^M" | wc -l | tr -d ' \n')
  REMOVED=$(git diff --name-status "$MAIN_BRANCH" "$PR_BRANCH" | grep "^D" | wc -l | tr -d ' \n')

  # Set default values (if empty)
  ADDED=${ADDED:-0}
  MODIFIED=${MODIFIED:-0}
  REMOVED=${REMOVED:-0}

  echo "Git Statistics: Added=$ADDED, Removed=$REMOVED, Modified=$MODIFIED"

  git push origin -f "$PR_BRANCH"

  cd ..

  # 3. Create or update Pull Request
  echo "Creating or updating Pull Request..."

  # Build summary content
  SUMMARY=""
  if [ "${ADDED:-0}" -gt 0 ]; then
    SUMMARY="${SUMMARY}- 🟢 Added: $ADDED files"$'\n'
  fi
  if [ "${REMOVED:-0}" -gt 0 ]; then
    SUMMARY="${SUMMARY}- 🔴 Removed: $REMOVED files"$'\n'
  fi
  if [ "${MODIFIED:-0}" -gt 0 ]; then
    SUMMARY="${SUMMARY}- 🟡 Modified: $MODIFIED files"$'\n'
  fi
  if [ "${ADDED:-0}" -eq 0 ] && [ "${REMOVED:-0}" -eq 0 ] && [ "${MODIFIED:-0}" -eq 0 ]; then
    SUMMARY="- ✅ No changes detected"$'\n'
  fi

  # Create PR body
  SOURCE_PR_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/pull/${PR_NUMBER}"
  PR_BODY="# Build Artifacts Diff

**Repository**: [${GITHUB_REPOSITORY}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY})
**PR**: [#${PR_NUMBER}](${SOURCE_PR_URL})
**Base**: [\`main@${BASE_SHA_SHORT}\`](${BASE_COMMIT_URL})
**Head**: [\`PR@${PR_SHA}\`](${HEAD_COMMIT_URL})
**Source Compare**: [${BASE_SHA_SHORT}...${PR_SHA}](${COMPARE_URL})

## Summary
${SUMMARY}"

  # Search for existing PR
  EXISTING_PR=$(gh pr list --repo "$DIFF_VIEWER_REPO" --head "$PR_BRANCH" --base "$MAIN_BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")

  if [ -n "$EXISTING_PR" ]; then
    echo "Updating existing PR #$EXISTING_PR"
    gh pr edit "$EXISTING_PR" --repo "$DIFF_VIEWER_REPO" --body "$PR_BODY"
    DIFF_URL="${GITHUB_SERVER_URL}/${DIFF_VIEWER_REPO}/pull/${EXISTING_PR}"
  else
    echo "Creating new Pull Request"
    PR_TITLE="Build diff for ${GITHUB_REPOSITORY}#${PR_NUMBER}"
    CREATED_PR=$(gh pr create --repo "$DIFF_VIEWER_REPO" --base "$MAIN_BRANCH" --head "$PR_BRANCH" --title "$PR_TITLE" --body "$PR_BODY" 2>&1)

    if echo "$CREATED_PR" | grep -q "${GITHUB_SERVER_URL}"; then
      DIFF_URL=$(echo "$CREATED_PR" | grep -o "${GITHUB_SERVER_URL}[^ ]*")
    else
      echo "Warning: Could not extract PR URL from: $CREATED_PR"
      DIFF_URL="${GITHUB_SERVER_URL}/${DIFF_VIEWER_REPO}/compare/${MAIN_BRANCH}...${PR_BRANCH}"
    fi
  fi

  echo "DIFF_URL=$DIFF_URL" >> "$GITHUB_OUTPUT"
  echo "Diff PR URL: $DIFF_URL"
else
  echo "Error: Could not clone diff-viewer repository."
  echo "This may happen if:"
  echo "  1. The repository does not exist: ${GITHUB_SERVER_URL}/${DIFF_VIEWER_REPO}"
  echo "  2. The token does not have access to the repository"
  echo "  3. The repository settings do not allow access from this workflow"
  exit 1
fi

# Output summary to report
echo "" >> summary.md
echo "#### Summary" >> summary.md
if [ "${ADDED:-0}" -gt 0 ]; then
  echo "- 🟢 Added: $ADDED files" >> summary.md
fi
if [ "${REMOVED:-0}" -gt 0 ]; then
  echo "- 🔴 Removed: $REMOVED files" >> summary.md
fi
if [ "${MODIFIED:-0}" -gt 0 ]; then
  echo "- 🟡 Modified: $MODIFIED files" >> summary.md
fi

# Message when all values are 0
if [ "${ADDED:-0}" -eq 0 ] && [ "${REMOVED:-0}" -eq 0 ] && [ "${MODIFIED:-0}" -eq 0 ]; then
  echo "- ✅ No changes detected" >> summary.md
fi

echo "Comparison complete. Report generated in summary.md"
