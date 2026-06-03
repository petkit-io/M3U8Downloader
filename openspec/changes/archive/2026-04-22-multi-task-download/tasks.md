## 1. 数据模型

- [x] 1.1 新建 `entry/src/main/ets/model/DownloadTask.ets`，定义 `TaskState` 枚举（Queued / Downloading / Paused / Interrupted / Complete / Failed）和 `DownloadTask` class（url, label, state, progress, localPath, addedAt, errorMsg）

## 2. URL 解析工具

- [x] 2.1 新建 `entry/src/main/ets/utils/UrlParser.ets`，实现 `extractParam(url, key): string` 手动解析 query 参数
- [x] 2.2 实现 `parseLabel(url): string`，根据 `moduleType` / `startTime` / `endTime` 生成时间段标签，无法解析时回退为 URL 前 40 字符

## 3. 持久化层

- [x] 3.1 新建 `entry/src/main/ets/store/TaskStore.ets`，封装 `@ohos.data.preferences` 的初始化（`getPreferences`）
- [x] 3.2 实现 `saveTasks(tasks: DownloadTask[]): void`，JSON 序列化后写入 key `"download_tasks"` 并调用 `flush()`
- [x] 3.3 实现 `loadTasks(): DownloadTask[]`，读取并反序列化，将 Downloading 状态转为 Interrupted

## 4. 并发调度器

- [x] 4.1 新建 `entry/src/main/ets/queue/TaskQueue.ets`，定义单例 `TaskQueue`，持有对 `tasks[]` 和 `onTasksChanged` 回调的引用
- [x] 4.2 实现 `setup(context, onTasksChanged)` 方法，初始化 TaskStore 并从持久化还原任务列表，按并发上限自动开始 Queued 任务
- [x] 4.3 实现 `addTasks(urls: string[])` 方法：过滤重复 URL，创建 DownloadTask，槽位可用则直接 start，否则 Queued，持久化
- [x] 4.4 实现私有 `startTask(task)` 方法：调用 `M3U8Manager.instance.download()`，在 onProgress 更新 task.progress，在 onComplete 更新 state 并触发 `pullNextQueued()`
- [x] 4.5 实现私有 `pullNextQueued()` 方法：扫描 tasks 找第一个 Queued 任务调用 startTask
- [x] 4.6 实现 `pauseTask(url)` 方法：调用 `M3U8Manager.pause()`，状态改 Paused，触发 pullNextQueued，持久化
- [x] 4.7 实现 `resumeTask(url)` 方法：槽位可用则直接 startTask（Interrupted / Paused → Downloading），否则改 Queued，持久化
- [x] 4.8 实现 `deleteTask(url)` 方法：若 Downloading 先 delete/cancel，调用 `removeLocalFiles()`，从数组移除，触发 pullNextQueued，持久化
- [x] 4.9 实现 `retryTask(url)` 方法：重置 task.progress = 0 / errorMsg = ''，调用 resumeTask 逻辑，持久化

## 5. 主页 UI 重构

- [x] 5.1 重写 `entry/src/main/ets/pages/Index.ets`，删除单任务 `@State` 变量，改为 `@State tasks: DownloadTask[]`
- [x] 5.2 在 `aboutToAppear` 中调用 `TaskQueue.instance.setup(ctx, (tasks) => { this.tasks = [...tasks] })`，初始化 M3U8Manager
- [x] 5.3 实现顶部导航栏：标题"M3U8 下载管理"+ 右侧展开/收起批量输入区的 [+] 按钮
- [x] 5.4 实现批量输入区（可折叠）：TextArea（高度 120vp）+ "全部添加并开始下载"按钮，点击调用 `TaskQueue.instance.addTasks()`，清空输入框
- [x] 5.5 实现任务列表：用 `ForEach(tasks, ...)` 渲染每个任务卡片，key 为 task.url 的 md5 或直接 url
- [x] 5.6 实现任务卡片组件（内联 `@Builder`）：上行显示 label + 状态色点，下行按状态显示进度条或状态文字，底部操作按钮行
- [x] 5.7 实现各状态操作按钮的 onClick 回调：暂停 / 恢复 / 删除 / 重试 / 播放（播放沿用现有 router.pushUrl 跳转 PlayerPage）
- [x] 5.8 在 `aboutToDisappear` 中调用 `M3U8LocalServer.instance.stop()`（PlayerPage 已管理，Index 无需处理 server）

## 6. 验证

- [ ] 6.1 批量粘贴 3 个以上 URL，验证最多 3 个同时下载，其余排队
- [ ] 6.2 暂停一个下载中任务，验证队列自动拉取下一个 Queued 任务
- [ ] 6.3 下载完成后关闭重启 App，验证任务列表恢复，已中断任务可手动恢复
- [ ] 6.4 下载完成的任务点播放，验证 PlayerPage 正常播放
- [ ] 6.5 删除任意状态任务，验证本地文件清理，列表更新正确

<!-- 以上 6.x 为真机验证项，需构建后手动测试 -->
