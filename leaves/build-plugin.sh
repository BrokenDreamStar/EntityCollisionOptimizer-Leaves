#!/bin/zsh
# Builds dist/EntityCollisionOptimizer-Leaves.jar
#   - mojmap classes compiled against the Leaves 26.1.2 runtime jar (no Fabric remap)
#   - darwin-arm64 native library from native/ sources
#   - leaves-plugin.json descriptor + both mixin configs
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRV=/Users/starm/Minecraft/Leaves26.1.2
SRVJAR="$SRV/versions/26.1.2/leaves-26.1.2.jar"
GRADLE_CACHES="$HOME/.gradle/caches/modules-2/files-2.1"
SPONGE_MIXIN="$GRADLE_CACHES/net.fabricmc/sponge-mixin/0.17.4+mixin.0.8.7/5f66cc9f59b8efaa942155a3d5a30599bf6640dd/sponge-mixin-0.17.4+mixin.0.8.7.jar"
MIXIN_EXTRAS="$GRADLE_CACHES/io.github.llamalad7/mixinextras-fabric/0.5.5/d1055b99c0ab08a8403fe2da3d79ca28e6340a76/mixinextras-fabric-0.5.5.jar"

CP="$SRVJAR:$SPONGE_MIXIN:$MIXIN_EXTRAS:$(find "$SRV/libraries" -name '*.jar' | tr '\n' ':')"

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
