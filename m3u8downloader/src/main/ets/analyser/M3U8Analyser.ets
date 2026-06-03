import { M3U8Info, M3U8KeyInfo, M3U8TsInfo } from '../model/M3U8Info'
import { BusinessError } from '@kit.BasicServicesKit'
import { M3U8Tools } from '../tools/M3U8Tools'
import { M3U8Setting } from '../tools/M3U8Setting'
import { LogBus } from '../logger/LogBus'

const TAG: string = 'M3U8Analyser'

export declare type AnalysisHandler = (m3u8Info: M3U8Info, error?: BusinessError) => void

export class M3U8Analyser {

  static analysisWithOriginUrlString(path: string, oriUrlString: string, m3u8Str: string, port: number = 8080, completionHandler: AnalysisHandler) {
    let info = new M3U8Info()
    let tsInfos: M3U8TsInfo[] = []
    let lines = m3u8Str.split(/\r?\n/)

    let currentTsInfo: M3U8TsInfo | null = null
    let globalKey: M3U8KeyInfo | null = null
    let index = 0

    for (let i = 0; i < lines.length; i++) {
      let line = lines[i].trim()
      if (!line) continue

      if (line.startsWith('#EXT-X-VERSION:')) {
        info.version = line.substring('#EXT-X-VERSION:'.length).trim()
      } else if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        info.targetDuration = line.substring('#EXT-X-TARGETDURATION:'.length).trim()
      } else if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        info.mediaSequence = line.substring('#EXT-X-MEDIA-SEQUENCE:'.length).trim()
      } else if (line.startsWith('#EXT-X-KEY:')) {
        let keyInfo = new M3U8KeyInfo()
        let keyContent = line.substring('#EXT-X-KEY:'.length)
        keyInfo.keyMethod = M3U8Tools.subStringFrom(keyContent + ',', 'METHOD=', ',').trim()
        let keyUri = M3U8Tools.subStringFrom(keyContent + ',', 'URI="', '"').trim()
        if (keyUri) {
          keyInfo.keyUri = M3U8Tools.resolveUrl(oriUrlString, keyUri)
          keyInfo.keyLocalUri = `${M3U8Setting.localHost(port)}/${M3U8Setting.uuidWithUrl(oriUrlString)}/${M3U8Setting.uuidWithUrl(keyInfo.keyUri)}`
        }
        keyInfo.keyIv = M3U8Tools.subStringFrom(keyContent + ',', 'IV=', ',').trim()
        
        // If it's before any EXTINF, it's a global key
        if (tsInfos.length === 0) {
          globalKey = keyInfo
          info.keyMethod = keyInfo.keyMethod
          info.keyUrl = keyInfo.keyUri
          info.keyIv = keyInfo.keyIv
          info.keyLocalUri = keyInfo.keyLocalUri
        } else if (currentTsInfo) {
          currentTsInfo.key = keyInfo
        } else {
          // Key for subsequent segments
          globalKey = keyInfo
        }
      } else if (line.startsWith('#EXTINF:')) {
        currentTsInfo = new M3U8TsInfo()
        currentTsInfo.duration = M3U8Tools.subStringFrom(line + ',', '#EXTINF:', ',').trim()
        currentTsInfo.index = index++
        if (globalKey) {
          currentTsInfo.key = globalKey
        }
      } else if (line.startsWith('#EXT-X-DISCONTINUITY')) {
        if (currentTsInfo) {
          currentTsInfo.hasDiscontinuity = true
        }
      } else if (!line.startsWith('#')) {
        // This is a TS URL
        if (currentTsInfo) {
          currentTsInfo.oriUrlString = M3U8Tools.resolveUrl(oriUrlString, line)
          currentTsInfo.localUrlString = `${M3U8Setting.localHost(port)}/${M3U8Setting.uuidWithUrl(oriUrlString)}/${M3U8Setting.tsFileWithIdentify(currentTsInfo.index!.toString())}`
          tsInfos.push(currentTsInfo)
          currentTsInfo = null
        }
      }
    }

    info.tsInfos = tsInfos
    LogBus.instance.info(TAG, 'parse m3u8 success, ts count: ' + tsInfos.length)
    completionHandler(info)
  }

  static synthesisHttpM3U8(m3u8Info: M3U8Info, port: number = 8080): string {
    let header = '#EXTM3U\n'
    if (m3u8Info.version) {
      header += `#EXT-X-VERSION:${m3u8Info.version}\n`
    }
    if (m3u8Info.targetDuration) {
      header += `#EXT-X-TARGETDURATION:${m3u8Info.targetDuration}\n`
    }
    if (m3u8Info.mediaSequence) {
      header += `#EXT-X-MEDIA-SEQUENCE:${m3u8Info.mediaSequence}\n`
    }

    let body = ''
    m3u8Info.tsInfos?.forEach((value) => {
      let keyStr = ''
      if (value.key?.keyUri && value.key?.keyLocalUri) {
        keyStr = `#EXT-X-KEY:METHOD=${value.key.keyMethod},URI="${value.key.keyLocalUri}",IV=${value.key.keyIv}\n`
      }
      body += keyStr + `#EXTINF:${value.duration},\n${value.localUrlString}\n`
      if (value.hasDiscontinuity) {
        body += '#EXT-X-DISCONTINUITY\n'
      }
    })

    return header + body + '#EXT-X-ENDLIST'
  }

  static synthesisLocalM3U8WithM3U8Info(path: string, m3u8Info: M3U8Info, url: string, port: number = 8080): string {

    let header = '#EXTM3U\n'

    if (m3u8Info.version) {
      header += `#EXT-X-VERSION:${m3u8Info.version}\n`
    }
    if (m3u8Info.targetDuration) {
      header += `#EXT-X-TARGETDURATION:${m3u8Info.targetDuration}\n`
    }
    if (m3u8Info.mediaSequence) {
      header += `#EXT-X-MEDIA-SEQUENCE:${m3u8Info.mediaSequence}\n`
    }

    let body = ''
    m3u8Info.tsInfos?.forEach((value) => {
      let keyStr = ''
      if (value.key?.keyUri) {
        keyStr = `#EXT-X-KEY:METHOD=${value.key.keyMethod},URI="${M3U8Tools.pkKeyUriM3U8FilePath(path, url, value.key.keyUri)}",IV=${value.key.keyIv}\n`
      }
      body += keyStr + `#EXTINF:${value.duration},\n${M3U8Tools.pkm3u8FilePath(path, url, value.index ?? 0)}\n`
      if (value.hasDiscontinuity) {
        body += '#EXT-X-DISCONTINUITY\n'
      }
    })

    return header + body + '#EXT-X-ENDLIST'
  }
}
