#!/bin/bash
# Run this script from inside your Flutter project folder
# Usage: bash push_phase1.sh

echo "=== TripGenie Phase 1 - GitHub Push ==="

# Initialize git if not already done
if [ ! -d ".git" ]; then
  git init
  echo "Git initialized"
fi

# Set remote (replace if already exists)
git remote remove origin 2>/dev/null
git remote add origin git@github.com:hamdan-ishfaq/MAD_PROJECT.git

# Stage all files
git add .

# Commit
git commit -m "feat: Phase 1 - Project setup, auth screens, bottom nav, discovery hub

- Flutter project structure with feature-first architecture
- Splash screen with animated logo and loading dots
- Login screen with form validation and guest login
- Bottom navigation bar (Home, Map, Planner, Profile)
- Discovery Hub with trending cards and top visited list
- Profile screen with stats, interests, and favorites
- App theme with custom colors, typography (Google Fonts Inter)
- GoRouter navigation setup
- Placeholder screens for Map, Planner (Phase 2/3/5)
- Free APIs only - no paid services"

# Push to main branch
git branch -M main
git push -u origin main

echo ""
echo "=== Done! Phase 1 pushed to GitHub ==="