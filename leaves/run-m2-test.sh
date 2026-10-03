#!/bin/zsh
# M2 end-to-end test: boot Leaves 26.1.2 with the ECO plugin, query /eco, verify FFM init.
set -u
SRV=/Users/starm/Minecraft/Leaves26.1.2
cd "$SRV"

rm -f plugins/ECO-M1-Smoke.jar plugins/EntityCollisionOptimizer-Leaves.jar
rm -rf plugins/.mixins
cp -f /Users/starm/Development/Minecraft/eco-leaves-port/dist/EntityCollisionOptimizer-Leaves.jar plugins/

LOG="$SRV/logs/m2-test.log"
FIFO=/tmp/eco_m2_fifo
rm -f "$FIFO" "$LOG"
mkfifo "$FIFO"

java -Dleavesclip.enable.mixin=true -Dleavesclip.disable.auto-update=true \
     -Dmixin.debug=true -Dmixin.debug.verbose=true -Dmixin.debug.export=true \
     -jar leaves-26.1.2.jar --nogui < "$FIFO" > "$LOG" 2>&1 &
JPID=$!
exec 9>"$FIFO"

boot=0
for i in $(seq 1 300); do
  if ! kill -0 $JPID 2>/dev/null; then echo "(server exited early)"; break; fi
  if grep -q 'Done (' "$LOG" 2>/dev/null; then boot=1; break; fi
  sleep 1
done
sleep 3

echo "=== BOOT_OK=$boot (waited ${i}s) ==="
echo "=== /eco response ==="
echo "eco" >&9
sleep 3
grep -a "Entity Collision Optimizer" "$LOG" | head -3 || echo "(no /eco response)"
echo "=== FFM native evidence ==="
grep -a "Extracted FFM native library\|FFM collision backend initialized" "$LOG" | head -4 || echo "(none)"
echo "=== mixin application (count) ==="
grep -ac "Mixing " "$LOG"
grep -a "Mixing " "$LOG" | head -30
echo "=== mixin configs ==="
grep -a "Selecting config\|Preparing .*mixins.json" "$LOG" | head -10
echo "=== errors mentioning eco/collision ==="
grep -an "eco\|collision\|EntityCollisionOptimizer" "$LOG" | grep -aiE "error|exception|failed|invalid|unable" | head -15 || echo "(none)"
echo "=== plugin init ==="
grep -a "Initialized.*plugin\|EntityCollisionOptimizer (" "$LOG" | head -5
echo "=== .mixins dir ==="
ls -la "$SRV/plugins/.mixins" 2>/dev/null
echo "=== stopping ==="
echo "stop" >&9
for i in $(seq 1 90); do kill -0 $JPID 2>/dev/null || break; sleep 1; done
kill -0 $JPID 2>/dev/null && { echo "(force kill)"; kill $JPID; }
wait $JPID 2>/dev/null
exec 9>&-
echo "=== shutdown tail ==="
tail -5 "$LOG"
echo "=== DONE boot_ok=$boot ==="
