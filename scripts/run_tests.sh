#!/bin/bash
# Headless regression suite for Yes, Captain!
# Usage: scripts/run_tests.sh [quick]
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
run "sim: physics, damage, power"        "$GODOT" --headless --path . --script tests/t_sim.gd
run "human flows: repair, share, ritual" "$GODOT" --headless --path . --script tests/t_flow.gd
run "party modifiers"                    "$GODOT" --headless --path . --script tests/t_mods.gd
run "reconnect and late join"            "$GODOT" --headless --path . --script tests/t_reconnect.gd
ENFORCE=1 SEEDS=2 run "bot soak: every encounter x2 seeds"  "$GODOT" --headless --path . --script tests/t_soak.gd
ENFORCE=1 STRESS=1 SEEDS=2 KINDS=casual,mines,checkpoint,cake,ducks,bees,drones,pods,dock \
  run "bot soak: chaos director on overdrive" "$GODOT" --headless --path . --script tests/t_soak.gd
ENFORCE=1 TRACTOR=1 SEEDS=3 KINDS=bastion run "bot soak: bastion with tractor beam" "$GODOT" --headless --path . --script tests/t_soak.gd
if [ "$MODE" != "quick" ]; then
  ENFORCE=1 LENGTH=full SEEDS=3 run "full campaigns (AI captain + crew)" "$GODOT" --headless --path . --script tests/t_run.gd
  ENFORCE=1 LENGTH=short SEEDS=3 run "quick campaigns"                    "$GODOT" --headless --path . --script tests/t_run.gd
fi
run "UI smoke: every screen"             "$GODOT" --headless --path . scenes/main.tscn -- --solo --autotest=casual --wait=0.3 --tail=1
run "UI smoke: poke every control"       "$GODOT" --headless --path . scenes/main.tscn -- --solo --autotest=drones --exercise
# layout QA needs a real window (headless has no viewport size); skip with NOWINDOW=1 on CI
if [ -z "$NOWINDOW" ]; then
  for RES in 1280x720 1440x900 1920x1080; do
    run "layout check: every screen @ $RES"  "$GODOT" --path . --resolution $RES scenes/main.tscn -- --layoutcheck=drones
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
