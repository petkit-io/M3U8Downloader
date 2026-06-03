# @wangbinji/m3u8downloader

适用于 HarmonyOS Next（API 16+）的 M3U8 下载库，支持 HLS VOD 流的完整下载、暂停/恢复/删除及下载进度回调，并内置本地 HTTP 服务以解决 HarmonyOS 不支持 file:// HLS 播放的问题。

## 功能特性

- ✅ 解析 M3U8 文件，顺序下载 TS 分片
- ✅ 支持 AES-128 加密分片（自动下载 key 文件）
- ✅ 下载完成后合成本地可播放的 `.m3u8` 索引文件
- ✅ 支持暂停、恢复、删除任务
- ✅ 实时下载进度回调 `[0, 1]`
- ✅ 支持自定义请求头（token 等鉴权场景）
- ✅ 内置本地 HTTP 服务（`M3U8LocalServer`），支持配合 ijkplayer 播放本地 HLS
- ✅ 零私有依赖，仅依赖 HarmonyOS 官方 Kit

## 对比优势

### 功能对比

| 特性 | 朴素手写实现 | @wangbinji/m3u8downloader |
|------|------------|--------------------------|
| TS 分片下载 | ✅ 串行 | ✅ **并发窗口**（默认 3，最高 5） |
| AES-128 加密支持 | ❌ 需自行实现 | ✅ 自动下载 key，透明解密 |
| 断点续传 | ❌ 需自行管理状态 | ✅ 内置，恢复时跳过已完成分片 |
| 进度回调精度 | 分片粒度（阶梯跳跃） | **字节粒度**（平滑 0→1） |
| 本地 HLS 播放 | ❌ AVPlayer 不支持 file:// | ✅ 内置 HTTP 服务，兼容 ijkplayer |
| 三方私有依赖 | 视实现而定 | ✅ **零**，仅 HarmonyOS 官方 Kit |

### 下载速度

基准场景：60 个 TS 分片 × 每片 500 KB × 网络带宽 5 Mbps

| 模式 | 并发数 | 估算耗时 | 相对基准 |
|------|--------|---------|---------|
| 朴素串行实现 | 1 | ~48 s | 1× 基准 |
| 本库 concurrency=1 | 1 | ~48 s | 1× |
| 本库 concurrency=3（默认） | 3 | ~17 s | **≈ 2.8×** |
| 本库 concurrency=5 | 5 | ~11 s | **≈ 4.4×** |

> ⚠️ 以上数据为理论估算，实测因设备、网络环境和分片大小而异。并发加速比在带宽充足时更接近理论值；弱网场景下提升幅度会缩小。

断点续传场景：已下载 40/60 片时暂停后恢复，本库预扫描跳过已完成分片，**仅需补充剩余 33% 数据**；朴素实现通常需从头重新下载。

## 安装

```bash
ohpm install @wangbinji/m3u8downloader
```

## 快速开始

### 1. 初始化（应用启动时调用一次）

```typescript
import { M3U8Manager } from '@wangbinji/m3u8downloader'

// 在 UIAbility.onCreate 或首页 aboutToAppear 中初始化
// setup() 返回 Promise，本地 HTTP 服务启动失败时会 reject，建议加 try/catch
try {
  await M3U8Manager.instance.setup({
    context: this.context,
    saveFilePath: this.context.filesDir,
    // 可选：携带自定义请求头
    defaultHeaders: { 'Authorization': 'Bearer your_token' }
  })
} catch (e) {
  console.error('M3U8Manager 初始化失败:', e.message)
}
```

### 2. 开始下载

```typescript
import { M3U8Manager, M3U8DownloadState } from '@wangbinji/m3u8downloader'

const m3u8Url = 'https://example.com/video/index.m3u8'

M3U8Manager.instance.download(
  m3u8Url,
  // 进度回调：progress [0,1]，downloadedSegments 已完成分片数，totalSegments 总分片数
  (progress, downloadedSegments, totalSegments) => {
    console.log(`下载进度: ${(progress * 100).toFixed(1)}% (${downloadedSegments}/${totalSegments})`)
  },
  // 完成回调
  (state, localPath, error) => {
    if (state === M3U8DownloadState.Complete) {
      console.log('下载完成，本地路径:', localPath)
      // localPath 即本地 movie.m3u8 文件路径，可配合 M3U8LocalServer 播放
    } else if (state === M3U8DownloadState.Fail) {
      console.error('下载失败:', error?.message)
    } else if (state === M3U8DownloadState.Cancel) {
      console.log('下载已取消')
    }
  }
)
```

### 3. 暂停下载

```typescript
M3U8Manager.instance.pause(m3u8Url, (error) => {
  console.log('已暂停')
})
```

### 4. 恢复下载

```typescript
M3U8Manager.instance.resume(
  m3u8Url,
  (error) => { console.log('恢复指令已发送') },
  (progress, downloadedSegments, totalSegments) => { console.log(`进度: ${(progress * 100).toFixed(1)}%`) },
  (state, localPath) => { /* 完成回调 */ }
)
```

### 5. 删除任务

```typescript
M3U8Manager.instance.delete(m3u8Url, () => {
  console.log('任务已取消')
})
```

### 6. 清理本地文件

```typescript
M3U8Manager.instance.removeLocalFiles(m3u8Url)
```

## M3U8LocalServer（本地 HTTP 服务）

HarmonyOS 的 `AVPlayer` 和 `Video` 组件不支持通过 `file://` 协议播放本地 HLS（`.m3u8`）文件。`M3U8LocalServer` 在本地启动一个轻量 HTTP 服务（监听 `127.0.0.1:8080`），将下载完成的 TS 分片通过 HTTP 提供给 ijkplayer 播放。

### 启动和停止

```typescript
import { M3U8LocalServer } from '@wangbinji/m3u8downloader'

// 在播放页面 aboutToAppear 中启动
// onReady 回调携带 success 参数，false 表示端口绑定失败（如端口被占用）
M3U8LocalServer.instance.start(this.context.filesDir, 8080, (success) => {
  if (success) {
    console.log('本地 HTTP 服务已就绪')
  } else {
    console.error('本地 HTTP 服务启动失败，请检查端口是否被占用')
  }
})

// 在播放页面 aboutToDisappear 中停止
M3U8LocalServer.instance.stop()
```

### 配合 ijkplayer 播放本地 HLS

下载完成后，`localPath` 为本地 `movie.m3u8` 的绝对路径（如 `/data/storage/el2/base/haps/entry/files/m3u8files/<md5>/movie.m3u8`）。

将路径转为 HTTP URL 后传给 ijkplayer：

```typescript
import { IjkMediaPlayer } from '@ohos/ijkplayer'
import { M3U8LocalServer } from '@wangbinji/m3u8downloader'

// 将本地路径转换为 HTTP URL
// localPath 格式: .../m3u8files/<md5>/movie.m3u8
// 对应 HTTP URL: http://127.0.0.1:8080/<md5>/movie.m3u8
function toHttpUrl(localPath: string): string {
  const m3u8filesIdx = localPath.indexOf('/m3u8files/')
  const relativePath = localPath.substring(m3u8filesIdx + '/m3u8files/'.length)
  return `http://127.0.0.1:8080/${relativePath}`
}

// 在播放组件中
const httpUrl = toHttpUrl(this.localPath)  // http://127.0.0.1:8080/<md5>/movie.m3u8

const player = IjkMediaPlayer.getInstance()
player.setDataSource(httpUrl)
player.setDisplay(this.surfaceId)
player.prepareAsync()
player.setOnPreparedListener({
  onPrepared: (mp) => { mp.start() }
})
```

> **注意**：播放前确保 `M3U8LocalServer.instance.start()` 已调用完毕（等待 `onReady` 回调）。

## API 说明

### `M3U8Manager`

| 方法 | 说明 |
|------|------|
| `setup(config)` | 初始化，必须在其他方法前调用 |
| `download(url, onProgress, onComplete)` | 开始下载指定 M3U8 |
| `pause(url, callback)` | 暂停下载任务 |
| `resume(url, callback, onProgress, onComplete)` | 恢复已暂停任务 |
| `delete(url, callback)` | 取消并删除下载任务 |
| `removeLocalFiles(url)` | 删除指定 URL 对应的所有本地缓存文件 |

### `M3U8LocalServer`

| 方法 | 说明 |
|------|------|
| `start(filesDir, onReady?)` | 启动本地 HTTP 服务，`filesDir` 为 `context.filesDir` |
| `stop()` | 停止本地 HTTP 服务 |

### `M3U8ManagerConfig`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `context` | `Context` | ✅ | 应用上下文 |
| `saveFilePath` | `string` | ✅ | 本地存储根目录（推荐使用 `context.filesDir`） |
| `defaultHeaders` | `Record<string, string>` | ❌ | 所有请求携带的自定义请求头 |

### `M3U8DownloadState`

| 枚举值 | 说明 |
|--------|------|
| `Downloading` | 下载进行中 |
| `Complete` | 下载并合成成功 |
| `Fail` | 下载或合成失败 |
| `Cancel` | 任务已取消 |

## 注意事项

- 仅支持 HLS VOD（含 `#EXT-X-ENDLIST`），不支持直播流
- TS 分片为顺序下载，保证稳定性，但较大文件需等待一定时间
- HarmonyOS 不支持通过 `AVPlayer`/`Video` 组件直接播放本地 `.m3u8` 文件，需配合 `M3U8LocalServer` 和 `@ohos/ijkplayer` 使用

## License

MIT
