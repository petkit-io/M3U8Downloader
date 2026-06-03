## Context

m3u8downloader 是一个 HarmonyOS ArkTS HAR 库，负责下载 M3U8 视频（解析 → 下载 TS 分片 → 合成本地 m3u8 → 通过本地 HTTP server 提供播放）。当前代码功能完整但存在以下问题：隐式副作用、API 语义模糊、内部组件生命周期暴露给用户、日志无法控制。准备发布给第三方使用，需要在 API 稳定性和代码质量上对齐库的标准。

## Goals / Non-Goals

**Goals:**
- 公开 API 清晰、参数语义自解释
- 用户只需与 `M3U8Manager` 交互，无需了解内部 server、文件路径等细节
- 库内日志可由用户控制（注入 / 静默）
- 内部无重复代码、无隐藏副作用

**Non-Goals:**
- 不改变下载核心逻辑（仍为顺序下载）
- 不支持并发下载、master playlist、Range 断点续传（留给后续版本）
- 不改变文件存储结构（避免破坏已有缓存）

## Decisions

### D1：Logger 接口注入

**决策**：在 `M3U8ManagerConfig` 增加可选 `logger?: M3U8Logger` 字段。`M3U8Logger` 是一个接口：

```ts
export interface M3U8Logger {
  debug(tag: string, msg: string): void
  info(tag: string, msg: string): void
  warn(tag: string, msg: string): void
  error(tag: string, msg: string): void
}
```

库内部创建一个 `LogBus` 单例，`M3U8Manager.setup()` 时将 logger 注入进去。所有模块通过 `LogBus.instance` 调用，不再直接用 `console.*`。

**为什么不用全局静态 logger**：全局静态会在多实例场景下产生竞争，注入到 `LogBus` 单例更安全。

**为什么不把 logger 直接传给每个类**：参数传递链太深（Manager → Container → Downloader → FileManager），单例更简洁。

**替代方案**：事件驱动日志（emit log events）→ 过于复杂，不适合库。

---

### D2：Server 生命周期内化

**决策**：`M3U8Manager.setup()` 内部调用 `M3U8LocalServer.instance.start()`，`Index.ets` 不再导出 `M3U8LocalServer`。

**为什么**：用户不应该知道 server 的存在，这是实现细节。暴露 server 会导致用户困惑（什么时候启动？传什么路径？端口冲突怎么办？）。

**风险**：`setup()` 变成异步操作（server 启动需要时间）。
**缓解**：`setup()` 返回 `Promise<void>`，用户 `await setup()` 后再调用 `download()`。

---

### D3：Port 可配置

**决策**：`M3U8ManagerConfig` 新增 `port?: number`，默认值 `8080`。`M3U8Setting.localHost()` 和 `M3U8Setting.port()` 改为接收 port 参数而非硬编码。

---

### D4：uuidWithUrl 副作用拆分

**决策**：
- `M3U8Setting.uuidWithUrl(url)` → 纯函数，只返回 md5 字符串，不创建目录
- `M3U8Setting.ensureDir(path)` → 独立方法，负责创建目录（如不存在则创建）
- 所有需要创建目录的调用点显式调用 `ensureDir`

调用链梳理：目录创建只在两个时机需要：
1. `M3U8Manager.containerForUrl()` → 在获取/创建 container 时确保目录存在
2. `M3U8Analyser` 中使用 uuidWithUrl 构造路径时 → 不需要创建目录，只需路径字符串

---

### D5：Key 文件去重

**决策**：在 `buildFileDownloadInfos()` 中用一个 `Set<string>` 记录已加入的 keyUri，重复的跳过。

---

### D6：Cancel 状态处理

**决策**：移除 `M3U8DownloadState.Cancel`。当前 `delete()` 操作只是设置 `cancel = true` 停止循环，下载会自然停止，但外部没有 Cancel 状态回调。移除避免用户误解有"取消回调"。

---

### D7：DownloadProgressHandler 签名

**决策**：

```ts
// 旧
(progress: number, taskUrl: string, taskCompleteDownload: number) => void

// 新
(progress: number, downloadedSegments: number, totalSegments: number) => void
```

去掉 `taskUrl`（调用者自己知道 url），`taskCompleteDownload` 改名为 `downloadedSegments`，新增 `totalSegments`。

---

### D8：buildHeaders 去重

**决策**：提取到 `M3U8Setting` 的静态工具方法 `buildHeaders(defaultHeaders?: Record<string, string>): Record<string, string>`，Container 和 Downloader 都调用该方法。

---

### D9：tryGenerateDir 清理

**决策**：删除 `M3U8FileManager.tryGenerateDir()` 方法，调用方改为直接调用 `M3U8Setting.ensureDir()`（即 D4 中的独立目录创建方法）。

---

### D10：hasDiscontinuity 拼写修正

**决策**：`M3U8TsInfo.hasDiscontiunity` → `hasDiscontinuity`。这是 breaking change，在 changelog 中注明。

## Risks / Trade-offs

- `setup()` 改为返回 `Promise<void>` → 用户需要 await，是 breaking change，但对发布前的库来说可以接受
- `M3U8LocalServer` 不再导出 → 如果有用户（内测阶段）直接用了这个类，需要迁移
- `hasDiscontinuity` 拼写修正 → 凡是读过该字段的代码都需要更新（entry 示例 App 中未使用该字段，影响面小）
- `M3U8DownloadState.Cancel` 移除 → 若用户有 switch-case 判断该状态，编译时会报错（有利于发现问题）
