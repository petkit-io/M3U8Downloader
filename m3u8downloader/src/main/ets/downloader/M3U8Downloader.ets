import { M3U8FileDownloadInfo } from '../model/M3U8FileDownloadInfo'
import { M3U8DownloadState } from '../model/M3U8DownloadState'
import { M3U8FileManager } from '../filemanager/M3U8FileManager'
import { M3U8Setting } from '../tools/M3U8Setting'
import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { LogBus } from '../logger/LogBus'

const TAG: string = 'M3U8Downloader'

export declare type DownloaderCompleteHandler = (state: M3U8DownloadState, error?: Error) => void
export declare type DownloaderPauseCompletionHandler = (error?: BusinessError) => void

export class M3U8Downloader {

  context?: Context
  url: string = ''
  fileDownloadInfos?: M3U8FileDownloadInfo[] = []
  completeHandler?: DownloaderCompleteHandler
  pause?: boolean
  cancel?: boolean
  storage: number = 10
  defaultHeaders?: Record<string, string>
  /** Concurrent TS segment download window size. Valid range: 1–5. Default: 3. */
  concurrency: number = 3

  progressHandler?: (progress: number, downloadedSegments: number, totalSegments: number) => void

  // Per-segment in-flight download progress (index → 0.0~1.0)
  private segmentProgress: Map<number, number> = new Map()
  // Monotonic progress guard: never report a value lower than the last reported
  private lastReportedProgress: number = 0
  // Generation counter: incremented on each start() to discard stale async callbacks
  private runId: number = 0

  constructor(downloadInfos: M3U8FileDownloadInfo[], totalStorage: number, context: Context, completeHandler: DownloaderCompleteHandler) {
    this.fileDownloadInfos = downloadInfos
    this.completeHandler = completeHandler
    this.cancel = false
    this.context = context
    this.storage = totalStorage
  }

  start() {
    // Advance generation so any in-flight callbacks from a previous run are ignored
    this.runId++
    const myRunId = this.runId

    this.cancel = false
    this.pause = false
    this.segmentProgress.clear()
    this.lastReportedProgress = 0

    if (!this.fileDownloadInfos || this.fileDownloadInfos.length <= 0) {
      LogBus.instance.error(TAG, 'start() - no download infos, calling Fail')
      this.completeHandler?.(M3U8DownloadState.Fail)
      return
    }

    const infos = this.fileDownloadInfos!
    const total = infos.length
    LogBus.instance.info(TAG, `start() - total items: ${total} concurrency=${this.effectiveConcurrency()}`)
    this.completeHandler?.(M3U8DownloadState.Downloading)

    // Pre-scan already-downloaded files to avoid restarting progress from 0 on resume
    let existingCount = 0
    for (let i = 0; i < total; i++) {
      if (fileIo.accessSync(infos[i].filePath ?? '')) {
        infos[i].success = true
        existingCount++
      }
    }

    if (existingCount > 0) {
      LogBus.instance.info(TAG, `pre-scan: ${existingCount}/${total} already downloaded`)
      if (this.progressHandler) {
        this.reportProgress(existingCount / total, existingCount, total)
      }
    }

    if (existingCount === total) {
      LogBus.instance.info(TAG, 'ALL DONE (pre-scan) -> Complete')
      this.completeHandler?.(M3U8DownloadState.Complete)
      return
    }

    this.startConcurrentDownload(myRunId)
  }

  private effectiveConcurrency(): number {
    return (this.concurrency >= 1 && this.concurrency <= 5) ? this.concurrency : 3
  }

  private startConcurrentDownload(myRunId: number) {
    const infos = this.fileDownloadInfos!
    let nextIndex = 0

    const startNext = () => {
      // Skip already-completed items
      while (nextIndex < infos.length && infos[nextIndex].success) {
        nextIndex++
      }
      if (nextIndex >= infos.length || this.cancel || this.pause || this.runId !== myRunId) {
        return
      }
      const index = nextIndex++
      LogBus.instance.info(TAG, `item[${index}] start url=${infos[index].downloadUrl} isSts=${infos[index].isStsAddress}`)
      this.createDownloadTaskWithInfo(infos[index], index, myRunId, () => {
        if (this.runId === myRunId && !this.cancel && !this.pause) {
          startNext()
        }
      })
    }

    const slots = this.effectiveConcurrency()
    for (let i = 0; i < slots; i++) {
      startNext()
    }
  }

  private createDownloadTaskWithInfo(downloadInfo: M3U8FileDownloadInfo, index: number, runId: number, next: () => void) {
    const headers = M3U8Setting.buildHeaders(this.defaultHeaders)

    if (downloadInfo.isStsAddress) {
      // AES key download — runs outside the concurrent TS window
      http.createHttp().request(downloadInfo.downloadUrl ?? '', {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      }, (err: BusinessError, data: http.HttpResponse) => {
        if (this.runId !== runId) {
          return
        }
        if (err || !data || !data.result) {
          LogBus.instance.error(TAG, `key[${index}] FAILED err=${err?.message ?? 'no data'} code=${err?.code}`)
          downloadInfo.failed = true
          this.verifyDownloadCountAndCallback(false)
          next()
          return
        }
        LogBus.instance.info(TAG, `key[${index}] OK, saving to ${downloadInfo.filePath}`)
        M3U8FileManager.instance.saveData(data.result as ArrayBuffer, downloadInfo.filePath ?? '', () => {
          if (this.runId !== runId) {
            return
          }
          downloadInfo.success = true
          this.verifyDownloadCountAndCallback(true)
          next()
        })
      })
    } else {
      // TS segment download
      const httpRequest = http.createHttp()
      this.segmentProgress.set(index, 0)
      httpRequest.on('dataReceiveProgress', (data) => {
        if (this.runId !== runId || this.cancel || this.pause) {
          return
        }
        if (data.totalSize > 0) {
          this.segmentProgress.set(index, data.receiveSize / data.totalSize)
          this.reportIntermediateProgress()
        }
      })
      httpRequest.request(downloadInfo.downloadUrl ?? '', {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      }, (err: BusinessError, data: http.HttpResponse) => {
        if (this.runId !== runId) {
          httpRequest.destroy()
          return
        }
        // Remove in-flight entry before reporting so progress never double-counts
        this.segmentProgress.delete(index)
        if (err || !data || !data.result) {
          LogBus.instance.error(TAG, `ts[${index}] FAILED err=${err?.message ?? 'no data'} code=${err?.code} url=${downloadInfo.downloadUrl}`)
          downloadInfo.failed = true
          this.verifyDownloadCountAndCallback(false)
          httpRequest.destroy()
          next()
          return
        }
        const buffer = data.result as ArrayBuffer
        LogBus.instance.info(TAG, `ts[${index}] OK size=${buffer.byteLength}, saving to ${downloadInfo.filePath}`)
        M3U8FileManager.instance.saveData(buffer, downloadInfo.filePath ?? '', () => {
          if (this.runId !== runId) {
            return
          }
          downloadInfo.success = true
          this.verifyDownloadCountAndCallback(true)
          next()
        })
        httpRequest.destroy()
      })
    }
  }

  // Intermediate progress during active downloads: (completed + sum of in-flight ratios) / total
  private reportIntermediateProgress() {
    const total = this.fileDownloadInfos?.length ?? 0
    if (total <= 0 || !this.progressHandler) {
      return
    }

    let successCount = 0
    this.fileDownloadInfos?.forEach((value) => {
      if (value.success) {
        successCount++
      }
    })

    let inFlightSum = 0
    this.segmentProgress.forEach((p) => {
      inFlightSum += p
    })

    const raw = (successCount + inFlightSum) / total
    this.reportProgress(Math.min(1.0, raw), successCount, total)
  }

  private verifyDownloadCountAndCallback(isSuccess: boolean) {
    if (this.cancel || this.pause) {
      return
    }

    let successCount = 0
    let failCount = 0

    this.fileDownloadInfos?.forEach((value) => {
      if (value.success) {
        successCount++
      } else if (value.failed) {
        failCount++
      }
    })

    const total = this.fileDownloadInfos?.length ?? 0
    LogBus.instance.info(TAG, `verify success=${successCount} fail=${failCount} total=${total}`)

    if (total > 0 && this.progressHandler) {
      let inFlightSum = 0
      this.segmentProgress.forEach((p) => {
        inFlightSum += p
      })
      const raw = (successCount + inFlightSum) / total
      this.reportProgress(Math.min(1.0, raw), successCount, total)
    }

    if (isSuccess && successCount == total) {
      LogBus.instance.info(TAG, 'ALL DONE -> Complete')
      this.completeHandler?.(M3U8DownloadState.Complete)
      return
    }

    if (failCount > 0 && successCount + failCount == total) {
      LogBus.instance.error(TAG, `SOME FAILED -> Fail (success=${successCount} fail=${failCount})`)
      const error = new Error('download failed')
      this.completeHandler?.(M3U8DownloadState.Fail, error)
    }
  }

  // Monotonic progress reporter: never lets progress go backwards
  private reportProgress(progress: number, downloadedSegments: number, totalSegments: number) {
    const safe = Math.max(this.lastReportedProgress, progress)
    this.lastReportedProgress = safe
    this.progressHandler?.(safe, downloadedSegments, totalSegments)
  }

  pauseDownload(completionHandler: DownloaderPauseCompletionHandler) {
    this.pause = true
    completionHandler()
  }

  deleteDownload(completionHandler: DownloaderPauseCompletionHandler) {
    this.cancel = true
    completionHandler()
  }

  restoreDownload(completionHandler: DownloaderPauseCompletionHandler) {
    this.pause = false
    this.cancel = false
    this.start()
    completionHandler()
  }
}
