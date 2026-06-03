import router from '@ohos.router'
import { M3U8Manager } from '@wangbinji/m3u8downloader'
import { DownloadTask, TaskState } from '../model/DownloadTask'
import { TaskQueue } from '../queue/TaskQueue'

@Component
struct TaskCard {
  @ObjectLink task: DownloadTask

  private stateColor(state: TaskState): ResourceColor {
    switch (state) {
      case TaskState.Downloading: return '#1677FF'
      case TaskState.Paused:      return '#FA8C16'
      case TaskState.Complete:    return '#52C41A'
      case TaskState.Failed:      return '#FF4D4F'
      case TaskState.Interrupted: return '#FF7A45'
      case TaskState.Queued:      return '#8C8C8C'
      default:                    return '#8C8C8C'
    }
  }

  private stateText(state: TaskState): string {
    switch (state) {
      case TaskState.Downloading: return '下载中'
      case TaskState.Paused:      return '已暂停'
      case TaskState.Complete:    return '已完成'
      case TaskState.Failed:      return '下载失败'
      case TaskState.Interrupted: return '已中断'
      case TaskState.Queued:      return '排队中'
      default:                    return ''
    }
  }

  build() {
    Column({ space: 10 }) {

      // Top row: label + state dot
      Row({ space: 8 }) {
        Text(this.task.label)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1D1D1F')
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Circle()
          .width(8)
          .height(8)
          .fill(this.stateColor(this.task.state))
        Text(this.stateText(this.task.state))
          .fontSize(12)
          .fontColor(this.stateColor(this.task.state))
      }
      .width('100%')

      // Progress bar (Downloading / Paused / Complete)
      if (this.task.state === TaskState.Downloading ||
          this.task.state === TaskState.Paused ||
          this.task.state === TaskState.Complete) {
        Column({ space: 4 }) {
          Progress({ value: this.task.progress * 100, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(4)
            .color('#1677FF')
            .backgroundColor('#E8E8E8')
          Text(`${(this.task.progress * 100).toFixed(1)}%`)
            .fontSize(12)
            .fontColor('#8C8C8C')
            .alignSelf(ItemAlign.End)
        }
        .width('100%')
      }

      // Error message
      if (this.task.state === TaskState.Failed) {
        Text(this.task.errorMsg)
          .fontSize(12)
          .fontColor('#FF4D4F')
          .backgroundColor('#FFF2F0')
          .borderRadius(4)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .width('100%')
      }

      // Action buttons
      Row({ space: 8 }) {

        if (this.task.state === TaskState.Queued) {
          Button('开始')
            .fontSize(13)
            .height(32)
            .layoutWeight(1)
            .backgroundColor('#1677FF')
            .borderRadius(6)
            .onClick(() => { TaskQueue.instance.resumeTask(this.task.url) })
        }

        if (this.task.state === TaskState.Downloading) {
          Button('暂停')
            .fontSize(13)
            .height(32)
            .layoutWeight(1)
            .backgroundColor('#FA8C16')
            .borderRadius(6)
            .onClick(() => { TaskQueue.instance.pauseTask(this.task.url) })
        }

        if (this.task.state === TaskState.Paused || this.task.state === TaskState.Interrupted) {
          Button('恢复')
            .fontSize(13)
            .height(32)
            .layoutWeight(1)
            .backgroundColor('#1677FF')
            .borderRadius(6)
            .onClick(() => { TaskQueue.instance.resumeTask(this.task.url) })
        }

        if (this.task.state === TaskState.Failed) {
          Button('重试')
            .fontSize(13)
            .height(32)
            .layoutWeight(1)
            .backgroundColor('#1677FF')
            .borderRadius(6)
            .onClick(() => { TaskQueue.instance.retryTask(this.task.url) })
        }

        if (this.task.state === TaskState.Complete) {
          Button('播放')
            .fontSize(13)
            .height(32)
            .layoutWeight(1)
            .backgroundColor('#52C41A')
            .borderRadius(6)
            .onClick(() => {
              router.pushUrl({ url: 'pages/PlayerPage', params: { localPath: this.task.localPath } })
            })
        }

        Button('删除')
          .fontSize(13)
          .height(32)
          .layoutWeight(1)
          .fontColor('#FF4D4F')
          .backgroundColor(Color.White)
          .border({ width: 1, color: '#FF4D4F' })
          .borderRadius(6)
          .onClick(() => { TaskQueue.instance.deleteTask(this.task.url) })
      }
      .width('100%')

    }
    .padding(14)
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(10)
    .shadow({ radius: 4, color: '#0000001A', offsetX: 0, offsetY: 2 })
  }
}

@Entry
@Component
struct Index {

  @State tasks: DownloadTask[] = []
  @State inputText: string = 'https://api.petkit.com/6/d4h/getDownloadM3u8?deviceId=548814&userId=819545&moduleType=CLOUD_STORAGE&mark=1777447355&startTime=1777447355&endTime=1777447652\n' +
    'https://api.petkit.com/6/d4h/getDownloadM3u8?deviceId=548814&userId=819545&moduleType=CLOUD_STORAGE&mark=1777407900&startTime=1777407900&endTime=1777408135\n'
    // 'https://api.petkit.com/6/d4h/getDownloadM3u8?deviceId=548814&userId=819545&moduleType=CLOUD_STORAGE&mark=1776830782&startTime=1776830782&endTime=1776830840\n' +
    // 'https://api.petkit.com/6/d4h/getDownloadM3u8?deviceId=548814&userId=819545&moduleType=CLOUD_STORAGE&mark=1776845103&startTime=1776845103&endTime=1776845286\n' +
    // 'https://api.petkit.com/6/d4h/getDownloadM3u8?deviceId=548814&userId=819545&moduleType=CLOUD_STORAGE&mark=1776802360&startTime=1776802360&endTime=1776802599\n'
  @State showInput: boolean = false

  async aboutToAppear(): Promise<void> {
    const ctx = this.getUIContext().getHostContext()!
    await M3U8Manager.instance.setup({
      context: ctx,
      saveFilePath: ctx.filesDir,
      defaultHeaders: {
        'X-Session': '25a697ba7ff64ace838ab83862f1b2d5v1aAC2dRdpq6iKeC6pim'
      }
    })
    TaskQueue.instance.setup(ctx, (updated: DownloadTask[]) => {
      this.tasks = updated
    }).catch((err: Error) => {
      console.error('TaskQueue setup error:', err?.message)
    })
  }

  aboutToDisappear(): void {
    // Server lifecycle is managed by PlayerPage
  }

  private addTasks(): void {
    const rawLines = this.inputText.split('\n')
    const lines: string[] = []
    for (let i = 0; i < rawLines.length; i++) {
      const line = rawLines[i].trim()
      if (line.length > 0) {
        lines.push(line)
      }
    }
    TaskQueue.instance.addTasks(lines)
    this.inputText = ''
    this.showInput = false
  }

  build() {
    Column() {

      // Navigation bar
      Row() {
        Text('M3U8 下载管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D1D1F')
          .layoutWeight(1)
        Button(this.showInput ? '收起' : '+')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .width(40)
          .height(40)
          .backgroundColor(this.showInput ? '#F5F5F5' : '#1677FF')
          .fontColor(this.showInput ? '#1D1D1F' : Color.White)
          .borderRadius(20)
          .onClick(() => { this.showInput = !this.showInput })
      }
      .padding({ left: 20, right: 20, top: 56, bottom: 16 })
      .width('100%')

      // Collapsible input area
      if (this.showInput) {
        Column({ space: 12 }) {
          TextArea({ text: this.inputText, placeholder: '每行一个 M3U8 URL，支持批量粘贴' })
            .onChange((val: string) => { this.inputText = val })
            .fontSize(13)
            .fontColor('#1D1D1F')
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding(12)
            .height(120)
            .width('100%')
          Button('全部添加')
            .width('100%')
            .height(44)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#1677FF')
            .borderRadius(10)
            .onClick(() => { this.addTasks() })
        }
        .padding({ left: 20, right: 20, bottom: 16 })
        .width('100%')
      }

      // Task list
      Scroll() {
        Column({ space: 12 }) {
          if (this.tasks.length === 0) {
            Text('暂无任务，点击右上角 + 添加')
              .fontSize(14)
              .fontColor('#8C8C8C')
              .margin({ top: 60 })
          } else {
            ForEach(this.tasks, (task: DownloadTask) => {
              TaskCard({ task: task })
            }, (task: DownloadTask) => task.url)
          }
        }
        .padding({ left: 20, right: 20, top: 8, bottom: 40 })
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
