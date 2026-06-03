import { fileIo } from '@kit.CoreFileKit'
import { md5 } from './M3U8MD5'

export class M3U8Setting {

  static localHost(port: number = 8080): string {
    return `http://127.0.0.1:${port}`
  }

  static m3u8InfoFilename(): string {
    return 'movie.m3u8'
  }

  static oriM3U8InfoFileName(): string {
    return 'oriMovie.m3u8'
  }

  static keyFileName(): string {
    return 'key'
  }

  static resumeKeyFileName(): string {
    return 'resumeKey'
  }

  static ensureDir(dirPath: string): void {
    let isHave = fileIo.accessSync(dirPath)
    if (!isHave) {
      fileIo.mkdirSync(dirPath)
    }
  }

  static commonDirPrefix(path: string): string {
    let fileDir = path + '/m3u8files/'
    M3U8Setting.ensureDir(fileDir)
    return fileDir
  }

  static uuidWithUrl(url: string): string {
    return md5(url)
  }

  static tsFileWithIdentify(identify: string): string {
    return `${identify}.ts`
  }

  static tsResumeFileWithIdentify(identify: string): string {
    return `${identify}.data`
  }

  static fullCommonDirPrefixWithUrl(path: string, url: string): string {
    const dirPrefix = M3U8Setting.commonDirPrefix(path)
    const uuid = M3U8Setting.uuidWithUrl(url)
    const fullDir = dirPrefix + uuid
    M3U8Setting.ensureDir(fullDir)
    return fullDir
  }

  static buildHeaders(defaultHeaders?: Record<string, string>): Record<string, string> {
    const headers: Record<string, string> = {}
    if (defaultHeaders) {
      const keys = Object.keys(defaultHeaders)
      for (let i = 0; i < keys.length; i++) {
        headers[keys[i]] = defaultHeaders[keys[i]]
      }
    }
    return headers
  }
}
