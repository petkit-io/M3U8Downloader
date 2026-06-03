## Why

`M3U8Downloader` 当前采用严格串行方式下载 TS 分片——每个分片下载完成后才开始下一个。在网络 RTT 较高（如 CDN 场景）时，大量时间浪费在请求等待上，而非实际数据传输。对于 80 个分片、RTT 100ms 的典型短视频，并发下载可将总耗时从 ~40 秒缩短至 ~14 秒（3 并发），用户等待时间减少约 65%。

## What Changes

- `M3U8Downloader` 新增并发下载能力，支持同时下载 2~5 个 TS 分片（可配置，默认 3）
- `M3U8ManagerConfig` 新增可选字段 `concurrency?: number`，允许调用方自定义并发数
- 进度回调语义不变：`(progress, downloadedSegments, totalSegments)` 仍可正确反映并发完成的实际进度
- 暂停/恢复/取消语义不变：`pause`、`cancel` 标志在并发场景下依然有效
- AES key 文件保持串行下载（通常仅 1~2 个，无需并发）
- 公开 API 签名不变（`M3U8Manager.download/pause/resume/delete` 无变化）

## Capabilities

### New Capabilities

- `concurrent-download`：TS 分片并发下载能力——支持配置并发窗口大小，保持分片索引有序写入，正确处理并发场景下的进度统计和暂停/取消控制

### Modified Capabilities

（无 spec 级行为变更——现有能力的对外契约不受影响）

## Impact

- **修改文件**：`m3u8downloader/src/main/ets/downloader/M3U8Downloader.ets`（核心改动）
- **修改文件**：`m3u8downloader/src/main/ets/model/M3U8Config.ets`（新增 `concurrency` 字段）
- **修改文件**：`m3u8downloader/src/main/ets/manager/M3U8Manager.ets`（透传 concurrency 到 Downloader）
- **不影响**：`M3U8Analyser`、`M3U8FileManager`、`M3U8LocalServer`、`entry/` 示例 App
- **无新依赖**：仍仅使用 HarmonyOS Kit 官方 API
