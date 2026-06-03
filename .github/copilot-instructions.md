# Copilot Instructions

## 语言要求

本项目的所有 Copilot 对话始终使用**简体中文**。

## 项目概述

HarmonyOS Next（API 16+）M3U8/HLS 下载库（`@wangbinji/m3u8downloader`），以 HAR（HarmonyOS Archive）格式发布至 OHPM，附带演示应用（`entry`）展示多任务管理和基于 ijkplayer 的本地播放功能。

## 架构

`build-profile.json5` 中定义了**两个模块**：

- **`m3u8downloader/`** — 可复用的 HAR 库。零第三方依赖，仅使用 HarmonyOS Kit 官方 API。公共 API 从 `m3u8downloader/Index.ets` 导出。
- **`entry/`** — 演示应用。通过 `file:../m3u8downloader` 和 `@ohos/ijkplayer` 依赖库。自行实现任务队列、持久化和 UI —— 这些**有意不包含**在库中。

### 库内部结构（`m3u8downloader/src/main/ets/`）

```
manager/    → M3U8Manager：单例入口，将任务委派给每个 URL 对应的 container
container/  → M3U8DownloadContainer：每个 URL 的状态机（获取 → 解析 → 下载 → 保存）
analyser/   → M3U8Analyser：静态 M3U8 解析器，重构 local/HTTP m3u8 变体
downloader/ → M3U8Downloader：顺序下载 TS 分片 + AES-128 密钥
server/     → M3U8LocalServer：内嵌 TCP HTTP 服务器（127.0.0.1:8080）
filemanager/→ M3U8FileManager：异步文件 I/O 封装
logger/     → LogBus：事件总线日志，支持可插拔后端（默认：console）
model/      → 数据类：M3U8Info、M3U8TsInfo、M3U8KeyInfo、M3U8DownloadState 等
tools/      → 工具类：URL 解析、MD5 哈希、路径构建
```

### 演示应用内部结构（`entry/src/main/ets/`）

```
pages/      → Index.ets（任务列表 UI）、PlayerPage.ets（ijkplayer 播放页）
queue/      → TaskQueue：单例，最大 3 个并发下载，6 状态状态机
store/      → TaskStore：基于 dataPreferences 的 JSON 持久化
model/      → DownloadTask 模型 + TaskState 枚举
utils/      → UrlParser：从 M3U8 URL 查询参数中提取标签
```

### 数据流

1. `M3U8Manager.setup()` 初始化上下文 + 启动本地 HTTP 服务器
2. `M3U8Manager.download(url)` 以 `MD5(url)` 为键创建 `M3U8DownloadContainer`
3. Container 获取 M3U8 清单 → `M3U8Analyser` 解析 → `M3U8Downloader` 顺序下载 TS 分片
4. 下载完成后，将 local + HTTP m3u8 变体写入 `<filesDir>/m3u8files/<md5>/`
5. 播放：`M3U8LocalServer` 在 `http://127.0.0.1:8080/<md5>/<filename>` 提供文件供 ijkplayer 播放

## 关键约定

- **开发语言：** ArkTS（`.ets` 文件）—— 类 TypeScript，配合 HarmonyOS 装饰器（`@Entry`、`@Component`、`@State`、`@StorageLink`）
- **单例模式：** `M3U8Manager`、`M3U8LocalServer`、`M3U8FileManager`、`LogBus`、`TaskQueue` 均使用 `static _instance` + `get instance()` getter
- **回调优于 Promise：** 所有异步操作使用类型化函数处理器（如 `DownloadProgressHandler`、`DownloadCompleteHandler`），而非 async/await
- **路径隔离：** 每个下载 URL 映射到 `<filesDir>/m3u8files/<MD5(url)>/` —— TS 分片命名为 `<index>.ts`，清单文件命名为 `movie.m3u8`（本地）/ `httpMovie.m3u8`（HTTP）/ `oriMovie.m3u8`（原始）
- **日志规范：** 使用 `LogBus.instance.{debug|info|warn|error}(TAG, msg)`，每个文件定义 `TAG` 常量
- **库边界：** 仅 `m3u8downloader/Index.ets` 中的类型为公共 API。应用层代码（TaskQueue、TaskStore、UrlParser）必须留在 `entry/` 中

## 构建系统

- **构建工具：** Hvigor（HarmonyOS 构建系统，类似 Gradle）
- **包管理器：** OHPM（根目录和各模块下的 `oh-package.json5`）
- **IDE：** DevEco Studio（构建、签名和部署通常通过 IDE 完成）
- **目标 SDK：** HarmonyOS 5.0.4（API 16），`runtimeOS: "HarmonyOS"`

## 代码检查

代码检查配置位于 `code-linter.json5`：
- 目标：所有 `*.ets` 文件
- 规则集：`@performance/recommended`、`@typescript-eslint/recommended`
- 强制安全规则：`no-unsafe-aes`、`no-unsafe-hash`、`no-unsafe-rsa-*` 等

## OpenSpec 工作流

本项目使用 [OpenSpec](https://github.com/openspec-dev/openspec-tool) 进行结构化变更管理。规格文档位于 `openspec/specs/`，每个能力一个目录。变更通过 OpenSpec 工件工作流进行提案、设计和实现，完成后归档到 `openspec/changes/archive/`。
