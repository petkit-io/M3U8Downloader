# 性能对比数据优势 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 README.md 的「功能特性」与「安装」章节之间插入「## 对比优势」章节，包含功能横向对比表和下载速度加速比表。

**Architecture:** 纯文档修改，无代码变更。在 `m3u8downloader/README.md` 第 15 行（功能特性列表末尾）和第 17 行（`## 安装`）之间插入新 Markdown 章节。

**Tech Stack:** Markdown

---

### Task 1: 在 README.md 插入「对比优势」章节

**Files:**
- Modify: `m3u8downloader/README.md`（功能特性列表末尾与「## 安装」之间）

- [ ] **Step 1: 确认插入点**

打开 `m3u8downloader/README.md`，找到以下两行的位置：

```
- ✅ 零私有依赖，仅依赖 HarmonyOS 官方 Kit
```
（这是功能特性列表的最后一行）

紧接其后是：
```
## 安装
```

新章节将插入这两行之间。

- [ ] **Step 2: 插入「对比优势」章节**

在「功能特性」列表末尾与「## 安装」之间，插入以下内容：

```markdown

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

```

- [ ] **Step 3: 确认最终结果**

查看修改后的 README，确认：
1. 「对比优势」章节位于「功能特性」与「安装」之间
2. 两张表格渲染正常（列宽对齐、无多余空行）
3. 估算说明文字（⚠️ 开头）正常显示
4. 其他现有章节内容未受影响
