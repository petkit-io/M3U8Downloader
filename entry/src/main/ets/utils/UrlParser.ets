export function extractParam(url: string, key: string): string {
  const qIdx = url.indexOf('?')
  if (qIdx === -1) {
    return ''
  }
  const query = url.substring(qIdx + 1)
  const pairs = query.split('&')
  for (let i = 0; i < pairs.length; i++) {
    const pair = pairs[i]
    const eqIdx = pair.indexOf('=')
    if (eqIdx === -1) {
      continue
    }
    const k = pair.substring(0, eqIdx)
    if (k === key) {
      return decodeURIComponent(pair.substring(eqIdx + 1))
    }
  }
  return ''
}

function formatHHmm(seconds: number): string {
  const d = new Date(seconds * 1000)
  const h = d.getUTCHours().toString().padStart(2, '0')
  const m = d.getUTCMinutes().toString().padStart(2, '0')
  return `${h}:${m}`
}

function formatHHmmss(seconds: number): string {
  const d = new Date(seconds * 1000)
  const h = d.getUTCHours().toString().padStart(2, '0')
  const m = d.getUTCMinutes().toString().padStart(2, '0')
  const s = d.getUTCSeconds().toString().padStart(2, '0')
  return `${h}:${m}:${s}`
}

export function parseLabel(url: string): string {
  const moduleType = extractParam(url, 'moduleType')
  const startTimeStr = extractParam(url, 'startTime')
  const endTimeStr = extractParam(url, 'endTime')

  if (!startTimeStr) {
    return url.length > 40 ? url.substring(0, 40) + '...' : url
  }

  const startTime = parseInt(startTimeStr, 10)

  if (moduleType === 'CLOUD_STORAGE' && endTimeStr) {
    const endTime = parseInt(endTimeStr, 10)
    const duration = endTime - startTime
    return `云存储  ${formatHHmm(startTime)} ~ ${formatHHmm(endTime)} (${duration}s)`
  }

  if (moduleType === 'EVENT_VIDEO') {
    return `[事件]  ${formatHHmmss(startTime)}`
  }

  return url.length > 40 ? url.substring(0, 40) + '...' : url
}
