## Context

`m3u8downloader` 是一个 HarmonyOS ArkTS HAR 模块，当前以本地路径依赖方式被 `entry` 模块引用（`file:../m3u8downloader`）。模块已具备：
- 完整 M3U8 下载引擎（顺序分片下载、AES-128 加密支持）
- 本地 HTTP 文件服务（`M3U8LocalServer`，解决 HarmonyOS 不支持 file:// HLS 播放的问题）
- 零外部依赖（MD5 为纯 ArkTS 实现，其余全为 HarmonyOS 官方 SDK）

当前问题：`Index.ets` 导出了 `DownloadTask`、`TaskQueue`、`TaskStore`、`parseLabel` 等 Demo 应用特有的业务逻辑，不适合作为通用库 API 对外发布。

## Goals / Non-Goals

**Goals:**
- 收窄公开 API 至通用下载核心（`M3U8Manager`、`M3U8LocalServer` 及相关类型）
- 将应用层代码（`DownloadTask`、`TaskQueue`、`TaskStore`、`UrlParser`）迁回 `entry`
- 配置正确的 obfuscation keep 规则，使 release 包可正常被消费方调用
- 更新 `oh-package.json5`（版本号 `0.0.1`、包名 scope 改为个人账号）
- 更新 README 至与实现一致

**Non-Goals:**
- 发布到 OHPM 服务器（本次只做本地工程准备，发布由开发者手动执行 `ohpm publish`）
- 修改下载引擎逻辑
- 添加单元测试

## Decisions

### 决策 1：公开 API 仅保留下载核心

**Index.ets 保留的导出：**
```
M3U8Manager              下载引擎单例
M3U8LocalServer          本地 HTTP 服务
M3U8ManagerConfig        初始化配置类型
M3U8DownloadState        下载状态枚举
DownloadProgressHandler  进度回调类型
DownloadCompleteHandler  完成回调类型
M3U8PauseCompletionHandler 暂停/删除回调类型
```

**移除的导出：**
```
DownloadTask    → 迁回 entry/src/main/ets/model/
TaskState       → 迁回 entry/src/main/ets/model/
TaskQueue       → 迁回 entry/src/main/ets/queue/
TaskStore       → 迁回 entry/src/main/ets/store/
parseLabel      → 迁回 entry/src/main/ets/utils/
extractParam    → 迁回 entry/src/main/ets/utils/
```

**理由**：`UrlParser` 的标签格式（`CLOUD_STORAGE`/`EVENT_VIDEO`）与 petkit 摄像头 API 强耦合；`TaskQueue`/`TaskStore` 是特定 UI 层的调度策略。放入公共库会使其他开发者困惑，且难以适配。

### 决策 2：obfuscation-rules.txt 补全策略

release 构建开启了混淆，消费方通过 `import { M3U8LocalServer } from '@xxx/m3u8downloader'` 调用时，类名和方法名必须被 keep。新增规则：

```
-keep class M3U8LocalServer
-keep function M3U8LocalServer.instance
-keep function M3U8LocalServer.start
-keep function M3U8LocalServer.stop
```

`consumer-rules.txt` 保持为空（消费方不需要额外的混淆规则）。

### 决策 3：迁回文件后 entry 的 import 路径调整

`TaskQueue` 内部之前引用了 `M3U8Manager`（相对路径 `'../manager/M3U8Manager'`），迁回 `entry` 后需改回从包名导入：

```typescript
// 迁回 entry 后，TaskQueue.ets 中
import { M3U8Manager, M3U8DownloadState } from '@xxx/m3u8downloader'
```

`Index.ets` 中的 `DownloadTask`、`TaskQueue` import 从 `@xxx/m3u8downloader` 改为本地相对路径。

### 决策 4：版本与包名

- `version`: `0.0.1`（标明实验阶段，后续稳定后升至 `1.x`）
- `name`: `@<个人ohpm账号>/m3u8downloader`（发布前由开发者填入实际账号名）

## Risks / Trade-offs

- **迁移破坏构建** → `TaskQueue` 的 import 路径需同步修改，漏改会导致编译错误。缓解：修改后立即验证 `entry` 编译通过。
- **obfuscation 规则遗漏** → 若有公开方法未加 `-keep`，release 包中该方法名被混淆，消费方运行时找不到。缓解：以 `Index.ets` 的导出列表为准，逐一核对 keep 规则。
- **README 与实际 API 不符** → 描述过时会增加使用者上手成本。缓解：本次任务强制要求 README 与最终 `Index.ets` 导出保持一致。

## Migration Plan

1. 从 `m3u8downloader/Index.ets` 移除 4 项导出
2. 将对应的 4 个文件/目录从 `m3u8downloader/src/main/ets/` 移回 `entry/src/main/ets/`
3. 修复 `TaskQueue.ets` 内的 import（改回包名引用）
4. 修复 `entry/Index.ets` 内的 import（改为本地相对路径）
5. 补全 `obfuscation-rules.txt`
6. 更新 `oh-package.json5`（版本号 + 包名 scope）
7. 更新 `README.md`
8. 本地 release 构建验证（`hvigor build --mode=release`）
9. 开发者手动执行 `ohpm publish` 完成发布
