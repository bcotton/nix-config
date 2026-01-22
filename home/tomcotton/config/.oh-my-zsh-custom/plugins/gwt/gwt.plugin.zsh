#!/bin/zsh

# Git Worktree Manager (gwt)
# Simplifies creating git worktrees with proper branch tracking

gwt2() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: gwt <path>"
        echo "Example: gwt ../feature-branch"
        return 1
    fi

    local worktree_path="$1"
    local branch_name="$(basename "$worktree_path")"
    
    # Check if local branch exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo "Local branch '$branch_name' exists, using it"
        git worktree add "$worktree_path" "$branch_name"
    # Check if remote branch exists
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
        echo "Remote branch 'origin/$branch_name' exists, tracking it"
        git worktree add "$worktree_path" -b "$branch_name" "origin/$branch_name"
    else
        echo "No existing branch found, creating new branch '$branch_name'"
        git worktree add "$worktree_path" -b "$branch_name"
    fi
}