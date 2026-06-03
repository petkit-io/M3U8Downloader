## Context

项目是 HarmonyOS ArkTS 应用，已有完整的 M3U8 下载链路。下载完成后本地存储结构为：

```
<filesDir>/m3u8files/<md5(url)>/
  oriMovie.m3u8     ← 原始远端 m3u8（备份）
  movie.m3u8        ← 本地版（TS 引用绝对文件路径）
  0.ts, 1.ts, ...   ← TS 片段
  <md5(keyUri)>     ← 加密 key 文件（如有）
```

现有 `movie.m3u8` 中 TS 引用使用绝对文件路径（如 `/data/.../0.ts`），HarmonyOS `Video` 组件无法直接用文件路径播放 HLS；`M3U8TsInfo.localUrlString` 已预生成 `http://127.0.0.1:8080/<md5>/<index>.ts` 格式的 URL，但一直未被使用。

## Goals / Non-Goals

**Goals:**
- 下载完成时生成 `httpMovie.m3u8`（TS 引用为 HTTP URL）
- 实现最小可用的本地 HTTP 文件服务器（`M3U8LocalServer`）
- 实现 `PlayerPage` 播放页面，使用系统 `Video` 组件
- `Index` 页在下载完成后提供播放入口

**Non-Goals:**
- 自定义播放器 UI（进度条、倍速、全屏按钮等）
- 播放历史记录
- 后台播放 / 锁屏控制
- 多任务同时播放

## Decisions

### 决策 1：HTTP 服务器使用 TCPSocketServer 自建

**选择**：使用 `@ohos.net.socket` 的 `TCPSocketServer` 实现最小 HTTP/1.1 服务器

**备选**：
- 使用 WebServer 三方库 → HarmonyOS 生态暂无成熟稳定的三方 HTTP 服务库
- file:// URI 直接播放 → HarmonyOS AVPlayer 对 file:// HLS 支持不稳定

**理由**：TCPSocketServer 是系统 SDK，无需额外依赖。只需实现 GET 请求解析 + 文件读取 + HTTP 响应，逻辑简单可控。

---

### 决策 2：HTTP 服务器为单例，按需启动/停止

**选择**：`M3U8LocalServer` 单例，`PlayerPage.aboutToAppear()` 启动，`PlayerPage.aboutToDisappear()` 停止

**理由**：避免长期占用端口和内存；单例确保不会重复绑定端口；播放页生命周期与服务器生命周期一致，逻辑清晰。

---

### 决策 3：httpMovie.m3u8 在下载完成时生成

**选择**：`M3U8DownloadContainer.saveM3U8File()` 完成 `movie.m3u8` 后，紧接着生成 `httpMovie.m3u8`

**备选**：点击播放时动态生成 → 需要在播放路径上引入异步等待，增加 PlayerPage 复杂度

**理由**：下载完成时所有 `localUrlString` 数据已在内存中，就地生成成本极低；播放时直接读取文件，PlayerPage 无需感知生成逻辑。

---

### 决策 4：HTTP 服务器路径映射规则

```
请求路径: /<md5>/<filename>
映射规则: <filesDir>/m3u8files/<md5>/<filename>
httpMovie.m3u8 路径: /<md5>/httpMovie.m3u8
```

服务器从 `filesDir` 根目录开始解析，只处理两级路径，拒绝路径遍历（`..`）。

---

### 决策 5：播放器使用 @ohos/ijkplayer（XComponent）

**选择**：`XComponent({ libraryname: 'ijkplayer_napi' })` + `IjkMediaPlayer`

**备选**：系统 `Video` 组件 → 真机验证发现 HarmonyOS AVPlayer 不支持本地 HTTP HLS（`http://127.0.0.1:8080/...`）和 `file://` HLS，始终返回加载失败错误。

**理由**：ijkplayer 基于 FFmpeg，对 HLS 协议支持完整，通过本地 HTTP 服务器可正常播放下载好的片段。`start-on-prepared: 1` 配合 HTTP 服务器自检（`onReady` 回调）确保时序正确。`libraryname` 必须为 `'ijkplayer_napi'`（对应 `libijkplayer_napi.so`），使用 `'ijkplayer'` 会加载错误的底层库导致画面无法渲染。

## Risks / Trade-offs

- **端口冲突** → 8080 端口被其他进程占用时服务启动失败。缓解：捕获 bind 错误，向用户展示提示信息。
- **大文件内存压力** → TCPSocketServer 回调中一次性读取 TS 文件（通常 2-10MB）并整块写入 socket。当前实现未做分块，直接全量读取。实测当前片段大小（2-5MB）可接受，TCPSocket 单次 `send` 对 HarmonyOS 平台无明确文档上限，实测可正常发送。若未来遇到超大片段，可改为分块循环读取。
- **加密 M3U8（EXT-X-KEY）** → key 文件同样需要通过 HTTP 服务提供；`keyLocalUri` 已包含正确的 HTTP URL，`httpMovie.m3u8` 生成时直接使用即可。
- **并发请求** → `Video` 组件可能对同一 m3u8 发出多个并发 TS 请求。TCPSocketServer 的 `on('connect')` 回调是异步的，天然支持并发，但需注意文件读取并发上限。

## Migration Plan

纯新增功能，无破坏性变更：
- 旧的 `movie.m3u8` 保持不变
- 新增 `httpMovie.m3u8` 文件与之并列，不影响现有下载逻辑
- `Index.ets` 仅新增按钮，不修改现有交互流程
- 无需数据迁移

## Open Questions（已解决）

- ~~HarmonyOS `TCPSocketServer` 的单次 `send` 数据量上限是否有限制？~~ → 实测全量发送 2-5MB TS 文件无问题，无需分块。
- ~~`ohos.permission.INTERNET` 是否需要为 loopback 地址声明？~~ → 经真机验证，ijkplayer 访问 `http://127.0.0.1:8080/...` 需要声明 `INTERNET` 权限，否则连接被拒。`module.json5` 中已添加该权限。
