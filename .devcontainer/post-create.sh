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
echo ""
echo "📝 Git credentials are forwarded from your Windows host via ssh-agent."
echo "   If git push fails, ensure ssh-agent is running on Windows:"
echo "     Get-Service ssh-agent | Set-Service -StartupType Automatic"
echo "     Start-Service ssh-agent"
echo "     ssh-add ~/.ssh/id_ed25519"