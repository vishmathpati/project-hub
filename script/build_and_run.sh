#!/usr/bin/env bash
set -euo pipefail

run_mode="${1:-run}"
case "$run_mode" in
  run|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

bash "$project_root/build-app.sh"
app_bundle="$project_root/ProjectHub.app"
pkill -x ProjectHub >/dev/null 2>&1 || true

case "$run_mode" in
  --debug) exec lldb -- "$app_bundle/Contents/MacOS/ProjectHub" ;;
  --logs|--telemetry)
    /usr/bin/open -n "$app_bundle"
    exec /usr/bin/log stream --info --style compact --predicate 'process == "ProjectHub"'
    ;;
  --verify)
    /usr/bin/open -n "$app_bundle"
    for attempt in {1..20}; do
      while IFS= read -r running_pid; do
        running_binary="$(ps -p "$running_pid" -o comm= || true)"
        if [[ "$running_binary" == "$app_bundle/Contents/MacOS/ProjectHub" ]]; then
          echo "Project Hub is running from $app_bundle (PID $running_pid)"
          exit 0
        fi
      done < <(pgrep -x ProjectHub || true)
      sleep 0.2
    done
    echo "Project Hub did not stay running." >&2
    exit 1
    ;;
  run) /usr/bin/open -n "$app_bundle" ;;
esac
