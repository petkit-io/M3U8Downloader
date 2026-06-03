## Context

当前 `M3U8Manager` 后端已通过 `HashMap<md5, M3U8DownloadContainer>` 天然支持并发多任务，`DownloadProgressHandler` 签名也已携带 `taskUrl`。缺失的只是 UI 层：`Index.ets` 使用单套 `@State` 变量管理一个任务，需要重构为任务列表模型。

## Goals / Non-Goals

**Goals:**
- 批量 URL 输入，解析后统一加入任务列表
- 最多 3 个任务并发下载，其余 Queued 排队
- 任务列表通过 `@ohos.data.preferences` 持久化，重启后恢复
- 从 URL 参数自动生成时间段标签（云存储/事件视频）
- 每个任务独立支持：暂停 / 恢复 / 重试 / 删除 / 播放

**Non-Goals:**
- 修改 `m3u8downloader` 库
- 断点续传（重启后中断任务需用户手动恢复，重新下载）
- 任务优先级调整

## Decisions

### 1. 状态持有者：TaskQueue 作为单例

TaskQueue 持有 `tasks: DownloadTask[]`，通过 `@StorageLink` / `AppStorage` 或直接在 `Index.ets` 的 `aboutToAppear` 中初始化并作为 `@State` 传递。

**选择**：`TaskQueue` 作为普通单例，`Index.ets` 持有 `@State tasks: DownloadTask[]`，TaskQueue 的回调直接更新该数组触发重渲染。

**理由**：ArkTS 的响应式系统在组件内最可靠，避免跨组件 AppStorage 的类型限制。

### 2. 并发调度：手动触发 + 并发上限保护

```
activeCount: 当前 Downloading 状态的任务数
MAX = 3

添加任务：
  所有任务进入 Queued，不自动开始

用户点击"开始"（resumeTask）：
  if activeCount < 3 → 直接 start，state = Downloading
  else              → 保持 Queued，不排队等待

任务结束（Complete / Failed / Paused / Deleted）：
  activeCount--
  不自动拉取 Queued 任务（用户需手动触发）
```

**决策变更**（实现阶段用户明确要求）：初始设计为"任务结束后自动拉取 Queued"，实际改为全手动触发。理由：用户希望完全掌控每个任务的启动时机，避免意外消耗流量。启动时也不自动开始 Queued 任务。

### 3. 持久化：preferences + JSON

```typescript
// 写：任何状态变更后
preferences.put('tasks', JSON.stringify(tasks))
preferences.flush()

// 读：App 启动时
const raw = preferences.getSync('tasks', '[]')
tasks = JSON.parse(raw)
// Downloading → Interrupted（重启时正在下载的任务）
// Queued → 保持，重启后自动开始
```

**选择 preferences 而非 SQLite**：任务数量小（<100），JSON 序列化足够，API 更简单。

### 4. URL 标签解析

手动解析 query string（ArkTS 无 `URL` 内置 API）：

```
extractParam(url, 'startTime') → Unix timestamp (秒)
extractParam(url, 'endTime')   → Unix timestamp (秒，可选）
extractParam(url, 'moduleType') → CLOUD_STORAGE | EVENT_VIDEO

输出：
  CLOUD_STORAGE + endTime → "云存储  HH:mm ~ HH:mm (Xs)"
  EVENT_VIDEO             → "[事件]  HH:mm:ss"
```

### 5. 重启后中断任务的恢复

用户点"恢复"时调用 `M3U8Manager.instance.download()` 重新下载（不调用 `resume()`，因为 container 已不在内存中）。下载器会检查已存在的 `.data` 文件，跳过已完成的 TS 片段。

### 6. 删除任务

调用 `M3U8Manager.instance.delete()` + `removeLocalFiles()`，完成后从 `tasks[]` 移除并持久化。若任务处于 Downloading 状态，先 delete（内部 cancel）再移除。

## Risks / Trade-offs

- **重启后 Queued 任务自动开始**：若用户关闭 App 时有多个 Queued 任务，重启后自动开始可能消耗流量。→ 可接受，符合用户预期（继续未完成的队列）。
- **`tasks[]` 数组引用更新问题**：ArkTS 对数组内对象属性变更可能不触发重渲染。→ 每次状态变更时用 `this.tasks = [...this.tasks]` 替换整个数组引用。
- **preferences 写入延迟**：`flush()` 是异步的，极端情况下崩溃可能丢失最后一次写入。→ 可接受，重启后最坏情况是任务状态回退一步。

## Open Questions

- 并发数 3 是否需要用户可配置？（当前硬编码）
- 批量添加时，重复 URL 是静默跳过还是提示用户？（当前：静默跳过）
