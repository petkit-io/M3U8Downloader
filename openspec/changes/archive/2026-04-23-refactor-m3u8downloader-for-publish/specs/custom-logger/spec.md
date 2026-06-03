## ADDED Requirements

### Requirement: 用户可注入自定义 Logger
库 SHALL 提供 `M3U8Logger` 接口，用户可在 `M3U8ManagerConfig.logger` 字段中传入自定义实现。
库内部所有日志输出 SHALL 通过该接口，不得直接调用 `console.*`。
若用户未提供 logger，库 SHALL 使用默认实现（基于 `console.*`）。

#### Scenario: 用户注入自定义 logger
- **WHEN** 用户在 `setup()` 中传入实现了 `M3U8Logger` 接口的对象
- **THEN** 库内部所有 debug/info/warn/error 日志均通过该对象输出

#### Scenario: 用户不传 logger
- **WHEN** 用户调用 `setup()` 时未提供 `logger` 字段
- **THEN** 库使用默认 console logger，行为与之前一致

#### Scenario: 用户传入空实现以静默日志
- **WHEN** 用户传入所有方法为空函数的 logger 实现
- **THEN** 库不产生任何日志输出

### Requirement: Logger 分级输出
`M3U8Logger` 接口 SHALL 包含四个级别：`debug`、`info`、`warn`、`error`，每个方法接收 `tag: string` 和 `msg: string` 两个参数。

#### Scenario: 各级别日志正确路由
- **WHEN** 库内部发生下载失败事件
- **THEN** 通过 `logger.error(tag, msg)` 输出，而非 `logger.info`

### Requirement: Logger 接口对外导出
`M3U8Logger` 接口 SHALL 通过 `Index.ets` 导出，用户可用其声明自定义实现的类型。

#### Scenario: 用户实现 M3U8Logger
- **WHEN** 用户 import `M3U8Logger` 并实现该接口
- **THEN** 编译器能正确检查类型合规性
