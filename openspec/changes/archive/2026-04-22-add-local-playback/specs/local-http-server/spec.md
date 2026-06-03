## ADDED Requirements

### Requirement: 本地 HTTP 服务器启动与停止
系统 SHALL 提供单例 `M3U8LocalServer`，支持在指定 `filesDir` 上启动监听 `127.0.0.1:8080` 的 HTTP 服务，并在不需要时停止释放端口。

#### Scenario: 首次启动服务器
- **WHEN** 调用 `M3U8LocalServer.instance.start(filesDir)`
- **THEN** 服务器绑定 `127.0.0.1:8080` 并开始接受连接，后续对该端口的 HTTP GET 请求可正常响应

#### Scenario: 服务器已启动时再次调用 start
- **WHEN** 服务器已在运行状态下再次调用 `start()`
- **THEN** 忽略重复启动，不抛出异常，不重复绑定端口

#### Scenario: 停止服务器
- **WHEN** 调用 `M3U8LocalServer.instance.stop()`
- **THEN** 服务器关闭监听，释放 8080 端口；后续 HTTP 请求将得不到响应

---

### Requirement: 静态文件服务
服务器 SHALL 将路径 `/<md5>/<filename>` 的 GET 请求映射到本地文件 `<filesDir>/m3u8files/<md5>/<filename>` 并返回文件内容。

#### Scenario: 请求存在的 TS 文件
- **WHEN** 客户端发送 `GET /<md5>/0.ts HTTP/1.1`
- **THEN** 服务器返回 `HTTP/1.1 200 OK`，`Content-Type: video/mp2t`，响应体为对应文件的完整内容

#### Scenario: 请求存在的 m3u8 文件
- **WHEN** 客户端发送 `GET /<md5>/httpMovie.m3u8 HTTP/1.1`
- **THEN** 服务器返回 `HTTP/1.1 200 OK`，`Content-Type: application/vnd.apple.mpegurl`，响应体为 m3u8 文本内容

#### Scenario: 请求存在的 key 文件
- **WHEN** 客户端发送 `GET /<md5>/<keyMd5> HTTP/1.1`（key 文件无扩展名）
- **THEN** 服务器返回 `HTTP/1.1 200 OK`，`Content-Type: application/octet-stream`，响应体为 key 文件内容

#### Scenario: 请求不存在的文件
- **WHEN** 客户端请求的文件路径在文件系统中不存在
- **THEN** 服务器返回 `HTTP/1.1 404 Not Found`

---

### Requirement: 路径安全校验
服务器 SHALL 拒绝包含路径遍历符（`..`）的请求，防止访问 `m3u8files` 目录之外的文件。

#### Scenario: 路径包含 `..`
- **WHEN** 客户端发送包含 `..` 的请求路径（如 `GET /../../etc/passwd`）
- **THEN** 服务器返回 `HTTP/1.1 400 Bad Request`，不访问任何文件
