## ADDED Requirements

### Requirement: M3U8Manager 自动管理本地 server 生命周期
`M3U8Manager.setup()` SHALL 在内部启动本地 HTTP server，用户无需手动调用任何 server 相关 API。
`M3U8LocalServer` 类 SHALL NOT 通过 `Index.ets` 对外导出。

#### Scenario: 用户调用 setup 后 server 自动就绪
- **WHEN** 用户 `await M3U8Manager.instance.setup(config)` 完成
- **THEN** 本地 HTTP server 已在指定端口监听，可立即开始下载

#### Scenario: server 已在运行时重复调用 setup
- **WHEN** 用户多次调用 `setup()`
- **THEN** server 不重复启动，不抛出异常

### Requirement: setup 返回 Promise
`M3U8Manager.setup()` SHALL 返回 `Promise<void>`，在 server 启动完成（或失败）后 resolve。

#### Scenario: server 启动成功
- **WHEN** setup 被调用且端口可用
- **THEN** Promise resolve，用户可立即调用 download()

#### Scenario: server 启动失败（端口占用）
- **WHEN** setup 被调用但端口已被占用
- **THEN** Promise 仍 resolve（不 reject），库通过 logger.warn 记录错误，下载功能继续可用（分片下载不受影响，仅播放本地文件时可能失败）

### Requirement: port 可配置
`M3U8ManagerConfig` SHALL 包含可选 `port?: number` 字段，默认值为 `8080`。
库内所有需要本地 server 地址的地方 SHALL 使用该配置值，不得硬编码端口号。

#### Scenario: 用户指定自定义端口
- **WHEN** 用户在 config 中设置 `port: 9090`
- **THEN** server 在 9090 端口监听，生成的本地 m3u8 文件中 URL 使用 9090 端口

#### Scenario: 用户不指定端口
- **WHEN** 用户在 config 中未设置 port
- **THEN** server 在默认 8080 端口监听
