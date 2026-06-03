
export class M3U8Info {
  targetDuration?: string
  version?: string
  mediaSequence?: string

  keyMethod?: string
  keyUrl?: string
  keyLocalUri?: string
  keyIv?: string
  fileUrl?: string
  tsInfos?: M3U8TsInfo[]
}

export class M3U8TsInfo {
  duration?: string
  oriUrlString?: string
  localUrlString?: string
  index?: number
  hasDiscontinuity?: boolean
  completed?: number
  key?: M3U8KeyInfo
}

export class M3U8KeyInfo {
  keyMethod?: string
  keyUri?: string
  keyLocalUri?: string
  keyIv?: string
}
