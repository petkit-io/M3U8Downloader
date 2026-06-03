import { M3U8Manager, M3U8DownloadState } from '@wangbinji/m3u8downloader'
import { DownloadTask, TaskState } from '../model/DownloadTask'
import { TaskStore } from '../store/TaskStore'
import { parseLabel } from '../utils/UrlParser'

const MAX_CONCURRENT = 3

export class TaskQueue {
  private static _instance = new TaskQueue()

  static get instance(): TaskQueue {
    return TaskQueue._instance
  }

  private tasks: DownloadTask[] = []
  private store: TaskStore = new TaskStore()
  private onTasksChanged: ((tasks: DownloadTask[]) => void) | null = null

  async setup(context: Context, onTasksChanged: (tasks: DownloadTask[]) => void): Promise<void> {
    this.onTasksChanged = onTasksChanged
    await this.store.init(context)
    this.tasks = await this.store.loadTasks()
    this.notify()
    // Queued tasks are NOT auto-started on launch; user must click start explicitly
  }

  addTasks(urls: string[]): void {
    for (let i = 0; i < urls.length; i++) {
      const url = urls[i].trim()
      if (!url) {
        continue
      }
      // Skip duplicates
      if (this.findTask(url) !== null) {
        continue
      }
      const task = new DownloadTask(url, parseLabel(url))
      this.tasks.push(task)
      // Tasks stay Queued; user starts them manually
    }
    this.save()
    this.notify()
  }

  pauseTask(url: string): void {
    const task = this.findTask(url)
    if (!task || task.state !== TaskState.Downloading) {
      return
    }
    M3U8Manager.instance.pause(url, () => {
      task.state = TaskState.Paused
      this.save()
      this.notify()
    })
  }

  resumeTask(url: string): void {
    const task = this.findTask(url)
    if (!task) {
      return
    }
    if (this.activeCount() < MAX_CONCURRENT) {
      this.startTask(task)
    } else {
      task.state = TaskState.Queued
      this.save()
      this.notify()
    }
  }

  deleteTask(url: string): void {
    const task = this.findTask(url)
    if (!task) {
      return
    }
    const wasDownloading = task.state === TaskState.Downloading
    if (wasDownloading) {
      M3U8Manager.instance.delete(url, () => {
        this.removeTaskFromList(url)
      })
    } else {
      this.removeTaskFromList(url)
    }
  }

  retryTask(url: string): void {
    const task = this.findTask(url)
    if (!task) {
      return
    }
    task.progress = 0
    task.errorMsg = ''
    task.localPath = ''
    this.resumeTask(url)
  }

  private removeTaskFromList(url: string): void {
    M3U8Manager.instance.removeLocalFiles(url)
    const newTasks: DownloadTask[] = []
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].url !== url) {
        newTasks.push(this.tasks[i])
      }
    }
    this.tasks = newTasks
    this.save()
    this.notify()
  }

  private startTask(task: DownloadTask): void {
    task.state = TaskState.Downloading
    this.save()
    this.notify()
    M3U8Manager.instance.download(
      task.url,
      (progress: number, downloadedSegments: number, totalSegments: number) => {
        task.progress = progress
        this.notify()
      },
      (state: M3U8DownloadState, localUrl: string, error?: Error) => {
        if (state === M3U8DownloadState.Complete) {
          task.state = TaskState.Complete
          task.localPath = localUrl
          task.progress = 1
        } else if (state === M3U8DownloadState.Fail) {
          task.state = TaskState.Failed
          task.errorMsg = error?.message ?? '未知错误'
        }
        this.save()
        this.notify()
      }
    )
  }

  private activeCount(): number {
    let count = 0
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].state === TaskState.Downloading) {
        count++
      }
    }
    return count
  }

  private findTask(url: string): DownloadTask | null {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].url === url) {
        return this.tasks[i]
      }
    }
    return null
  }

  private save(): void {
    this.store.saveTasks(this.tasks)
  }

  private notify(): void {
    if (this.onTasksChanged) {
      // Reverse so newest-added tasks appear at top
      const reversed: DownloadTask[] = []
      for (let i = this.tasks.length - 1; i >= 0; i--) {
        reversed.push(this.tasks[i])
      }
      this.onTasksChanged(reversed)
    }
  }
}
