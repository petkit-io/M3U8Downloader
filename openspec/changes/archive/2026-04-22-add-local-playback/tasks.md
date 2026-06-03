## 1. 生成 HTTP 版 m3u8

- [x] 1.1 在 `M3U8Tools.ets` 中新增 `pkM3U8HttpContentFilePath(path, url)` 方法，返回 `<filesDir>/m3u8files/<md5>/httpMovie.m3u8` 路径
- [x] 1.2 在 `M3U8Analyser.ets` 中新增静态方法 `synthesisHttpM3U8(m3u8Info, oriUrl)` —— 用 `tsInfo.localUrlString` 替代文件路径生成 m3u8 字符串，key URI 使用 `key.keyLocalUri`
- [x] 1.3 在 `M3U8DownloadContainer.saveM3U8File()` 完成 `movie.m3u8` 写入后，追加调用 `synthesisHttpM3U8` 并将结果写入 `httpMovie.m3u8`

## 2. 本地 HTTP 服务器

- [x] 2.1 新建 `m3u8downloader/src/main/ets/server/M3U8LocalServer.ets`，实现单例类 `M3U8LocalServer`，包含 `start(filesDir: string)` 和 `stop()` 方法
- [x] 2.2 在 `start()` 中使用 `@ohos.net.socket` 的 `TCPSocketServer`，绑定 `127.0.0.1:8080`，监听连接
- [x] 2.3 在连接回调中解析 HTTP GET 请求行，提取路径（格式 `/<md5>/<filename>`）
- [x] 2.4 校验路径不含 `..`，若含则响应 `400 Bad Request`
- [x] 2.5 根据路径拼接本地文件绝对路径 `<filesDir>/m3u8files/<md5>/<filename>`，用 `fileIo` 读取文件内容
- [x] 2.6 根据文件扩展名设置 `Content-Type`（`.m3u8` → `application/vnd.apple.mpegurl`，`.ts` → `video/mp2t`，其他 → `application/octet-stream`），组装 HTTP 响应并通过 socket 发送
- [x] 2.7 文件不存在时响应 `404 Not Found`
- [x] 2.8 在 `stop()` 中关闭 TCPSocketServer，重置运行状态

## 3. 导出 M3U8LocalServer

- [x] 3.1 在 `m3u8downloader` 的入口导出文件（`Index.ets` 或 `oh-package.json5` 对应的 main 入口）中导出 `M3U8LocalServer`，供 `entry` 模块使用

## 4. 播放页面 PlayerPage

- [x] 4.1 新建 `entry/src/main/ets/pages/PlayerPage.ets`，定义 `@Entry @Component struct PlayerPage`
- [x] 4.2 使用 `router.getParams()` 获取路由传入的 `url` 参数
- [x] 4.3 实现 `aboutToAppear()`：调用 `M3U8LocalServer.instance.start(filesDir)` 启动 HTTP 服务器
- [x] 4.4 实现 `aboutToDisappear()`：调用 `M3U8LocalServer.instance.stop()` 停止 HTTP 服务器
- [x] 4.5 在 `build()` 中：顶部放置返回按钮（`router.back()`），中间放置 `Video({ src: url, controller: videoController })` 并设置 `.controls(true).autoPlay(true)`
- [x] 4.6 为 `Video` 组件绑定 `onError` 回调，将错误状态记录到 `@State hasError`，在界面上显示错误提示文本

## 5. 路由注册与 Index 改造

- [x] 5.1 在 `entry/src/main/resources/base/profile/main_pages.json` 的 `src` 数组中添加 `"pages/PlayerPage"`
- [x] 5.2 在 `Index.ets` 的 `TaskState.Complete` 分支中，新增"播放"按钮（绿色风格，位于"删除任务"按钮上方）
- [x] 5.3 播放按钮 `onClick`：计算 HTTP URL（`http://127.0.0.1:8080/<md5>/httpMovie.m3u8`，其中 md5 可通过 `M3U8Setting.uuidWithUrl` 获取），调用 `router.pushUrl({ url: 'pages/PlayerPage', params: { url: httpUrl } })`
