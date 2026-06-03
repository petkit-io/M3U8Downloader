## ADDED Requirements

### Requirement: 任务列表持久化
系统 SHALL 在每次任务状态变更后将完整任务列表序列化为 JSON 并写入 `@ohos.data.preferences`，key 为 `"download_tasks"`。

#### Scenario: 状态变更后自动持久化
- **WHEN** 任意任务的状态、进度或 localPath 发生变更
- **THEN** 系统将当前完整任务列表写入 preferences

#### Scenario: 删除任务后持久化
- **WHEN** 用户删除一个任务
- **THEN** 系统从列表移除该任务并立即更新 preferences

### Requirement: App 启动时还原任务列表
系统 SHALL 在 App 启动时从 preferences 读取任务列表并还原，其中处于 Downloading 状态的任务转为 Interrupted，处于 Queued 状态的任务保持 Queued 并在启动后自动开始（受并发上限约束）。

#### Scenario: 还原已中断任务
- **WHEN** App 重启，preferences 中存在 Downloading 状态的任务
- **THEN** 这些任务还原为 Interrupted 状态，等待用户手动恢复

#### Scenario: 还原排队任务并自动开始
- **WHEN** App 重启，preferences 中存在 Queued 状态的任务
- **THEN** 这些任务保持 Queued，启动后按并发上限自动开始下载

#### Scenario: 首次启动无持久化数据
- **WHEN** App 首次启动，preferences 中无任务数据
- **THEN** 系统以空任务列表初始化，正常运行
