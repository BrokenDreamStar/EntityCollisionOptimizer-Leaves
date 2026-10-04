[Entity Collision Optimizer](https://github.com/water2004/EntityCollisionOptimizer) 的 [Leaves](https://github.com/LeavesMC/Leaves) 插件移植

`src/` 是上游 Fabric mod 源码，`leaves/` 是插件移植层。

## 安装与运行

把 jar 放入服务端 `plugins/` 目录，并在启动参数中加入：

```text
-Dleavesclip.enable.mixin=true
--enable-native-access=ALL-UNNAMED
```

进服后用 `/eco` 自检 native 后端是否初始化成功；`-Deco.queryHook=false` 可关闭实体查询钩子。
