import { M3U8Setting } from './M3U8Setting'

export class TextRange {
  location: number = 0
  length: number = 0

  constructor(location: number, length: number) {
    this.location = location
    this.length = length
  }
}

export class M3U8Tools {

  static rangeOfString(origin: string, subStr: string): TextRange {
    let location = origin.indexOf(subStr)
    let length = subStr.length
    return new TextRange(location, length)
  }

  static subStringWithRange(originStr: string, range: TextRange): string {
    return originStr.substring(range.location, range.location + range.length)
  }

  static subStringFrom(origin: string, start: string, end: string): string {
    let startRange = M3U8Tools.rangeOfString(origin, start)
    if (startRange.location == -1) {
      return ''
    }
    let textRange = new TextRange(startRange.location + startRange.length, origin.length - startRange.location - startRange.length)
    let newStr = M3U8Tools.subStringWithRange(origin, textRange)
    let kEndRange = M3U8Tools.rangeOfString(newStr, end)
    if (kEndRange.location == -1) {
      return ''
    }
    let endRange = new TextRange(kEndRange.location + startRange.location + startRange.length, kEndRange.length)
    let range = new TextRange(startRange.location + startRange.length, endRange.location - startRange.location - startRange.length)
    return M3U8Tools.subStringWithRange(origin, range)
  }

  static subStringFromByOffset(originStr: string, fromStr: string, offset: number): string {
    let startRange = M3U8Tools.rangeOfString(originStr, fromStr)
    if (startRange.location != -1) {
      return originStr.substring(startRange.location + offset)
    }
    return ''
  }

  static subStringTo(originStr: string, toStr: string): string {
    let startRange = M3U8Tools.rangeOfString(originStr, toStr)
    return M3U8Tools.subStringWithRange(originStr, new TextRange(0, startRange.location))
  }

  static pkKeyUriM3U8FilePath(path: string, filePathUrl: string, kUriUrl: string): string {
    return M3U8Tools.pkm3u8KeyUriFilePath(path, filePathUrl, kUriUrl, 0, true)
  }

  static pkm3u8FilePath(path: string, filePath: string, tsIndex: number): string {
    return M3U8Tools.pkm3u8KeyUriFilePath(path, filePath, '', tsIndex, false)
  }

  static pkm3u8KeyUriFilePath(path: string, url: string, keyUri: string, index: number, isKeyUri: boolean): string {
    let appendPath: string = ''
    if (isKeyUri) {
      appendPath = M3U8Setting.uuidWithUrl(keyUri)
    } else {
      appendPath = M3U8Setting.tsFileWithIdentify(index.toString())
    }
    return M3U8Setting.fullCommonDirPrefixWithUrl(path, url) + '/' + appendPath
  }

  static pkKeyUriM3U8ResumeFilePath(path: string, url: string): string {
    return M3U8Tools.pkm3u8KeyUriResumeFilePath(path, url, 0, true)
  }

  static pkm3u8ResumeFilePath(path: string, url: string, index: number): string {
    return M3U8Tools.pkm3u8KeyUriResumeFilePath(path, url, index, false)
  }

  static pkm3u8KeyUriResumeFilePath(path: string, url: string, index: number, isKeyUri: boolean): string {
    let appendPath: string = ''
    if (isKeyUri) {
      appendPath = M3U8Setting.resumeKeyFileName()
    } else {
      appendPath = M3U8Setting.tsResumeFileWithIdentify(index.toString())
    }
    return M3U8Setting.fullCommonDirPrefixWithUrl(path, url) + '/' + appendPath
  }

  static pkM3U8LocalContentFilePath(path: string, url: string): string {
    return M3U8Setting.fullCommonDirPrefixWithUrl(path, url) + '/' + M3U8Setting.m3u8InfoFilename()
  }

  static pkM3U8HttpContentFilePath(path: string, url: string): string {
    return M3U8Setting.fullCommonDirPrefixWithUrl(path, url) + '/httpMovie.m3u8'
  }

  static pkM3U8RemoteContentFilePath(path: string, url: string): string {
    return M3U8Setting.fullCommonDirPrefixWithUrl(path, url) + '/' + M3U8Setting.oriM3U8InfoFileName()
  }

  static pkMp4FilePath(path: string, url: string): string {
    return M3U8Setting.commonDirPrefix(path) + M3U8Setting.uuidWithUrl(url) + '.mp4'
  }

  static resolveUrl(baseUrl: string, relativeUrl: string): string {
    if (relativeUrl.startsWith('http://') || relativeUrl.startsWith('https://')) {
      return relativeUrl
    }

    const urlParts = baseUrl.split('/')
    if (relativeUrl.startsWith('/')) {
      // Absolute path from root
      return urlParts[0] + '//' + urlParts[2] + relativeUrl
    } else {
      // Relative path
      urlParts.pop() // remove filename or last segment
      return urlParts.join('/') + '/' + relativeUrl
    }
  }
}
