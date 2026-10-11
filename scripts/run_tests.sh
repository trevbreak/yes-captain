#!/bin/bash
# Headless regression suite for Yes, Captain!
# Usage: scripts/run_tests.sh [quick]   (quick = one seed per mission)
# Needs `godot` (4.4+; developed on 4.7) on the PATH.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
MODE="${1:-full}"
FAILED=0
LOG="$(mktemp -d)"

godot_import() { "$GODOT" --headless --path . --import >/dev/null 2>&1; }

run() {
  local name="$1"; shift
  local out="$LOG/$(echo "$name" | tr ' /' '__').log"
  printf "%-46s " "$name"
  "$@" >"$out" 2>&1
  local code=$?
  if grep -q "SCRIPT ERROR\|Parse Error" "$out"; then
    echo "FAIL (script error)"; grep -m3 "SCRIPT ERROR\|Parse Error" "$out"; FAILED=1
  elif [ $code -ne 0 ]; then
    echo "FAIL (exit $code)"; tail -5 "$out"; FAILED=1
  else
    echo "PASS"
  fi
}

godot_import
SEEDS_N=3; [ "$MODE" = "quick" ] && SEEDS_N=1
SEEDS=$SEEDS_N run "robot crews beat all 10 missions"  "$GODOT" --headless --path . --script tests/t_missions.gd
run "UI smoke: every seat in a mission"     "$GODOT" --headless --path . scenes/main.tscn -- --solo --autotest=haven --warm=1 --wait=0.3 --tail=0.5
run "UI smoke: poke every control"          "$GODOT" --headless --path . scenes/main.tscn -- --solo --autotest=haven --exercise --warm=1 --wait=0.3
# layout QA needs a real window (headless has no viewport size); skip with NOWINDOW=1 on CI
if [ -z "$NOWINDOW" ]; then
  for RES in 1024x768 1280x720 1920x1080; do
    run "layout check: every screen @ $RES"  "$GODOT" --path . --resolution $RES scenes/main.tscn -- --layoutcheck
  done
fi

# networking: dedicated headless host + a separate client process
printf "%-46s " "network: host + remote client"
"$GODOT" --headless --path . --script tests/t_net_server.gd >"$LOG/net_server.log" 2>&1 &
SERVER=$!
sleep 2
"$GODOT" --headless --path . --script tests/t_net_client.gd >"$LOG/net_client.log" 2>&1
CODE=$?
wait $SERVER 2>/dev/null
if [ $CODE -eq 0 ] && grep -q "CLIENT PASS" "$LOG/net_client.log"; then echo "PASS"; else echo "FAIL"; tail -8 "$LOG/net_client.log"; FAILED=1; fi

echo
if [ $FAILED -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED (logs in $LOG)"; fi
exit $FAILED
