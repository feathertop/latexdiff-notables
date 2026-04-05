#!/bin/bash

# --- Configuration ---
REPO_NAME="latexdiff-notables"           # Change to your GitHub repo name
GITHUB_USERNAME="feathertop"  # Change to your GitHub username
BRANCH="main"
COMMIT_MSG="Initial commit"

# --- Script ---

# Initialize git repo if not already initialized
if [ ! -d ".git" ]; then
  echo "Initializing new Git repository..."
  git init
  git branch -M "$BRANCH"
else
  echo "Git repository already initialized."
fi

# Add all files
git add .

# Commit
echo "Committing with message: \"$COMMIT_MSG\""
git commit -m "$COMMIT_MSG"

# Check if remote 'origin' already exists
if git remote get-url origin &>/dev/null; then
  echo "Remote 'origin' already set."
else
  echo "Adding remote origin..."
  git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
fi

# Push to GitHub
echo "Pushing to GitHub..."
git push -u origin "$BRANCH"

echo "Done! Your code is live at https://github.com/$GITHUB_USERNAME/$REPO_NAME"
