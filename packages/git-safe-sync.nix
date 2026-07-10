{
  writeShellApplication,
  git,
  coreutils,
}:

writeShellApplication {
  name = "git-safe-sync";
  runtimeInputs = [
    git
    coreutils
  ];
  text = ''
    set -euo pipefail

    if [ "$#" -lt 2 ]; then
      echo "Usage: git-safe-sync <repo_url> <target_dir> [clone flags...]" >&2
      exit 1
    fi

    REPO_URL="$1"
    TARGET_DIR="$2"
    shift 2

    if [ ! -d "$TARGET_DIR" ]; then
      # Pass any extra flags (like --depth 1) to git clone
      git clone "$@" "$REPO_URL" "$TARGET_DIR"
      cd "$TARGET_DIR"
      if ! git verify-commit HEAD; then
        echo "Initial clone failed signature verification. Deleting unsafe clone." >&2
        cd /
        rm -rf "$TARGET_DIR"
        exit 1
      fi
    else
      cd "$TARGET_DIR"
      git fetch origin
      BRANCH=$(git rev-parse --abbrev-ref HEAD)
      git merge --ff-only --verify-signatures origin/"$BRANCH"
    fi
  '';
}
