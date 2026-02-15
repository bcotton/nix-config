#!/usr/bin/env bash
set -e

url=$1
basename=${url##*/}
name=${2:-${basename%.*}}

# Get the default branch from remote
default_branch=$(git ls-remote --symref "$url" HEAD | awk '/^ref:/ {sub(/refs\/heads\//, "", $2); print $2}')

# Clone into name/default-branch/
git clone "$url" "$name/$default_branch"
git -C "$name/$default_branch" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

echo "Cloned into: $name/$default_branch"
