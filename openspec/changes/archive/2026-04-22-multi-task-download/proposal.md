## Why

当前应用只支持单个 M3U8 任务的下载与管理，用户无法同时管理多个视频片段的下载。安防摄像头场景下用户通常需要批量下载多段录像，现有 UI 无法满足需求。

## What Changes

- 新增批量 URL 输入界面（多行 TextArea，每行一个 URL，一键全部添加）
- 将主页 UI 从单任务状态变量重构为任务列表（List + 任务卡片）
- 新增并发调度器，最多同时下载 3 个任务，超出的进入排队状态
- 新增任务持久化，App 重启后任务列表还原，下载中的任务标记为"已中断"
- 自动从 URL 参数（startTime / endTime / moduleType）解析时间段标签显示
- 每个任务独立支持：暂停、恢复、重试、删除（含本地文件清理）、播放

## Capabilities

### New Capabilities

- `task-list-ui`: 多任务列表界面，展示所有下载任务的状态、进度、操作按钮
- `task-queue`: 并发调度器，维护最多 3 个活跃下载，其余排队
- `task-persistence`: 任务列表持久化（@ohos.data.preferences），App 重启后还原
- `url-parser`: 从 M3U8 URL 参数解析时间段标签供 UI 展示

### Modified Capabilities

## Impact

- `entry/src/main/ets/pages/Index.ets`：完全重构
- 新增文件：`entry/src/main/ets/model/DownloadTask.ets`、`entry/src/main/ets/store/TaskStore.ets`、`entry/src/main/ets/queue/TaskQueue.ets`、`entry/src/main/ets/utils/UrlParser.ets`
- `m3u8downloader` 库无需修改
- 依赖 `@ohos.data.preferences`（HarmonyOS 内置，无需新增外部包）
