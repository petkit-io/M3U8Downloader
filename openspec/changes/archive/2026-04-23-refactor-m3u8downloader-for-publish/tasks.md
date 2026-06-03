## 1. Logger 基础设施

- [x] 1.1 新建 `m3u8downloader/src/main/ets/logger/M3U8Logger.ets`，定义 `M3U8Logger` 接口（debug/info/warn/error 四个方法，参数 tag+msg）
- [x] 1.2 新建 `m3u8downloader/src/main/ets/logger/LogBus.ets`，实现单例 `LogBus`，持有当前 logger，默认使用 console 实现
- [x] 1.3 在 `Index.ets` 中导出 `M3U8Logger` 接口

## 2. 配置模型更新

- [x] 2.1 在 `M3U8Config.ets` 的 `M3U8ManagerConfig` 中新增 `port?: number` 字段（默认 8080）
- [x] 2.2 在 `M3U8Config.ets` 的 `M3U8ManagerConfig` 中新增 `logger?: M3U8Logger` 字段

## 3. M3U8Setting 重构（副作用拆分 + port 参数化）

- [x] 3.1 `M3U8Setting.uuidWithUrl(url)` 改为纯函数：移除 path 参数，只计算并返回 md5，不创建目录
- [x] 3.2 新增 `M3U8Setting.ensureDir(dirPath: string): void`，负责目录不存在时创建
- [x] 3.3 `M3U8Setting.commonDirPrefix(path)` 内部改调 `ensureDir`（行为不变，去副作用隔离）
- [x] 3.4 `M3U8Setting.localHost(port: number)` 接收 port 参数，不再硬编码 8080
- [x] 3.5 `M3U8Setting.fullCommonDirPrefixWithUrl` 更新：调用新的纯函数 `uuidWithUrl`，并在需要时单独调用 `ensureDir`
- [x] 3.6 更新所有调用 `uuidWithUrl` 的地方（M3U8Analyser、M3U8Tools、M3U8DownloadContainer），确保不依赖其创建目录的副作用

## 4. buildHeaders 去重

- [x] 4.1 在 `M3U8Setting` 中新增静态方法 `buildHeaders(defaultHeaders?: Record<string, string>): Record<string, string>`
- [x] 4.2 删除 `M3U8DownloadContainer` 中的内联 buildHeaders 逻辑，改调 `M3U8Setting.buildHeaders`
- [x] 4.3 删除 `M3U8Downloader` 中的 `buildHeaders()` 私有方法，改调 `M3U8Setting.buildHeaders`

## 5. M3U8Manager：server 内化 + setup 异步化

- [x] 5.1 `M3U8Manager.setup()` 改为返回 `Promise<void>`
- [x] 5.2 `setup()` 内部调用 `LogBus.instance.setLogger(config.logger)` 注入 logger
- [x] 5.3 `setup()` 内部调用 `M3U8LocalServer.instance.start(config.saveFilePath, config.port ?? 8080)` 并 await server 就绪
- [x] 5.4 将 port 存储在 manager 内部，传递给需要端口的地方（M3U8Setting.localHost 调用处）
- [x] 5.5 `Index.ets` 移除 `M3U8LocalServer` 的导出

## 6. DownloadProgressHandler 签名更新

- [x] 6.1 将 `M3U8DownloadContainer.ets` 中 `DownloadProgressHandler` 类型改为 `(progress: number, downloadedSegments: number, totalSegments: number) => void`
- [x] 6.2 更新 `M3U8Downloader.progressHandler` 字段类型，调用处传入正确的三个参数（successCount / total）
- [x] 6.3 更新 `M3U8Manager` 和 `M3U8DownloadContainer` 中所有 progressHandler 的调用点
- [x] 6.4 更新 `Index.ets` 的 `DownloadProgressHandler` 重导出（类型变了）

## 7. Key 文件下载去重

- [x] 7.1 在 `M3U8DownloadContainer.buildFileDownloadInfos()` 中用 `Set<string>` 记录已添加的 keyUri，重复的跳过 push

## 8. 枚举与模型清理

- [x] 8.1 从 `M3U8DownloadState` 中移除 `Cancel` 枚举值
- [x] 8.2 将 `M3U8TsInfo.hasDiscontiunity` 重命名为 `hasDiscontinuity`（同步更新 Analyser 中所有读写该字段的地方）

## 9. M3U8FileManager 清理

- [x] 9.1 删除 `M3U8FileManager.tryGenerateDir()` 方法
- [x] 9.2 更新 `M3U8DownloadContainer` 中调用 `tryGenerateDir()` 的地方，改为直接调用 `M3U8Setting.ensureDir()`

## 10. 全库日志替换

- [x] 10.1 `M3U8Downloader.ets`：将所有 `console.info/error` 替换为 `LogBus.instance.info/error`
- [x] 10.2 `M3U8DownloadContainer.ets`：替换所有 `console.*`
- [x] 10.3 `M3U8Analyser.ets`：替换所有 `console.*`
- [x] 10.4 `M3U8FileManager.ets`：替换所有 `console.*`
- [x] 10.5 `M3U8Manager.ets`：替换所有 `console.*`
- [x] 10.6 `M3U8LocalServer.ets`：替换所有 `console.*`
- [x] 10.7 `M3U8Setting.ets`：替换（如有）

## 11. entry 示例 App 同步更新

- [x] 11.1 `EntryAbility.ets` 或 `Index.ets`：`setup()` 改为 `await`，移除手动 `M3U8LocalServer.instance.start()` 调用（如有）
- [x] 11.2 `TaskQueue.ets`：更新 `DownloadProgressHandler` 回调签名，适配新的三参数形式
- [x] 11.3 确认 entry 中未直接使用 `hasDiscontiunity`（如有，修正拼写）
- [x] 11.4 确认 entry 中未使用 `M3U8DownloadState.Cancel`（如有，移除）
