## 1. 收窄库的公开 API

- [x] 1.1 从 `m3u8downloader/Index.ets` 删除以下四行导出：`DownloadTask`、`TaskState`、`TaskQueue`、`extractParam`、`parseLabel`
- [x] 1.2 从 `m3u8downloader/src/main/ets/` 删除 `model/DownloadTask.ets`、`queue/TaskQueue.ets`、`store/TaskStore.ets`、`utils/UrlParser.ets` 及其目录

## 2. 将应用层代码迁回 entry

- [x] 2.1 在 `entry/src/main/ets/` 下重建 `model/`、`queue/`、`store/`、`utils/` 目录，写入对应文件（内容与删除前一致）
- [x] 2.2 修改 `entry/src/main/ets/queue/TaskQueue.ets` 的 import：将 `'../manager/M3U8Manager'` 和 `'../model/M3U8DownloadState'` 改回 `'@<scope>/m3u8downloader'` 包名导入
- [x] 2.3 修改 `entry/src/main/ets/pages/Index.ets` 的 import：将 `DownloadTask`、`TaskState`、`TaskQueue` 从 `'@<scope>/m3u8downloader'` 改为本地相对路径 `'../model/DownloadTask'` 和 `'../queue/TaskQueue'`

## 3. 补全混淆规则

- [x] 3.1 在 `m3u8downloader/obfuscation-rules.txt` 中补充 `M3U8LocalServer` 的 keep 规则：`-keep class M3U8LocalServer`，及 `instance`、`start`、`stop` 方法的 keep 规则
- [x] 3.2 核对 `Index.ets` 中每一个导出符号，确认均有对应的 `-keep` 规则（包括 `M3U8ManagerConfig`、回调类型等）

## 4. 更新包元数据

- [x] 4.1 修改 `m3u8downloader/oh-package.json5`：`version` 改为 `"0.0.1"`，`name` 改为 `"@<个人ohpm账号>/m3u8downloader"`（发布前填入实际账号名）

## 5. 更新 README

- [x] 5.1 删除 README 中所有对 `@ohos/crypto-js` 的引用
- [x] 5.2 将"并发下载所有 TS 分片"描述改为"顺序下载 TS 分片"
- [x] 5.3 在 README 中新增 `M3U8LocalServer` 章节，包含：`start(filesDir)` / `stop()` 调用示例，以及配合 ijkplayer 播放 `httpMovie.m3u8` 的完整代码片段
- [x] 5.4 更新 `注意事项` 中关于并发分片数量的描述，移除不再适用的建议

## 6. 验证

- [x] 6.1 执行 `hvigor build --mode=release` 验证库 release 构建通过，无混淆相关报错
- [x] 6.2 在 `entry` 中验证编译通过（`DownloadTask`、`TaskQueue` 等从本地路径正确导入）
- [x] 6.3 检查生成的 `.har` 文件，确认公开 API 符号未被混淆（可用 `jar -tf` 查看包内容）
