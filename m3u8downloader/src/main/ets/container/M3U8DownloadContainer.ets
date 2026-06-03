import { M3U8Info } from '../model/M3U8Info'
import { M3U8FileDownloadInfo } from '../model/M3U8FileDownloadInfo'
import { M3U8DownloadState } from '../model/M3U8DownloadState'
import { M3U8FileManager } from '../filemanager/M3U8FileManager'
import { M3U8Setting } from '../tools/M3U8Setting'
import { M3U8Tools } from '../tools/M3U8Tools'
import { M3U8Analyser, AnalysisHandler } from '../analyser/M3U8Analyser'
import { M3U8Downloader, DownloaderPauseCompletionHandler } from '../downloader/M3U8Downloader'
import { BusinessError } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
import { LogBus } from '../logger/LogBus'

const TAG: string = 'M3U8DownloadContainer'

export declare type DownloadProgressHandler = (progress: number, downloadedSegments: number, totalSegments: number) => void
export declare type DownloadCompleteHandler = (state: M3U8DownloadState, localUrl: string, error?: Error) => void

export class M3U8DownloadContainer {

  m3u8Info?: M3U8Info
  downloader?: M3U8Downloader
  m3u8OriUrl?: string
  cancel?: boolean
  pause?: boolean
  storage: number = 10
  analysisHandler?: AnalysisHandler
  downloadProgressHandler?: DownloadProgressHandler
  completeHandler?: DownloadCompleteHandler
  saveFilePath: string = ''
  context?: Context
  defaultHeaders?: Record<string, string>
  port: number = 8080
  concurrency: number = 3

  constructor() {
    this.cancel = false
  }

  downloadWithUrl(path: string, url: string, storage: number,
    downloadProgressHandler: DownloadProgressHandler,
    completeHandler: DownloadCompleteHandler) {

    this.saveFilePath = path
    this.downloadProgressHandler = downloadProgressHandler
    this.completeHandler = completeHandler
    this.m3u8OriUrl = url
    this.storage = storage

    const headers = M3U8Setting.buildHeaders(this.defaultHeaders)

    http.createHttp().request(url, {
      method: http.RequestMethod.GET,
      header: headers,
      expectDataType: http.HttpDataType.STRING
    }, (err: BusinessError, data: http.HttpResponse) => {

      if (err || !data || !data.result) {
        LogBus.instance.error(TAG, `fetch m3u8 FAILED err=${err?.message ?? 'no data'} code=${err?.code}`)
        completeHandler(M3U8DownloadState.Fail, '')
        return
      }

      const rawStr = data.result as string
      LogBus.instance.info(TAG, `m3u8 fetched len=${rawStr.length} hasEXTINF=${rawStr.includes('#EXTINF:')}`)

      const m3u8File = M3U8Tools.pkM3U8RemoteContentFilePath(path, url)
      M3U8FileManager.instance.saveData(data.result as string, m3u8File, () => {
        LogBus.instance.info(TAG, 'remote m3u8 saved: ' + m3u8File)
      })

      M3U8Analyser.analysisWithOriginUrlString(path, url, rawStr, this.port, (info, error) => {
        if (error) {
          LogBus.instance.error(TAG, `analysis error: ${error.message}`)
          this.analysisHandler?.(info, error)
          completeHandler(M3U8DownloadState.Fail, '')
        } else {
          LogBus.instance.info(TAG, `analysis ok, ts count=${info.tsInfos?.length ?? 0}`)
          this.m3u8Info = info
          this.analysisHandler?.(info)
          this.createDownloaderAndStartDownload()
        }
      })
    })
  }

  private createDownloaderAndStartDownload() {
    this.downloader = new M3U8Downloader(this.buildFileDownloadInfos(), this.storage, this.context!, (state, error) => {
      if (state == M3U8DownloadState.Complete) {
        if (error) {
          this.completeHandler?.(M3U8DownloadState.Fail, '', error)
        } else {
          this.saveM3U8File()
        }
      } else if (state == M3U8DownloadState.Fail) {
        this.completeHandler?.(M3U8DownloadState.Fail, '', error)
      }
    })

    this.downloader.progressHandler = (progress, downloadedSegments, totalSegments) => {
      this.downloadProgressHandler?.(progress, downloadedSegments, totalSegments)
    }

    this.downloader.defaultHeaders = this.defaultHeaders
    this.downloader.concurrency = this.concurrency
    this.downloader.start()
  }

  private saveM3U8File() {
    const m3u8Str = M3U8Analyser.synthesisLocalM3U8WithM3U8Info(this.saveFilePath, this.m3u8Info!, this.m3u8OriUrl!, this.port)
    const m3u8File = M3U8Tools.pkM3U8LocalContentFilePath(this.saveFilePath, this.m3u8OriUrl!)

    M3U8FileManager.instance.saveData(m3u8Str, m3u8File, (error) => {
      if (error) {
        this.completeHandler?.(M3U8DownloadState.Fail, '', error)
      } else {
        const httpM3u8Str = M3U8Analyser.synthesisHttpM3U8(this.m3u8Info!, this.port)
        const httpM3u8File = M3U8Tools.pkM3U8HttpContentFilePath(this.saveFilePath, this.m3u8OriUrl!)
        M3U8FileManager.instance.saveData(httpM3u8Str, httpM3u8File, (error) => {
          if (error) {
            LogBus.instance.warn(TAG, 'httpMovie.m3u8 save failed: ' + error.message)
            // still report Complete since the main m3u8 file succeeded
          }
          this.completeHandler?.(M3U8DownloadState.Complete, m3u8File)
        })
      }
    })
  }

  private buildFileDownloadInfos(): M3U8FileDownloadInfo[] {
    let tempArray: M3U8FileDownloadInfo[] = []
    const addedKeyUris = new Set<string>()
    this.m3u8Info?.tsInfos?.forEach((tsInfo) => {

      let downloadInfo = new M3U8FileDownloadInfo()
      downloadInfo.downloadUrl = tsInfo.oriUrlString
      downloadInfo.filePath = M3U8Tools.pkm3u8FilePath(this.saveFilePath, this.m3u8OriUrl!, tsInfo.index ?? 0)
      downloadInfo.resumeFile = M3U8Tools.pkm3u8ResumeFilePath(this.saveFilePath, this.m3u8OriUrl!, tsInfo.index ?? 0)
      downloadInfo.completeDownload = tsInfo.completed
      downloadInfo.url_m3u8 = this.m3u8OriUrl
      if (downloadInfo.downloadUrl && downloadInfo.downloadUrl.length > 0) {
        tempArray.push(downloadInfo)
      }

      if (tsInfo.key?.keyUri && !addedKeyUris.has(tsInfo.key.keyUri)) {
        addedKeyUris.add(tsInfo.key.keyUri)
        let downloadKeyInfo = new M3U8FileDownloadInfo()
        downloadKeyInfo.downloadUrl = tsInfo.key.keyUri
        downloadKeyInfo.filePath = M3U8Tools.pkKeyUriM3U8FilePath(this.saveFilePath, this.m3u8OriUrl!, tsInfo.key.keyUri)
        downloadKeyInfo.url_m3u8 = this.m3u8OriUrl
        downloadKeyInfo.resumeFile = M3U8Tools.pkKeyUriM3U8ResumeFilePath(this.saveFilePath, tsInfo.key.keyUri)
        downloadKeyInfo.isStsAddress = true
        if (downloadKeyInfo.downloadUrl && downloadKeyInfo.downloadUrl.length > 0) {
          tempArray.push(downloadKeyInfo)
        }
      }
    })
    return tempArray
  }

  removeFiles(url: string, completionHandler: DownloaderPauseCompletionHandler) {
    const dir = M3U8Setting.commonDirPrefix(this.saveFilePath)
    const subPath = M3U8Setting.uuidWithUrl(url)
    const path = dir + subPath
    M3U8FileManager.instance.removeFileWithPath(path)
    completionHandler()
  }

  pauseDownloadTask(completionHandler: DownloaderPauseCompletionHandler) {
    if (this.downloader) {
      this.downloader.pauseDownload(completionHandler)
    } else {
      completionHandler()
    }
  }

  deleteDownloadTask(completionHandler: DownloaderPauseCompletionHandler) {
    if (this.downloader) {
      this.downloader.deleteDownload((error) => {
        this.completeHandler?.(M3U8DownloadState.Cancel, '')
        completionHandler(error)
      })
    } else {
      completionHandler()
    }
  }

  restoreDownloadTask(completionHandler: DownloaderPauseCompletionHandler) {
    if (this.downloader) {
      this.downloader.restoreDownload(completionHandler)
    } else {
      this.createDownloaderAndStartDownload()
      completionHandler()
    }
  }
}
