
export class M3U8FileDownloadInfo {
  url_m3u8?: string
  resumeFile?: string
  filePath?: string
  downloadUrl?: string
  totalDownload?: number
  completeDownload?: number
  success?: boolean
  failed?: boolean
  pauseSuccess?: boolean
  pauseFailed?: boolean

  isStsAddress: boolean = false
}
