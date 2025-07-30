#!/bin/bash
# Skrypt do naprawy problemów z git (usuwa node_modules z historii)

echo "=== Naprawa Git - usuwanie node_modules ==="

# Usuń node_modules z cache git
echo "Usuwanie node_modules z cache git..."
git rm -r --cached node_modules 2>/dev/null || true
git rm -r --cached frontend/node_modules 2>/dev/null || true
git rm -r --cached backend/node_modules 2>/dev/null || true
git rm -r --cached frontend/build 2>/dev/null || true

# Upewnij się że .gitignore istnieje
if [ ! -f .gitignore ]; then
    echo "Tworzenie .gitignore..."
    echo "node_modules/" > .gitignore
    echo "build/" >> .gitignore
    echo "*.log" >> .gitignore
fi

# Dodaj zmiany
git add .gitignore
git add -A

# Pokaż status
echo ""
echo "=== Aktualny status git ==="
git status --short | wc -l
echo "plików do commitu"
echo ""
echo "Jeśli wszystko wygląda OK, wykonaj:"
echo "git commit -m 'Fix: Remove node_modules and add .gitignore'"
echo "git push"