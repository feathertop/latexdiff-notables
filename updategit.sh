#!/bin/bash

# ==============================================================
# updategit.sh — Initialize, commit, create repo, and push to GitHub
# ==============================================================

# --- Configuration (edit these) ---
REPO_NAME="latexdiff-notables"
GITHUB_USERNAME="feathertop"
BRANCH="main"
COMMIT_MSG="Initial commit"
REPO_DESCRIPTION="Make latexdiff more reliable when dealing with complex table structures. The script will jump over tables and only show diff in texts."
REPO_VISIBILITY="public"  # "public" or "private"

# --- Git Identity (edit these) ---
GIT_USER_NAME="Michael Zhang"
GIT_USER_EMAIL="your-email@example.com"  # Change to your actual email

# ==============================================================
# Helper functions
# ==============================================================

print_step() {
  echo ""
  echo "========================================"
  echo ">> $1"
  echo "========================================"
}

print_success() {
  echo "✅ $1"
}

print_warning() {
  echo "⚠️  $1"
}

print_error() {
  echo "❌ $1"
}

check_command() {
  if ! command -v "$1" &>/dev/null; then
    return 1
  fi
  return 0
}

# ==============================================================
# Step 0: Check prerequisites
# ==============================================================
print_step "Checking prerequisites"

# Check if git is installed
if ! check_command git; then
  print_error "Git is not installed. Please install it first."
  exit 1
fi
print_success "Git is installed."

# Check if gh (GitHub CLI) is installed
GH_AVAILABLE=false
if check_command gh; then
  GH_AVAILABLE=true
  print_success "GitHub CLI (gh) is installed."
else
  print_warning "GitHub CLI (gh) is not installed."
  echo "   We need it to create repos from the command line."
  echo "   Installing via Homebrew..."
  if check_command brew; then
    brew install gh
    if check_command gh; then
      GH_AVAILABLE=true
      print_success "GitHub CLI installed successfully."
    else
      print_error "Failed to install GitHub CLI."
    fi
  else
    print_warning "Homebrew not found. Trying direct install..."
    echo "   You can install manually: https://cli.github.com/"
    echo "   Or install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  fi
fi

# ==============================================================
# Step 1: Configure Git identity
# ==============================================================
print_step "Configuring Git identity"

CURRENT_NAME=$(git config --global user.name 2>/dev/null)
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null)

if [ -z "$CURRENT_NAME" ]; then
  git config --global user.name "$GIT_USER_NAME"
  print_success "Set git user.name to '$GIT_USER_NAME'"
else
  print_success "Git user.name already set to '$CURRENT_NAME'"
fi

if [ -z "$CURRENT_EMAIL" ]; then
  git config --global user.email "$GIT_USER_EMAIL"
  print_success "Set git user.email to '$GIT_USER_EMAIL'"
else
  print_success "Git user.email already set to '$CURRENT_EMAIL'"
fi

# ==============================================================
# Step 2: Test network connectivity
# ==============================================================
print_step "Testing network connectivity to GitHub"

test_connection() {
  curl -s --max-time 10 -o /dev/null -w "%{http_code}" https://github.com
}

HTTP_CODE=$(test_connection)

if [ "$HTTP_CODE" -eq 000 ] 2>/dev/null; then
  print_warning "Cannot reach github.com via HTTPS."
  echo "   Attempting fixes..."

  # Try flushing DNS
  echo "   Flushing DNS cache..."
  sudo dscacheutil -flushcache 2>/dev/null
  sudo killall -HUP mDNSResponder 2>/dev/null
  sleep 2

  # Try setting SSL backend
  echo "   Setting SSL backend to SecureTransport..."
  git config --global http.sslBackend SecureTransport 2>/dev/null

  # Re-test
  HTTP_CODE=$(test_connection)
  if [ "$HTTP_CODE" -eq 000 ] 2>/dev/null; then
    print_warning "Still cannot reach github.com via HTTPS."
    echo "   Will attempt SSH as fallback later."
    USE_SSH=true
  else
    print_success "Connection restored after fixes."
    USE_SSH=false
  fi
else
  print_success "GitHub is reachable (HTTP $HTTP_CODE)."
  USE_SSH=false
fi

# ==============================================================
# Step 3: Authenticate with GitHub CLI
# ==============================================================
if [ "$GH_AVAILABLE" = true ]; then
  print_step "Checking GitHub CLI authentication"

  if ! gh auth status &>/dev/null; then
    print_warning "Not authenticated with GitHub CLI."
    echo "   Starting login process..."
    if [ "$USE_SSH" = true ]; then
      gh auth login --git-protocol ssh
    else
      gh auth login --git-protocol https
    fi

    if ! gh auth status &>/dev/null; then
      print_error "GitHub CLI authentication failed."
      echo "   You may need to authenticate manually: gh auth login"
    else
      print_success "Authenticated with GitHub CLI."
    fi
  else
    print_success "Already authenticated with GitHub CLI."
  fi
fi

# ==============================================================
# Step 4: Initialize local Git repository
# ==============================================================
print_step "Initializing local Git repository"

if [ ! -d ".git" ]; then
  git init
  git branch -M "$BRANCH"
  print_success "Initialized new Git repository."
else
  print_success "Git repository already initialized."
fi

# ==============================================================
# Step 5: Stage and commit files
# ==============================================================
print_step "Staging and committing files"

git add .

if git diff --cached --quiet; then
  print_warning "No new changes to commit. Skipping commit."
else
  git commit -m "$COMMIT_MSG"
  print_success "Changes committed."
fi

# ==============================================================
# Step 6: Create GitHub repo if it doesn't exist
# ==============================================================
print_step "Checking if GitHub repository exists"

if [ "$GH_AVAILABLE" = true ]; then
  # Check if repo exists
  if gh repo view "$GITHUB_USERNAME/$REPO_NAME" &>/dev/null; then
    print_success "Repository '$GITHUB_USERNAME/$REPO_NAME' already exists on GitHub."
  else
    echo "   Repository not found. Creating it now..."
    gh repo create "$REPO_NAME" \
      --"$REPO_VISIBILITY" \
      --description "$REPO_DESCRIPTION" \
      --source . \
      --remote origin 2>/dev/null

    if [ $? -eq 0 ]; then
      print_success "Repository '$GITHUB_USERNAME/$REPO_NAME' created on GitHub."
    else
      # Try without --source flag (older gh versions)
      gh repo create "$GITHUB_USERNAME/$REPO_NAME" \
        --"$REPO_VISIBILITY" \
        --description "$REPO_DESCRIPTION" 2>/dev/null
      if [ $? -eq 0 ]; then
        print_success "Repository created on GitHub."
      else
        print_error "Failed to create repository. You may need to create it manually at https://github.com/new"
      fi
    fi
  fi
else
  print_warning "GitHub CLI not available. Please ensure the repo exists at:"
  echo "   https://github.com/$GITHUB_USERNAME/$REPO_NAME"
  echo "   Or create it at https://github.com/new"
fi

# ==============================================================
# Step 7: Set up remote
# ==============================================================
print_step "Setting up remote origin"

if [ "$USE_SSH" = true ]; then
  REMOTE_URL="git@github.com:$GITHUB_USERNAME/$REPO_NAME.git"
else
  REMOTE_URL="https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
fi

if git remote get-url origin &>/dev/null; then
  CURRENT_REMOTE=$(git remote get-url origin)
  if [ "$CURRENT_REMOTE" != "$REMOTE_URL" ]; then
    echo "   Updating remote from '$CURRENT_REMOTE' to '$REMOTE_URL'"
    git remote set-url origin "$REMOTE_URL"
    print_success "Remote origin updated."
  else
    print_success "Remote origin already correctly set."
  fi
else
  git remote add origin "$REMOTE_URL"
  print_success "Remote origin added: $REMOTE_URL"
fi

# ==============================================================
# Step 8: Pull remote changes (if any) then push
# ==============================================================
print_step "Pushing to GitHub"

# Fetch remote to check for existing commits
git fetch origin "$BRANCH" 2>/dev/null

if git rev-parse "origin/$BRANCH" &>/dev/null; then
  echo "   Remote branch exists. Rebasing local changes on top..."
  git pull --rebase origin "$BRANCH"
  if [ $? -ne 0 ]; then
    print_warning "Rebase had conflicts. Attempting merge instead..."
    git rebase --abort 2>/dev/null
    git pull --no-rebase origin "$BRANCH" --allow-unrelated-histories
    if [ $? -ne 0 ]; then
      print_error "Merge failed. Please resolve conflicts manually, then run:"
      echo "   git add ."
      echo "   git commit -m 'Merge conflicts resolved'"
      echo "   git push -u origin $BRANCH"
      exit 1
    fi
  fi
fi

# Push
git push -u origin "$BRANCH"

if [ $? -eq 0 ]; then
  echo ""
  echo "========================================"
  print_success "All done! Your code is live at:"
  echo "   https://github.com/$GITHUB_USERNAME/$REPO_NAME"
  echo "========================================"
else
  print_error "Push failed."

  # If HTTPS failed, suggest SSH
  if [ "$USE_SSH" != true ]; then
    echo ""
    echo "   HTTPS push failed. Trying SSH as fallback..."
    git remote set-url origin "git@github.com:$GITHUB_USERNAME/$REPO_NAME.git"

    # Check if SSH key exists
    if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ]; then
      echo "   No SSH key found. Generating one..."
      ssh-keygen -t ed25519 -C "$GIT_USER_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
      echo ""
      print_warning "Add this SSH public key to https://github.com/settings/keys :"
      echo ""
      cat "$HOME/.ssh/id_ed25519.pub"
      echo ""
      echo "   After adding the key, run: git push -u origin $BRANCH"
      exit 1
    fi

    git push -u origin "$BRANCH"
    if [ $? -eq 0 ]; then
      echo ""
      print_success "Pushed successfully via SSH!"
      echo "   https://github.com/$GITHUB_USERNAME/$REPO_NAME"
    else
      print_error "SSH push also failed."
      echo "   Please check your SSH key is added to GitHub: https://github.com/settings/keys"
      exit 1
    fi
  fi
fi
