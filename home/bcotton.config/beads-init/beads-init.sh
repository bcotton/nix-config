#!/usr/bin/env bash
set -euo pipefail

name=${1:-$(basename $(dirname $(pwd)))}

if [ ! -d .beads ]; then
    bd init -p "$name" --branch beads-sync
    bd hooks install
    bd migrate sync beads-sync

    git add .beads/.gitignore .gitattributes
    git add .beads

    bd daemon start --auto-commit
    bd sync
    echo "Beads initialized for $name, commit and push to sync with git"
else

fi


