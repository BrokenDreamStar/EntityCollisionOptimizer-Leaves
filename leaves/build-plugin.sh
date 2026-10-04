#!/bin/zsh
# Builds dist/EntityCollisionOptimizer-Leaves.jar
#   - mojmap classes compiled against the Leaves runtime (no Fabric remap)
#   - darwin-arm64 native library from native/ sources
#   - leaves-plugin.json descriptor + both mixin configs
#
# Classpath sources:
#   SRV=<server dir>   reuse an installed Leaves server (default $HOME/Minecraft/Leaves26.1.2)
#   LEAVES_JAR=<jar>   no server install: bootstrap from a leavesclip launcher jar; the
#                      launcher also supplies the compile-time mixin/MixinExtras classes
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRV="${SRV:-$HOME/Minecraft/Leaves26.1.2}"
LEAVES_JAR="${LEAVES_JAR:-}"
BOOT="$ROOT/build/bootstrap"

LAUNCHER="$LEAVES_JAR"
if [[ -z "$LAUNCHER" && -d "$SRV" ]]; then
  LAUNCHER=("$SRV"/leaves-*.jar(N))
  LAUNCHER="${LAUNCHER[1]:-}"
fi
if [[ -z "$LAUNCHER" ]]; then
  print -u2 "error: set SRV=<Leaves server dir> or LEAVES_JAR=<leavesclip launcher jar>"
  exit 1
fi

MOJMAP=""
LIBS=""
if [[ -d "$SRV/libraries" ]]; then
  MOJMAP=("$SRV"/versions/*/*.jar(N))
  MOJMAP="${MOJMAP[1]:-}"
  LIBS="$SRV/libraries"
fi
if [[ -z "$MOJMAP" || -z "$LIBS" ]]; then
  MOJMAP=("$BOOT/server"/versions/*/*.jar(N))
  MOJMAP="${MOJMAP[1]:-}"
  LIBS="$BOOT/server/libraries"
  if [[ -z "$MOJMAP" || ! -d "$LIBS" ]]; then
    echo "> bootstrapping the Leaves runtime (downloads vanilla, needs network)"
    mkdir -p "$BOOT/server"
    ( cd "$BOOT/server" && java -Dleavesclip.patchonly=true -jar "$LAUNCHER" --nogui )
    MOJMAP=("$BOOT/server"/versions/*/*.jar(N))
    MOJMAP="${MOJMAP[1]:-}"
    LIBS="$BOOT/server/libraries"
  fi
fi
echo "> runtime jar: $MOJMAP"
echo "> libraries:   $LIBS"

CP="$MOJMAP:$LAUNCHER:$(find "$LIBS" -name '*.jar' | tr '\n' ':')"

echo "> compiling java (release 25)"
rm -rf build/plugin-classes && mkdir -p build/plugin-classes
javac --release 25 -encoding UTF-8 -nowarn -cp "$CP" -d build/plugin-classes \
  $(find src/main/java -name '*.java' ! -name 'EntityCollisionOptimizer.java') \
  $(find leaves/java -name '*.java')

echo "> building native (darwin-arm64)"
mkdir -p native/out/macos-arm64
clang++ -std=c++20 -O3 -DNDEBUG -fPIC -fno-rtti -fomit-frame-pointer -pthread \
  -DAR_DARWIN -DAR_AARCH64 -mcpu=apple-m1 \
  -fvisibility=hidden -fvisibility-inlines-hidden -ffp-contract=off \
  -Wno-deprecated-declarations \
  -Inative/src -Inative/include \
  -dynamiclib \
  -o native/out/macos-arm64/libEntityCollisionOptimizer.dylib \
  native/src/native_error.cpp \
  native/src/state/context_api.cpp \
  native/src/state/metadata_api.cpp \
  native/src/state/persistent_index.cpp \
  native/src/spatial/spatial_index.cpp \
  native/src/spatial/section_index.cpp \
  native/src/query/collision_rules.cpp \
  native/src/query/query_api.cpp \
  native/src/motion/push_run.cpp \
  native/src/motion/movement_solver.cpp \
  native/src/geometry/voxel_geometry.cpp \
  native/src/blocks/block_scan.cpp \
  -Wl,-undefined,error -Wl,-dead_strip

echo "> packaging"
STAGE=build/plugin-stage
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -r build/plugin-classes/* "$STAGE/"
cp src/main/resources/entity_collision_optimizer.mixins.json "$STAGE/"
cp leaves/resources/leaves_bootstrap.mixins.json "$STAGE/"
cp leaves/resources/leaves-plugin.json "$STAGE/"
mkdir -p "$STAGE/org/edtp/entitycollisionoptimizer/natives/macos-arm64"
cp native/out/macos-arm64/libEntityCollisionOptimizer.dylib "$STAGE/org/edtp/entitycollisionoptimizer/natives/macos-arm64/"

mkdir -p dist
jar cf dist/EntityCollisionOptimizer-Leaves.jar -C "$STAGE" .
echo "> done: $(pwd)/dist/EntityCollisionOptimizer-Leaves.jar ($(du -h dist/EntityCollisionOptimizer-Leaves.jar | cut -f1))"
