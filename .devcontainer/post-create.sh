#!/bin/bash
set -e

echo "🔧 Setting up git hooks and nbstripout..."

# Initialize git repo if not already
if [ ! -d .git ]; then
    git init
fi

# Install pre-commit hooks
pre-commit install

# Also install nbstripout as a git filter (belt + suspenders with pre-commit)
nbstripout --install --attributes .gitattributes

echo "✅ pre-commit hooks installed"
echo "✅ nbstripout git filter installed"
