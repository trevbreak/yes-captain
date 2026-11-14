#!/bin/bash
# Export the browser build into export/web. Needs `godot` (4.7) and its web export templates.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
mkdir -p export/web
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --export-release "Web" export/web/index.html 2>&1 | grep -E "ERROR|error:" | grep -v "resources still in use" 
cp deploy/voice.js export/web/voice.js
[ -f export/web/config.js ] || echo "// set by the container at start-up" > export/web/config.js
[ -f export/web/index.wasm ] && echo "web build ready: $(du -sh export/web | cut -f1)" || { echo "web export FAILED"; exit 1; }
