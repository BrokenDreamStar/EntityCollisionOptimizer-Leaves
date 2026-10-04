#!/bin/zsh
# Builds dist/EntityCollisionOptimizer-Leaves.jar
#   - mojmap classes compiled against the Leaves runtime (no Fabric remap)
#   - every native library found under native/out/<platform>/, compiling the host platform
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

# The plugin descriptor reports the upstream mod version.
UPSTREAM_VERSION="$(sed -nE 's/^mod_version=(.*)$/\1/p' gradle.properties | head -1)"
if [[ -z "$UPSTREAM_VERSION" ]]; then
  print -u2 "error: mod_version not found in gradle.properties"
  exit 1
fi

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
echo "> version:     $UPSTREAM_VERSION (gradle.properties mod_version)"
echo "> runtime jar: $MOJMAP"
echo "> libraries:   $LIBS"

CP="$MOJMAP:$LAUNCHER:$(find "$LIBS" -name '*.jar' | tr '\n' ':')"

echo "> compiling java (release 25)"
rm -rf build/plugin-classes && mkdir -p build/plugin-classes
javac --release 25 -encoding UTF-8 -nowarn -cp "$CP" -d build/plugin-classes \
  $(find src/main/java -name '*.java' ! -name 'EntityCollisionOptimizer.java') \
  $(find leaves/java -name '*.java')

NATIVE_SOURCES=(
  native/src/native_error.cpp
  native/src/state/context_api.cpp
  native/src/state/metadata_api.cpp
  native/src/state/persistent_index.cpp
  native/src/spatial/spatial_index.cpp
  native/src/spatial/section_index.cpp
  native/src/query/collision_rules.cpp
  native/src/query/query_api.cpp
  native/src/motion/push_run.cpp
  native/src/motion/movement_solver.cpp
  native/src/geometry/voxel_geometry.cpp
  native/src/blocks/block_scan.cpp
)

echo "> building native for the host ($(uname -s)/$(uname -m))"
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)
    mkdir -p native/out/macos-arm64
    clang++ -std=c++20 -O3 -DNDEBUG -fPIC -fno-rtti -fomit-frame-pointer -pthread \
      -DAR_DARWIN -DAR_AARCH64 -mcpu=apple-m1 \
      -fvisibility=hidden -fvisibility-inlines-hidden -ffp-contract=off \
      -Wno-deprecated-declarations \
      -Inative/src -Inative/include \
      -dynamiclib \
      -o native/out/macos-arm64/libEntityCollisionOptimizer.dylib \
      "${NATIVE_SOURCES[@]}" \
      -Wl,-undefined,error -Wl,-dead_strip
    ;;
  Linux/x86_64)
    mkdir -p native/out/linux-x64
    clang++ -std=c++20 -O3 -DNDEBUG -fPIC -fno-rtti -fomit-frame-pointer -pthread \
      -DAR_LINUX -DAR_X64 -m64 -march=x86-64-v2 -mtune=generic \
      -fvisibility=hidden -fvisibility-inlines-hidden -ffp-contract=off \
      -Wno-deprecated-declarations \
      -Inative/src -Inative/include \
      -shared \
      -o native/out/linux-x64/libEntityCollisionOptimizer.so \
      "${NATIVE_SOURCES[@]}" \
      -static-libstdc++ -static-libgcc -Wl,--no-undefined -Wl,--gc-sections \
      -Wl,--version-script,native/version-script
    ;;
  *)
    echo "  host platform is not compiled here; packaging the prebuilt libraries already under native/out/"
    ;;
esac

echo "> packaging"
STAGE=build/plugin-stage
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -r build/plugin-classes/* "$STAGE/"
cp src/main/resources/entity_collision_optimizer.mixins.json "$STAGE/"
cp leaves/resources/leaves_bootstrap.mixins.json "$STAGE/"
sed -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\1$UPSTREAM_VERSION\2/" \
  leaves/resources/leaves-plugin.json > "$STAGE/leaves-plugin.json"

packaged=0
for dir in native/out/*(/N); do
  platform="${dir:t}"
  libs=("$dir"/*.dylib(N) "$dir"/*.so(N) "$dir"/*.dll(N))
  (( ${#libs} )) || continue
  mkdir -p "$STAGE/org/edtp/entitycollisionoptimizer/natives/$platform"
  cp "${libs[@]}" "$STAGE/org/edtp/entitycollisionoptimizer/natives/$platform/"
  echo "  + natives/$platform/${libs:t}"
  packaged=1
done
if (( ! packaged )); then
  print -u2 "error: no native libraries under native/out/; build one platform or provide prebuilt dirs"
  exit 1
fi

mkdir -p dist
jar cf dist/EntityCollisionOptimizer-Leaves.jar -C "$STAGE" .
echo "> done: $(pwd)/dist/EntityCollisionOptimizer-Leaves.jar ($(du -h dist/EntityCollisionOptimizer-Leaves.jar | cut -f1))"
