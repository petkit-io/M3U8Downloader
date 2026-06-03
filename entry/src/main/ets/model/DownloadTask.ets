export enum TaskState {
  Queued      = 'Queued',
  Downloading = 'Downloading',
  Paused      = 'Paused',
  Interrupted = 'Interrupted',
  Complete    = 'Complete',
  Failed      = 'Failed',
}

@Observed
export class DownloadTask {
  url: string
  label: string
  state: TaskState
  progress: number      // 0.0 – 1.0
  localPath: string     // absolute path to movie.m3u8 when complete
  addedAt: number       // Date.now() ms timestamp
  errorMsg: string

  constructor(url: string, label: string) {
    this.url = url
    this.label = label
    this.state = TaskState.Queued
    this.progress = 0
    this.localPath = ''
    this.addedAt = Date.now()
    this.errorMsg = ''
  }
}
