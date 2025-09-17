#!/bin/bash
# fix_eol.sh - convert repository scripts to Unix (LF) line endings and make shell scripts executable
# Usage: ./scripts/fix_eol.sh [path...]
# If no path provided, it will process the repository's scripts/ directory.

set -e

TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=("scripts")
fi

echo "Converting files to Unix (LF) line endings and fixing permissions..."
for t in "${TARGETS[@]}"; do
  if [ -d "$t" ]; then
    find "$t" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.txt" -o -name "*.cfg" -o -name "*.yml" -o -name "*.yaml" \) | while read -r f; do
      # remove CR characters
      if grep -q $'\r' "$f"; then
        printf "Fixing EOL for: %s\n" "$f"
        sed -i 's/\r$//' "$f" || true
      fi
      # Make shell scripts executable
      case "$f" in
        *.sh)
          chmod +x "$f" || true
          ;;
      esac
    done
  elif [ -f "$t" ]; then
    if grep -q $'\r' "$t"; then
      printf "Fixing EOL for: %s\n" "$t"
      sed -i 's/\r$//' "$t" || true
    fi
    case "$t" in
      *.sh)
        chmod +x "$t" || true
        ;;
    esac
  else
    echo "Target not found: $t"
  fi
done

echo "Done."
