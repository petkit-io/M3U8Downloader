## Why

m3u8downloader 准备作为公开 HAR 库发布，但当前 API 存在多处对外用户不友好的设计（隐式副作用、参数语义模糊、组件生命周期需手动管理），同时内部存在重复代码和 Bug，需要在发布前统一清理。

## What Changes

- **BREAKING** `DownloadProgressHandler` 签名由 `(progress, taskUrl, taskCompleteDownload)` 改为 `(progress, downloadedSegments, totalSegments)`，语义更清晰
- **BREAKING** `M3U8LocalServer` 不再对外暴露，生命周期由 `M3U8Manager` 内部管理
- **BREAKING** `hasDiscontiunity` 拼写修正为 `hasDiscontinuity`（影响 `M3U8TsInfo` 模型）
- `M3U8ManagerConfig` 新增可选 `port` 字段，默认 8080
- `M3U8ManagerConfig` 新增可选 `logger` 字段，支持用户注入自定义日志实现
- `M3U8DownloadState` 移除从未被触发的 `Cancel` 状态，或实现真正的取消逻辑
- `uuidWithUrl()` 拆分为纯函数（只计算 md5）+ 独立的目录创建逻辑
- Key 文件下载去重：同一 `keyUri` 在 `buildFileDownloadInfos()` 中只生成一条下载任务
- `M3U8FileManager.tryGenerateDir()` 空方法清理，目录管理逻辑归一
- `buildHeaders()` 去重，提取到公共位置
- 全库 `console.log/error/info` 替换为通过 `logger` 接口输出

## Capabilities

### New Capabilities

- `custom-logger`: 用户可通过 `M3U8ManagerConfig.logger` 注入日志实现，库内部统一使用该接口记录 debug/info/warn/error 级别日志
- `server-lifecycle`: `M3U8Manager` 自动管理本地 HTTP server 的启停，用户无需感知

### Modified Capabilities

（无现有 spec 文件，全部为新增）

## Impact

- **公开 API**：`Index.ets` 移除 `M3U8LocalServer` 导出；`DownloadProgressHandler` 签名变更；`M3U8ManagerConfig` 新增字段
- **内部模块**：`M3U8Setting`、`M3U8DownloadContainer`、`M3U8Downloader`、`M3U8Analyser`、`M3U8FileManager` 均有改动
- **entry 示例 App**：需同步更新调用方式（移除手动 server 启动、适配新 progress 回调签名）
- **无新依赖引入**
