[Entity Collision Optimizer](https://github.com/water2004/EntityCollisionOptimizer) 的 [Leaves](https://github.com/LeavesMC/Leaves) 插件移植

`src/` 是上游 Fabric mod 源码，`leaves/` 是插件移植层。

## 构建

需要 JDK 25、clang，以及一份 leavesclip 启动 jar 或已装好的 Leaves 服务端目录：

```sh
# 有服务端安装：直接复用（默认 $HOME/Minecraft/Leaves26.1.2，可用 SRV 覆盖）
SRV=/path/to/leaves-server zsh leaves/build-plugin.sh

# 没有：从 leavesclip 启动 jar 自举（首次构建联网下载 vanilla 与依赖库）
LEAVES_JAR=/path/to/leaves.jar zsh leaves/build-plugin.sh
```

产物：`dist/EntityCollisionOptimizer-Leaves.jar`；自举缓存放在 `build/bootstrap/`。

## 安装与运行

把 jar 放入服务端 `plugins/` 目录，并在启动参数中加入：

```text
-Dleavesclip.enable.mixin=true
--enable-native-access=ALL-UNNAMED
```

进服后用 `/eco` 自检 native 后端是否初始化成功；`-Deco.queryHook=false` 可关闭实体查询钩子。
