#!/bin/zsh
# R2 test: verify the native entity-query hook against the Moonrise traversal on live entities.
set -u
SRV=/Users/starm/Minecraft/Leaves26.1.2
cd "$SRV"

rm -f plugins/EntityCollisionOptimizer-Leaves.jar
rm -rf plugins/.mixins
cp -f /Users/starm/Development/Minecraft/eco-leaves-port/dist/EntityCollisionOptimizer-Leaves.jar plugins/

LOG="$SRV/logs/r2-test.log"
FIFO=/tmp/eco_r2_fifo
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
echo "=== BOOT_OK=$boot ==="

echo "forceload add 0 0 63 63" >&9
echo "forceload add 256 256 319 319" >&9
sleep 1
for i in $(seq 0 19); do
  echo "summon minecraft:armor_stand $((8 + i * 2)) 100 8 {Tags:[\"eco_verify\"]}" >&9
  echo "summon minecraft:armor_stand $((264 + i * 2)) 100 264 {Tags:[\"eco_verify\"]}" >&9
  echo "summon minecraft:cow $((8 + i * 2)) 100 264 {Tags:[\"eco_verify\"]}" >&9
done
echo "=== spawned 60 tagged entities, settling 8s ==="
sleep 8

echo "ecoverify" >&9
sleep 4
echo "eco" >&9
sleep 2

echo "=== ecoverify output ==="
grep -a "ecoverify\|Entity Collision Optimizer" "$LOG" | tail -8
echo "=== hook mixin applied? ==="
grep -a "MoonriseEntityQueryMixin" "$LOG" | head -2
echo "=== errors ==="
grep -an "Exception\|ERROR" "$LOG" | grep -aviE "advancement|recipe|watchdog" | head -10 || echo "(none)"

echo "=== cleanup ==="
echo 'kill @e[tag=eco_verify]' >&9
sleep 3
echo "forceload remove 0 0 63 63" >&9
echo "forceload remove 256 256 319 319" >&9
sleep 1
echo "stop" >&9
for i in $(seq 1 90); do kill -0 $JPID 2>/dev/null || break; sleep 1; done
kill -0 $JPID 2>/dev/null && { echo "(force kill)"; kill $JPID; }
wait $JPID 2>/dev/null
exec 9>&-
echo "=== DONE boot_ok=$boot ==="
