#!/bin/zsh
# M3 stress test: pile ~200 tagged cows to exercise pushing + collision queries, then clean up.
set -u
SRV=/Users/starm/Minecraft/Leaves26.1.2
cd "$SRV"

LOG="$SRV/logs/m3-stress.log"
FIFO=/tmp/eco_m3_fifo
rm -f "$FIFO" "$LOG"
mkfifo "$FIFO"

java -Dleavesclip.enable.mixin=true -Dleavesclip.disable.auto-update=true \
     -jar leaves-26.1.2.jar --nogui < "$FIFO" > "$LOG" 2>&1 &
JPID=$!
exec 9>"$FIFO"

boot=0
for i in $(seq 1 300); do
  if ! kill -0 $JPID 2>/dev/null; then echo "(server exited early)"; break; fi
  if grep -q 'Done (' "$LOG" 2>/dev/null; then boot=1; break; fi
  sleep 1
done
sleep 2
echo "=== BOOT_OK=$boot (waited ${i}s) ==="

echo "forceload add 0 0" >&9
sleep 1
for n in $(seq 1 200); do
  echo 'summon minecraft:cow 8 100 8 {Tags:["eco_stress"],PersistenceRequired:1b}' >&9
done
echo "=== stress spawned, ticking 15s ==="
sleep 15

echo "eco" >&9
sleep 2
echo "=== /eco response ==="
grep -a "Entity Collision Optimizer" "$LOG" | tail -2 || echo "(no response)"

echo "=== errors during stress ==="
grep -an "Exception\|ERROR" "$LOG" | grep -aviE "advancement|recipe|watchdog" | head -15 || echo "(none)"

echo "=== native init evidence ==="
grep -a "Extracted FFM native library\|FFM collision backend initialized" "$LOG" | head -3 || echo "(none)"

echo "=== cleanup ==="
echo 'kill @e[tag=eco_stress]' >&9
sleep 3
echo "forceload remove 0 0" >&9
sleep 1

echo "=== stopping ==="
echo "stop" >&9
for i in $(seq 1 90); do kill -0 $JPID 2>/dev/null || break; sleep 1; done
kill -0 $JPID 2>/dev/null && { echo "(force kill)"; kill $JPID; }
wait $JPID 2>/dev/null
exec 9>&-
echo "=== DONE boot_ok=$boot ==="
