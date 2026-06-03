# M3U8Downloader

适用于 HarmonyOS Next（API 16+）的 M3U8 下载库，支持 HLS VOD 流的完整下载、并发分片下载、暂停/恢复/删除及下载进度回调，并内置本地 HTTP 服务以解决 HarmonyOS 不支持 `file://` HLS 播放的问题。

## 功能特性

- ✅ 解析 M3U8 文件，并发下载 TS 分片（默认并发数 3，最高 5）
- ✅ 支持 AES-128 加密分片（自动下载 key 文件）
- ✅ 下载完成后合成本地可播放的 `.m3u8` 索引文件
- ✅ 支持暂停、恢复、删除任务（恢复时自动跳过已完成分片）
- ✅ 实时下载进度回调，精度 `[0, 1]`
- ✅ 支持自定义请求头（token 等鉴权场景）
- ✅ 内置本地 HTTP 服务（`M3U8LocalServer`），支持配合 ijkplayer 播放本地 HLS
- ✅ 支持自定义日志实现（注入 `M3U8Logger`）
- ✅ 零私有依赖，仅依赖 HarmonyOS 官方 Kit

## 安装

```bash
ohpm install @wangbinji/m3u8downloader
```

## 快速开始

### 1. 初始化（应用启动时调用一次）

```typescript
import { M3U8Manager } from '@wangbinji/m3u8downloader'

// 在 UIAbility.onCreate 或首页 aboutToAppear 中初始化
try {
  await M3U8Manager.instance.setup({
    context: this.context,
    saveFilePath: this.context.filesDir,
    port: 8080,          // 可选，本地 HTTP 服务端口，默认 8080
    concurrency: 3,      // 可选，TS 分片并发下载数（1-5），默认 3
    defaultHeaders: { 'Authorization': 'Bearer your_token' }  // 可选
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
  (progress, downloadedSegments, totalSegments) => {
    console.log(`下载进度: ${(progress * 100).toFixed(1)}% (${downloadedSegments}/${totalSegments})`)
  },
  (state, localPath, error) => {
    if (state === M3U8DownloadState.Complete) {
      console.log('下载完成，本地路径:', localPath)
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
  (progress, downloadedSegments, totalSegments) => {
    console.log(`进度: ${(progress * 100).toFixed(1)}%`)
  },
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

## 本地播放（M3U8LocalServer）

HarmonyOS 的 `AVPlayer` 和 `Video` 组件不支持通过 `file://` 协议播放本地 HLS 文件。`M3U8LocalServer` 在本地启动一个轻量 HTTP 服务，将下载完成的 TS 分片通过 HTTP 提供给播放器使用。

### 启动和停止

```typescript
import { M3U8LocalServer } from '@wangbinji/m3u8downloader'

// 在播放页面 aboutToAppear 中启动
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

### 配合 ijkplayer 播放

```typescript
import { IjkMediaPlayer } from '@ohos/ijkplayer'

// 将本地路径转换为 HTTP URL
// localPath: .../m3u8files/<md5>/movie.m3u8
// httpUrl:   http://127.0.0.1:8080/<md5>/movie.m3u8
function toHttpUrl(localPath: string): string {
  const idx = localPath.indexOf('/m3u8files/')
  return `http://127.0.0.1:8080/${localPath.substring(idx + '/m3u8files/'.length)}`
}

const player = IjkMediaPlayer.getInstance()
player.setDataSource(toHttpUrl(localPath))
player.setDisplay(this.surfaceId)
player.prepareAsync()
player.setOnPreparedListener({
  onPrepared: (mp) => { mp.start() }
})
```

> 播放前请确保 `M3U8LocalServer.instance.start()` 的 `onReady` 回调已触发。

## API

### `M3U8Manager`

| 方法 | 说明 |
|------|------|
| `setup(config)` | 初始化，必须在其他方法前调用 |
| `download(url, onProgress, onComplete)` | 开始下载指定 M3U8 |
| `pause(url, callback)` | 暂停下载任务 |
| `resume(url, callback, onProgress, onComplete)` | 恢复已暂停任务 |
| `delete(url, callback)` | 取消并删除下载任务 |
| `removeLocalFiles(url)` | 删除指定 URL 对应的所有本地缓存文件 |

### `M3U8ManagerConfig`

| 字段 | 类型 | 必填 | 说明 |
|------|------|:----:|------|
| `context` | `Context` | ✅ | 应用上下文 |
| `saveFilePath` | `string` | ✅ | 本地存储根目录（推荐 `context.filesDir`） |
| `port` | `number` | ❌ | 本地 HTTP 服务端口，默认 `8080` |
| `concurrency` | `number` | ❌ | TS 分片并发下载数，范围 1–5，默认 `3` |
| `defaultHeaders` | `Record<string, string>` | ❌ | 所有请求携带的自定义请求头 |
| `logger` | `M3U8Logger` | ❌ | 自定义日志实现 |

### `M3U8LocalServer`

| 方法 | 说明 |
|------|------|
| `start(filesDir, port?, onReady?)` | 启动本地 HTTP 服务 |
| `stop()` | 停止本地 HTTP 服务 |

### `M3U8DownloadState`

| 枚举值 | 说明 |
|--------|------|
| `Downloading` | 下载进行中 |
| `Complete` | 下载完成 |
| `Fail` | 下载失败 |
| `Cancel` | 任务已取消 |

## 注意事项

- 仅支持 HLS VOD（含 `#EXT-X-ENDLIST` 标记），不支持直播流
- HarmonyOS 不支持通过 `AVPlayer`/`Video` 组件直接播放本地 `.m3u8` 文件，需配合 `M3U8LocalServer` 和 `@ohos/ijkplayer` 使用
- `concurrency` 超出 1–5 范围时自动回退为默认值 3

## License

MIT
