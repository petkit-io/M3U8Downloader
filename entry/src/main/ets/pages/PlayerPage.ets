import router from '@ohos.router'
import { fileIo } from '@kit.CoreFileKit'
import http from '@ohos.net.http'
import { IjkMediaPlayer, OnPreparedListener, OnErrorListener } from '@ohos/ijkplayer'

const PLAYER_ID = 'xc_player'
const LOCAL_SERVER_PORT = 8080  // must match M3U8ManagerConfig.port

@Entry
@Component
struct PlayerPage {

  @State private status: string = '初始化...'
  @State private hasError: boolean = false
  @State private errorMessage: string = ''
  @State private httpUrl: string = ''
  @State private selfTestResult: string = ''

  private player: IjkMediaPlayer = new IjkMediaPlayer(PLAYER_ID)

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    const localPath = (params?.['localPath'] as string) ?? ''

    if (!localPath) {
      this.status = '错误：缺少 localPath'
      return
    }

    this.status = `检查文件...\n${localPath}`

    let movieExists = false
    try { movieExists = fileIo.accessSync(localPath) } catch (_e) {}
    if (!movieExists) {
      this.status = `文件不存在：\n${localPath}`
      return
    }

    const parts = localPath.split('/')
    const md5 = parts[parts.length - 2]
    const dir = parts.slice(0, parts.length - 1).join('/')
    const httpM3u8Path = `${dir}/httpMovie.m3u8`

    this.status = `文件存在，md5=${md5}\n生成播放列表...`

    let httpM3u8Exists = false
    try { httpM3u8Exists = fileIo.accessSync(httpM3u8Path) } catch (_e) {}

    if (!httpM3u8Exists) {
      try {
        const movieContent = this.readFileString(localPath)
        const httpContent = this.convertToHttpM3u8(movieContent, md5)
        this.writeFileString(httpM3u8Path, httpContent)
        this.status = `播放列表已生成\n启动HTTP服务器...`
      } catch (e) {
        this.status = `生成播放列表失败：${e}`
        return
      }
    } else {
      this.status = `播放列表已存在\n启动HTTP服务器...`
    }

    const url = `http://127.0.0.1:${LOCAL_SERVER_PORT}/${md5}/httpMovie.m3u8`
    this.status = `启动播放...\nURL=${url}\n自检中...`
    this.selfTest(url, md5)
  }

  // 用 HTTP client 自检服务器是否可用
  private selfTest(url: string, md5: string) {
    const client = http.createHttp()
    client.request(url, { method: http.RequestMethod.GET, connectTimeout: 5000, readTimeout: 5000 })
      .then((resp) => {
        const code = resp.responseCode
        const body = (resp.result as string) ?? ''
        this.selfTestResult = `自检 HTTP ${code}\n内容前100字符：\n${body.substring(0, 100)}`
        client.destroy()
        if (code === 200 && body.includes('#EXTM3U')) {
          // Server works, start player
          this.status = `服务器正常 ✓\n等待播放器...`
          this.httpUrl = url
        } else {
          this.status = `服务器响应异常 code=${code}`
        }
      })
      .catch((err: Error) => {
        this.selfTestResult = `自检失败：${err.message}`
        this.status = `HTTP服务器无响应\n${err.message}`
        client.destroy()
      })
  }

  aboutToDisappear(): void {
    try { this.player.stop(); this.player.release() } catch (_e) {}
  }

  private initPlayer(context: object): void {
    this.status = `播放器 onLoad 已触发\n初始化...`
    this.player.setContext(context, PLAYER_ID)
    this.player.native_setup()

    // 设置视频源（官方示例顺序：先 setDataSource）
    this.player.setDataSource(this.httpUrl)

    // 协议白名单
    this.player.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, 'protocol_whitelist',
      'async,cache,crypto,file,http,https,ijkhttphook,ijkinject,ijklivehook,ijklongurl,ijksegment,ijktcphook,pipe,rtp,tcp,tls,udp,ijkurlhook,data')
    // 起播优化
    this.player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, 'start-on-prepared', '1')
    this.player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, 'packet-buffering', '0')
    this.player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, 'framedrop', '5')
    this.player.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, 'timeout', '10000000')

    const preparedListener: OnPreparedListener = {
      onPrepared: () => {
        this.status = 'onPrepared ✓ 开始播放'
        this.player.start()
      }
    }
    const errorListener: OnErrorListener = {
      onError: (what: number, extra: number) => {
        this.status = `onError: (${what}/${extra})`
      }
    }

    this.player.setOnPreparedListener(preparedListener)
    this.player.setOnErrorListener(errorListener)
    this.player.setMessageListener()

    this.status = `prepareAsync 已调用\n${this.httpUrl}`
    this.player.prepareAsync()
  }

  // ---- helpers ----

  private readFileString(path: string): string {
    const stat = fileIo.statSync(path)
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
    const buf = new ArrayBuffer(stat.size)
    fileIo.readSync(file.fd, buf)
    fileIo.closeSync(file)
    const bytes = new Uint8Array(buf)
    let s = ''
    for (let i = 0; i < bytes.length; i++) { s += String.fromCharCode(bytes[i]) }
    return s
  }

  private writeFileString(path: string, content: string): void {
    const file = fileIo.openSync(path,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
    fileIo.writeSync(file.fd, content)
    fileIo.closeSync(file)
  }

  private convertToHttpM3u8(content: string, md5: string): string {
    const lines = content.split('\n')
    const out: string[] = []
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const trimmed = line.trim()
      if (trimmed.startsWith('#EXT-X-KEY:') && trimmed.indexOf('URI="') !== -1) {
        out.push(this.convertKeyLine(trimmed, md5))
      } else if (trimmed.length > 0 && !trimmed.startsWith('#') && trimmed.startsWith('/')) {
        const segs = trimmed.split('/')
        const filename = segs[segs.length - 1]
        out.push(`http://127.0.0.1:${LOCAL_SERVER_PORT}/${md5}/${filename}`)
      } else {
        out.push(line)
      }
    }
    return out.join('\n')
  }

  private convertKeyLine(line: string, md5: string): string {
    const mark = 'URI="'
    const uriIdx = line.indexOf(mark)
    if (uriIdx === -1) return line
    const pathStart = uriIdx + mark.length
    const pathEnd = line.indexOf('"', pathStart)
    if (pathEnd === -1) return line
    const uri = line.substring(pathStart, pathEnd)
    if (!uri.startsWith('/')) return line
    const segs = uri.split('/')
    const filename = segs[segs.length - 1]
    return line.substring(0, pathStart)
      + `http://127.0.0.1:${LOCAL_SERVER_PORT}/${md5}/${filename}`
      + line.substring(pathEnd)
  }

  // ---- UI ----

  build() {
    Column() {

      Row() {
        Button('← 返回')
          .fontSize(15).fontColor('#1677FF').backgroundColor(Color.Transparent)
          .onClick(() => { router.back() })
        Blank()
        Text('正在播放').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1D1D1F')
        Blank()
        Button('← 返回').fontSize(15).fontColor(Color.Transparent)
          .backgroundColor(Color.Transparent).enabled(false)
      }
      .width('100%').height(52).padding({ left: 8, right: 8 }).backgroundColor(Color.White)

      if (this.httpUrl && !this.hasError) {
        XComponent({
          id: PLAYER_ID,
          type: XComponentType.SURFACE,
          libraryname: 'ijkplayer_napi'
        })
          .onLoad((context: object) => { this.initPlayer(context) })
          .onDestroy(() => {})
          .width('100%').aspectRatio(16 / 9).backgroundColor(Color.Black)
      }

      // 状态文本（始终显示）
      Text(this.status)
        .fontSize(12).fontColor('#1D1D1F').backgroundColor('#F5F5F5')
        .borderRadius(6).padding(10).margin({ top: 8, left: 16, right: 16 })
        .width('100%').wordBreak(WordBreak.BREAK_ALL)

      // 自检结果（有内容时显示）
      if (this.selfTestResult) {
        Text(this.selfTestResult)
          .fontSize(12).fontColor('#0050B3').backgroundColor('#E6F4FF')
          .borderRadius(6).padding(10).margin({ top: 4, left: 16, right: 16 })
          .width('100%').wordBreak(WordBreak.BREAK_ALL)
      }

      Blank()
    }
    .width('100%').height('100%').backgroundColor('#F0F0F0')
  }
}
