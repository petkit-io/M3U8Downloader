## ADDED Requirements

### Requirement: 从 URL 解析时间段标签
系统 SHALL 从 M3U8 URL 的 query 参数中提取 `startTime`、`endTime`、`moduleType` 生成人类可读标签，用于任务卡片展示。

#### Scenario: 云存储带时间范围
- **WHEN** URL 包含 `moduleType=CLOUD_STORAGE`、`startTime` 和 `endTime`
- **THEN** 标签格式为 `云存储  HH:mm ~ HH:mm (Xs)`，其中 X 为时长秒数

#### Scenario: 事件视频无结束时间
- **WHEN** URL 包含 `moduleType=EVENT_VIDEO` 且无 `endTime`
- **THEN** 标签格式为 `[事件]  HH:mm:ss`

#### Scenario: 无法解析时回退
- **WHEN** URL 缺少 `startTime` 或无法识别 `moduleType`
- **THEN** 标签回退为 URL 的前 40 个字符加省略号

### Requirement: URL 去重检测
系统 SHALL 在批量添加时对 URL 进行去重，判断依据为 URL 字符串完全相同。

#### Scenario: 已存在 URL 跳过
- **WHEN** 批量输入中包含已在任务列表中的 URL
- **THEN** 该 URL 被静默跳过，不创建新任务，不报错
