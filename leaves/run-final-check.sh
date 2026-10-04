#!/bin/zsh
# Final verification: confirm the stress test left no tagged entities, re-check /eco, stop.
set -u
SRV=/Users/starm/Minecraft/Leaves26.1.2
cd "$SRV"
LOG="$SRV/logs/final-check.log"
FIFO=/tmp/eco_final_fifo
rm -f "$FIFO" "$LOG"
mkfifo "$FIFO"

java -Dleavesclip.enable.mixin=true -Dleavesclip.disable.auto-update=true \
     -jar leaves-26.1.2.jar --nogui < "$FIFO" > "$LOG" 2>&1 &
JPID=$!
exec 9>"$FIFO"

for i in $(seq 1 300); do
  if ! kill -0 $JPID 2>/dev/null; then echo "(server exited early)"; break; fi
  if grep -q 'Done (' "$LOG" 2>/dev/null; then break; fi
  sleep 1
done
sleep 2
echo "=== tagged leftovers ==="; echo 'execute if entity @e[tag=eco_stress]' >&9; sleep 2
echo "=== cows near test spot ==="; echo 'execute positioned 8 100 8 run execute if entity @e[type=minecraft:cow,distance=..48]' >&9; sleep 2
echo "=== /eco ==="; echo "eco" >&9; sleep 2
grep -a "测试成功\|测试失败\|Test passed\|Test failed\|Entity Collision Optimizer" "$LOG" | tail -5
echo "=== stop ==="
echo "stop" >&9
for i in $(seq 1 90); do kill -0 $JPID 2>/dev/null || break; sleep 1; done
kill -0 $JPID 2>/dev/null && kill $JPID
wait $JPID 2>/dev/null
exec 9>&-
echo "=== DONE ==="
