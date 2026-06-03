## ADDED Requirements

### Requirement: 公开 API 仅包含通用下载核心
`m3u8downloader` 库 SHALL 仅通过 `Index.ets` 导出与下载和本地服务直接相关的类型，不导出应用层调度、持久化或 URL 解析逻辑。

#### Scenario: 消费方可导入下载 API
- **WHEN** 消费方执行 `import { M3U8Manager, M3U8LocalServer, M3U8DownloadState, M3U8ManagerConfig } from '@xxx/m3u8downloader'`
- **THEN** 所有符号正常解析，无编译错误

#### Scenario: 应用层符号不在公开导出中
- **WHEN** 消费方尝试导入 `DownloadTask`、`TaskQueue`、`TaskStore`、`parseLabel`、`extractParam`
- **THEN** 编译报错"模块未导出该符号"，消费方需自行实现这些逻辑

### Requirement: Release 混淆后公开 API 可正常调用
库 SHALL 在 release 混淆构建下保留所有公开 API 的符号名，使消费方在生产环境中可正常调用。

#### Scenario: M3U8Manager 方法名未被混淆
- **WHEN** 消费方集成 release 版 HAR 并调用 `M3U8Manager.instance.download(...)`
- **THEN** 运行时正确找到方法，无"method not found"错误

#### Scenario: M3U8LocalServer 方法名未被混淆
- **WHEN** 消费方调用 `M3U8LocalServer.instance.start(filesDir)` 和 `.stop()`
- **THEN** 运行时正确执行，无符号解析错误

### Requirement: 包元数据符合 OHPM 发布规范
`oh-package.json5` SHALL 包含符合 OHPM 中心仓要求的字段：有效的包名（含个人 scope）、语义化版本号、description、license、keywords。

#### Scenario: 版本号为 0.0.1
- **WHEN** 读取 `m3u8downloader/oh-package.json5`
- **THEN** `version` 字段值为 `"0.0.1"`

#### Scenario: 包名包含个人 scope
- **WHEN** 读取 `m3u8downloader/oh-package.json5`
- **THEN** `name` 字段格式为 `"@<scope>/m3u8downloader"`，其中 `<scope>` 为发布者个人 OHPM 账号名

### Requirement: README 与实际 API 一致
库 SHALL 提供准确的 README，内容与当前实现一致，包含 `M3U8LocalServer` 的使用说明。

#### Scenario: README 不含过时内容
- **WHEN** 读取 `README.md`
- **THEN** 文档中不含对 `@ohos/crypto-js` 的引用，不含对"并发分片下载"的描述（实际已改为顺序下载）

#### Scenario: README 包含 M3U8LocalServer 用法
- **WHEN** 读取 `README.md`
- **THEN** 文档包含 `M3U8LocalServer` 的启动/停止示例代码及 ijkplayer 配合使用的说明
