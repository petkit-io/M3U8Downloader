## Why

项目已完成 M3U8 视频的下载功能，但下载完成后用户只能看到本地文件路径，无法在 App 内直接播放。新增本地播放能力，让用户在下载完成后可以立即观看视频，完成下载→播放的完整闭环。

## What Changes

- 下载完成时，额外生成一份 HTTP-URL 版本的 m3u8 文件（`httpMovie.m3u8`），片段路径指向本地 HTTP 服务器
- 新增单例本地 HTTP 服务器（`M3U8LocalServer`），按需启动/停止，将 `/<md5>/<filename>` 请求映射到本地文件系统
- 新增播放页面 `PlayerPage`，管理 HTTP 服务器生命周期并使用 `Video` 组件播放 HLS 流
- `Index` 页下载完成后显示"播放"按钮，点击跳转至 `PlayerPage`

## Capabilities

### New Capabilities

- `local-http-server`: 轻量级 TCP 静态文件服务器，监听 127.0.0.1:8080，为本地 m3u8 和 TS 文件提供 HTTP 访问能力
- `m3u8-local-playback`: 播放已下载的 M3U8 资源，包括 HTTP 版 m3u8 生成与 PlayerPage 播放界面

### Modified Capabilities

（无现有 spec 需变更）

## Impact

- **m3u8downloader 库**：`M3U8Analyser`、`M3U8Tools`、`M3U8DownloadContainer` 各新增少量方法/调用；新增 `M3U8LocalServer.ets`
- **entry 模块**：新增 `pages/PlayerPage.ets`；`Index.ets` 新增播放按钮与路由；`main_pages.json` 注册新页面
- **依赖**：使用 HarmonyOS `@ohos.net.socket`（TCPSocketServer）和 `@kit.ArkUI`（Video 组件），均为系统 SDK，无新增三方依赖
- **权限**：需确认 `ohos.permission.INTERNET` 已在 module.json5 中声明（本地 loopback 通常不需额外权限，但需验证）
