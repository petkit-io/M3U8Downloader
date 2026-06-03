## ADDED Requirements

### Requirement: 批量 URL 输入
系统 SHALL 提供多行文本输入区域，用户可粘贴多个 URL（每行一个），点击"全部添加"后批量创建下载任务，重复 URL 静默跳过。

#### Scenario: 批量添加新任务
- **WHEN** 用户在输入框粘贴多行 URL 并点击"全部添加"
- **THEN** 系统为每个有效、非重复的 URL 创建 Queued 状态任务并加入列表，输入框清空，任务不自动开始

#### Scenario: 重复 URL 跳过
- **WHEN** 用户添加的 URL 已存在于任务列表中
- **THEN** 系统静默跳过该 URL，不创建重复任务

### Requirement: 任务列表展示
系统 SHALL 以卡片列表形式展示所有下载任务，按添加时间降序排列（最新的在最上面），每张卡片显示：时间段标签、状态、进度条（下载中/暂停时）、操作按钮。

#### Scenario: 列表按添加时间排序
- **WHEN** 用户添加多个任务
- **THEN** 最新添加的任务显示在列表顶部

#### Scenario: 下载中任务显示进度
- **WHEN** 任务处于 Downloading 状态
- **THEN** 卡片显示进度条和百分比，并显示"暂停"和"删除"按钮

#### Scenario: 完成任务显示播放入口
- **WHEN** 任务处于 Complete 状态
- **THEN** 卡片显示"播放"和"删除"按钮，无进度条

#### Scenario: 中断任务显示恢复入口
- **WHEN** 任务处于 Interrupted 状态
- **THEN** 卡片显示"已中断"标签及"恢复"和"删除"按钮

#### Scenario: 排队任务显示等待状态
- **WHEN** 任务处于 Queued 状态
- **THEN** 卡片显示"排队中"标签及"开始"和"删除"按钮；点击"开始"调用 resumeTask（槽位可用则立即下载，否则继续 Queued）

#### Scenario: 失败任务显示重试入口
- **WHEN** 任务处于 Failed 状态
- **THEN** 卡片显示错误提示及"重试"和"删除"按钮
