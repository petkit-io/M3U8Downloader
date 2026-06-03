import dataPreferences from '@ohos.data.preferences'
import { DownloadTask, TaskState } from '../model/DownloadTask'

const STORE_NAME = 'M3U8TaskStore'
const KEY_TASKS = 'download_tasks'

export class TaskStore {
  private prefs: dataPreferences.Preferences | null = null

  async init(context: Context): Promise<void> {
    this.prefs = await dataPreferences.getPreferences(context, STORE_NAME)
  }

  saveTasks(tasks: DownloadTask[]): void {
    if (!this.prefs) {
      return
    }
    const raw = JSON.stringify(tasks)
    this.prefs.put(KEY_TASKS, raw).then(() => {
      this.prefs!.flush()
    })
  }

  async loadTasks(): Promise<DownloadTask[]> {
    if (!this.prefs) {
      return []
    }
    const raw = await this.prefs.get(KEY_TASKS, '[]') as string
    let parsed: DownloadTask[]
    try {
      parsed = JSON.parse(raw) as DownloadTask[]
    } catch {
      return []
    }
    // 从 JSON 重建 @Observed 实例，确保属性追踪正常工作
    const result: DownloadTask[] = []
    for (let i = 0; i < parsed.length; i++) {
      const obj = parsed[i]
      const task = new DownloadTask(obj.url ?? '', obj.label ?? '')
      task.state = obj.state ?? TaskState.Queued
      task.progress = obj.progress ?? 0
      task.localPath = obj.localPath ?? ''
      task.addedAt = obj.addedAt ?? Date.now()
      task.errorMsg = obj.errorMsg ?? ''
      if (task.state === TaskState.Downloading) {
        task.state = TaskState.Interrupted
      }
      result.push(task)
    }
    return result
  }
}
