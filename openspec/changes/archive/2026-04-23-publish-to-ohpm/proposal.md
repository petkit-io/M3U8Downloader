## Why

`m3u8downloader` 已具备完整的 M3U8 下载和本地播放能力，但目前以本地文件依赖（`file:../m3u8downloader`）的方式集成，其他 HarmonyOS 开发者无法直接使用。将其发布到 OHPM 中心仓库，可以让社区通过 `ohpm install` 一行命令集成 HLS 离线下载能力。

## What Changes

- 将库的公开 API 收窄为下载核心：移除 `DownloadTask`、`TaskQueue`、`TaskStore`、`parseLabel`、`extractParam` 的导出，这些是 Demo 应用的业务逻辑，不属于通用库职责
- 将上述移出的文件从 `m3u8downloader` 迁回 `entry` 模块
- 版本号改为 `0.0.1`，包名 scope 改为发布者个人 OHPM 账号
- 补全 `obfuscation-rules.txt`，确保 `M3U8LocalServer` 等新增公开类在 release 构建中不被混淆
- 更新 `README.md`：删除过时的 `@ohos/crypto-js` 依赖描述，补充 `M3U8LocalServer` 用法和 ijkplayer 播放示例，更新顺序下载说明
- 在 `entry` 中补全 `oh-package.json5` 依赖指向（改为 ohpm 包名）

## Capabilities

### New Capabilities

- `ohpm-package-api`：明确 `m3u8downloader` 的公开 API 边界，仅保留通用下载与本地服务能力

### Modified Capabilities

（无规格层面的行为变更，只是 API 导出范围收窄和工程配置调整）

## Impact

- `m3u8downloader/Index.ets`：移除 4 个导出（`DownloadTask`、`TaskQueue`、`extractParam`、`parseLabel`）
- `m3u8downloader/oh-package.json5`：版本号、包名 scope
- `m3u8downloader/obfuscation-rules.txt`：补充 keep 规则
- `m3u8downloader/README.md`：内容更新
- `entry/src/main/ets/`：新增 `model/`、`queue/`、`store/`、`utils/` 目录，接收迁回的文件
- `entry/src/main/ets/pages/Index.ets`：import 路径从 `@petkit/m3u8downloader` 改为本地相对路径
