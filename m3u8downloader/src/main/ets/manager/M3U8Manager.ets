import { HashMap } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { M3U8ManagerConfig } from '../model/M3U8Config'
import { M3U8DownloadState } from '../model/M3U8DownloadState'
import { M3U8Setting } from '../tools/M3U8Setting'
import { M3U8FileManager } from '../filemanager/M3U8FileManager'
import { M3U8DownloadContainer, DownloadProgressHandler, DownloadCompleteHandler } from '../container/M3U8DownloadContainer'
import { LogBus } from '../logger/LogBus'
import { M3U8LocalServer } from '../server/M3U8LocalServer'

export declare type M3U8PauseCompletionHandler = (error?: BusinessError) => void

export class M3U8Manager {

  private static _instance = new M3U8Manager()

  static get instance(): M3U8Manager {
    return M3U8Manager._instance
  }

  private config?: M3U8ManagerConfig
  private downloadContainerMap: HashMap<string, M3U8DownloadContainer> = new HashMap()

  async setup(config: M3U8ManagerConfig): Promise<void> {
    this.config = config
    if (config.logger) {
      LogBus.instance.setLogger(config.logger)
    }
    await new Promise<void>((resolve, reject) => {
      M3U8LocalServer.instance.start(config.saveFilePath, config.port ?? 8080, (success) => {
        if (success) {
          resolve()
        } else {
          reject(new Error(`M3U8LocalServer failed to start on port ${config.port ?? 8080}`))
        }
      })
    })
  }

  download(
    url: string,
    onProgress: DownloadProgressHandler,
    onComplete: DownloadCompleteHandler
  ) {
    if (!this.config) {
      LogBus.instance.error('M3U8Manager', 'setup() must be called before download()')
      onComplete(M3U8DownloadState.Fail, '')
      return
    }

    const container = this.containerForUrl(url)
    container.downloadWithUrl(
      this.config.saveFilePath,
      url,
      100,
      onProgress,
      this.buildWrappedCompleteHandler(url, onComplete)
    )
  }

  pause(url: string, completionHandler: M3U8PauseCompletionHandler) {
    const container = this.containerForUrl(url)
    container.pauseDownloadTask(completionHandler)
  }

  resume(
    url: string,
    completionHandler: M3U8PauseCompletionHandler,
    onProgress: DownloadProgressHandler,
    onComplete: DownloadCompleteHandler
  ) {
    const container = this.containerForUrl(url)
    if (container.downloader) {
      // Hot resume: rebind callbacks so this resume's closures are used
      container.downloadProgressHandler = onProgress
      container.completeHandler = this.buildWrappedCompleteHandler(url, onComplete)
      container.restoreDownloadTask(completionHandler)
    } else {
      // Cold resume: re-fetch manifest; M3U8Downloader.start() pre-scan skips already-downloaded TS files
      this.download(url, onProgress, onComplete)
      completionHandler()
    }
  }

  delete(url: string, completionHandler: M3U8PauseCompletionHandler) {
    const container = this.containerForUrl(url)
    container.deleteDownloadTask(completionHandler)
  }

  removeLocalFiles(url: string) {
    if (!this.config) {
      return
    }
    const container = this.containerForUrl(url)
    container.removeFiles(url, () => {
      LogBus.instance.info('M3U8Manager', 'local files removed for ' + url)
    })
  }

  /**
   * Builds a complete handler that removes the container from the map when
   * the download reaches a terminal state (Complete or Cancel), then forwards
   * the state to the caller's onComplete callback.
   */
  private buildWrappedCompleteHandler(url: string, onComplete: DownloadCompleteHandler): DownloadCompleteHandler {
    return (state, localUrl, error) => {
      if (state === M3U8DownloadState.Complete || state === M3U8DownloadState.Cancel) {
        this.downloadContainerMap.remove(M3U8Setting.uuidWithUrl(url))
      }
      onComplete(state, localUrl, error)
    }
  }

  private containerForUrl(url: string): M3U8DownloadContainer {
    if (!this.config) {
      return new M3U8DownloadContainer()
    }
    // Ensure parent directory exists before uuidWithUrl tries to create the subdirectory
    M3U8Setting.commonDirPrefix(this.config.saveFilePath)
    const key = M3U8Setting.uuidWithUrl(url)
    let container = this.downloadContainerMap.get(key)
    if (!container) {
      container = new M3U8DownloadContainer()
      container.context = this.config.context
      container.saveFilePath = this.config.saveFilePath
      container.defaultHeaders = this.config.defaultHeaders
      container.port = this.config.port ?? 8080
      container.concurrency = this.config.concurrency ?? 3
      this.downloadContainerMap.set(key, container)
    }
    return container
  }
}
