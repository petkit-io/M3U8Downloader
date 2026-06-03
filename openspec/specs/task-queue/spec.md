## ADDED Requirements

### Requirement: 并发下载上限
系统 SHALL 同时最多维持 3 个处于 Downloading 状态的任务。用户手动点击"开始"时，若槽位可用则立即开始，否则保持 Queued 等待用户再次尝试。

#### Scenario: 槽位可用时点开始
- **WHEN** 用户点击 Queued 任务的"开始"按钮且当前 Downloading 任务数 < 3
- **THEN** 任务立即进入 Downloading 状态开始下载

#### Scenario: 槽位已满时点开始
- **WHEN** 用户点击 Queued 任务的"开始"按钮且当前 Downloading 任务数 = 3
- **THEN** 任务保持 Queued 状态，不自动下载

#### Scenario: 添加任务后保持排队
- **WHEN** 用户批量添加任务
- **THEN** 所有新任务进入 Queued 状态，不自动开始下载，等待用户手动触发

### Requirement: 任务状态转换
系统 SHALL 支持以下状态转换：Queued → Downloading → Complete / Failed；Downloading ↔ Paused；任何状态 → Deleted；Interrupted → Downloading（用户手动恢复）；Failed → Downloading（重试）。

#### Scenario: 用户暂停后恢复
- **WHEN** 用户对 Paused 任务点击"恢复"且当前槽位可用
- **THEN** 任务变为 Downloading 并继续下载

#### Scenario: 失败后重试
- **WHEN** 用户对 Failed 任务点击"重试"
- **THEN** 任务重新进入下载流程（槽位可用则直接开始，否则 Queued）

#### Scenario: 删除任意状态任务
- **WHEN** 用户删除任意状态的任务
- **THEN** 若为 Downloading，先取消下载；清理本地文件；从列表移除；不自动拉取其他 Queued 任务
