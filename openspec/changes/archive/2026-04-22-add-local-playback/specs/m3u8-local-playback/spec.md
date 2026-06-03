## ADDED Requirements

### Requirement: 下载完成时生成 HTTP 版 m3u8
下载完成后，系统 SHALL 在与 `movie.m3u8` 相同目录下生成 `httpMovie.m3u8`，其中 TS 片段和 key 文件均引用 `http://127.0.0.1:8080/<md5>/...` 格式的 URL。

#### Scenario: 无加密的 m3u8 下载完成
- **WHEN** 无加密 M3U8 下载完成
- **THEN** 在 `<filesDir>/m3u8files/<md5>/httpMovie.m3u8` 生成文件，每个 `#EXTINF` 后的片段 URL 格式为 `http://127.0.0.1:8080/<md5>/<index>.ts`

#### Scenario: 有 EXT-X-KEY 加密的 m3u8 下载完成
- **WHEN** 带 EXT-X-KEY 加密的 M3U8 下载完成
- **THEN** `httpMovie.m3u8` 中 `#EXT-X-KEY` 的 `URI` 字段值为 `http://127.0.0.1:8080/<md5>/<keyMd5>` 格式

---

### Requirement: 播放页面导航
系统 SHALL 在下载完成后于 `Index` 页显示"播放"按钮；点击后跳转至 `PlayerPage`，并传递本地 `movie.m3u8` 的绝对文件路径作为路由参数。

#### Scenario: 下载完成后显示播放按钮
- **WHEN** 下载任务状态变为 `Complete`
- **THEN** `Index` 页在"删除任务"按钮上方显示"播放"按钮

#### Scenario: 点击播放按钮跳转
- **WHEN** 用户点击"播放"按钮
- **THEN** 路由跳转至 `PlayerPage`，携带参数 `{ localPath: '<filesDir>/m3u8files/<md5>/movie.m3u8' }`

---

### Requirement: PlayerPage 播放视频
`PlayerPage` SHALL 使用 `@ohos/ijkplayer`（XComponent + IjkMediaPlayer）播放本地 M3U8，通过本地 HTTP 服务器将文件路径转换为可播放的 HTTP URL，并管理服务器生命周期。

#### Scenario: 进入播放页面
- **WHEN** 路由跳转至 `PlayerPage`，参数包含有效的 `localPath`（`movie.m3u8` 绝对路径）
- **THEN** `aboutToAppear` 按需生成 `httpMovie.m3u8`（若不存在），启动 `M3U8LocalServer`，挂载 XComponent 后 ijkplayer 以 `http://127.0.0.1:8080/<md5>/httpMovie.m3u8` 为源开始播放

#### Scenario: 按需生成 httpMovie.m3u8
- **WHEN** 进入播放页时 `httpMovie.m3u8` 文件不存在（如旧版下载数据）
- **THEN** `PlayerPage` 读取 `movie.m3u8`，将绝对路径转换为 HTTP URL，写入 `httpMovie.m3u8` 后继续播放流程

#### Scenario: 离开播放页面
- **WHEN** 用户点击返回或以任何方式离开 `PlayerPage`
- **THEN** `aboutToDisappear` 调用 `M3U8LocalServer.instance.stop()`，释放 8080 端口

#### Scenario: 视频加载失败
- **WHEN** `Video` 组件触发 `onError` 事件
- **THEN** 页面显示错误提示文本，不崩溃
