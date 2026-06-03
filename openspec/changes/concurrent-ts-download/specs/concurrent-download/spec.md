## ADDED Requirements

### Requirement: 并发下载 TS 分片
系统 SHALL 支持同时下载多个 TS 分片，并发数由调用方通过配置项指定，默认值为 3，有效范围为 1～5。

#### Scenario: 默认并发数生效
- **WHEN** 调用方未指定 `concurrency` 配置项
- **THEN** 系统同时发起不超过 3 个 TS 分片的 HTTP 请求

#### Scenario: 自定义并发数生效
- **WHEN** 调用方在 `M3U8ManagerConfig` 中设置 `concurrency: 2`
- **THEN** 系统同时发起不超过 2 个 TS 分片的 HTTP 请求

#### Scenario: 并发数越界时回退到默认值
- **WHEN** 调用方设置 `concurrency` 为 0 或大于 5 的值
- **THEN** 系统忽略该值，使用默认并发数 3

### Requirement: 并发场景下进度准确上报
系统 SHALL 在多个分片同时下载时，仍向调用方上报准确的已完成分片数和总分片数，`progress` 值 SHALL 单调递增，不得出现回退。

#### Scenario: 两个分片同时完成时进度不重复
- **WHEN** 两个 TS 分片几乎同时完成下载
- **THEN** `onProgress` 回调被触发两次，`downloadedSegments` 分别为 N 和 N+1，`progress` 值严格递增

#### Scenario: 进度值范围合法
- **WHEN** 下载过程中任意时刻触发 `onProgress`
- **THEN** `progress` 值在 [0.0, 1.0] 区间内，且 `downloadedSegments ≤ totalSegments`

### Requirement: 并发场景下暂停与取消立即生效
系统 SHALL 保证在并发下载进行中调用 `pause()` 或 `delete()` 时，所有正在进行的分片请求在当前 HTTP 响应回调返回后不再触发新的请求。

#### Scenario: 并发下载中暂停
- **WHEN** 有 3 个分片正在并发下载时调用 `pause()`
- **THEN** 已发出的请求等待响应后停止，不再发起新的分片请求，`pauseCompletionHandler` 被调用

#### Scenario: 并发下载中取消
- **WHEN** 有 3 个分片正在并发下载时调用 `delete()`
- **THEN** 已发出的请求等待响应后停止，不再发起新的分片请求，`completionHandler` 被调用

### Requirement: AES key 文件下载不受并发影响
系统 SHALL 保证 AES key 文件仅下载一次（去重），且 key 文件的下载与 TS 分片的并发下载互不干扰。

#### Scenario: 相同 key URI 仅下载一次
- **WHEN** M3U8 中多个 TS 分片引用同一个 `EXT-X-KEY` URI
- **THEN** 该 key 文件只发起一次 HTTP 请求并保存到本地

#### Scenario: 下载完成后所有分片均已落盘
- **WHEN** `onComplete` 回调以 `Complete` 状态被触发
- **THEN** 所有 TS 分片和 key 文件均已写入本地文件系统，`movie.m3u8` 和 `httpMovie.m3u8` 已生成
