import { socket } from '@kit.NetworkKit'
import { fileIo } from '@kit.CoreFileKit'
import { LogBus } from '../logger/LogBus'

const TAG = 'M3U8LocalServer'
const HOST = '127.0.0.1'

export class M3U8LocalServer {

  private static _instance = new M3U8LocalServer()

  static get instance(): M3U8LocalServer {
    return M3U8LocalServer._instance
  }

  private server: socket.TCPSocketServer | null = null
  private running: boolean = false
  private filesDir: string = ''

  start(filesDir: string, port: number = 8080, onReady?: (success: boolean) => void) {
    if (this.running) {
      onReady?.(true)
      return
    }
    this.filesDir = filesDir
    this.running = true

    this.server = socket.constructTCPSocketServerInstance()
    this.server.listen({ address: HOST, port: port, family: 1 })
      .then(() => {
        LogBus.instance.info(TAG, `listening on ${HOST}:${port}`)
        this.server!.on('connect', (client: socket.TCPSocketConnection) => {
          this.handleConnection(client)
        })
        onReady?.(true)
      })
      .catch((err: Error) => {
        LogBus.instance.error(TAG, 'listen failed: ' + err.message)
        this.running = false
        this.server = null
        onReady?.(false)
      })
  }

  stop() {
    if (!this.running) {
      return
    }
    this.running = false
    if (this.server) {
      try {
        this.server.close().catch(() => {})
      } catch (_e) {}
      this.server = null
    }
  }

  private handleConnection(client: socket.TCPSocketConnection) {
    client.on('message', (value: socket.SocketMessageInfo) => {
      const requestStr = this.arrayBufferToString(value.message as ArrayBuffer)
      const firstLine = requestStr.split('\r\n')[0]
      const parts = firstLine.split(' ')

      if (parts.length < 2 || parts[0] !== 'GET') {
        this.sendTextResponse(client, 400, 'Bad Request', 'text/plain', 'Bad Request')
        return
      }

      const rawPath = parts[1].split('?')[0]

      // Security: reject path traversal
      if (rawPath.includes('..')) {
        this.sendTextResponse(client, 400, 'Bad Request', 'text/plain', 'Bad Request')
        return
      }

      const segments = rawPath.split('/').filter((s: string) => s.length > 0)
      if (segments.length !== 2) {
        this.sendTextResponse(client, 404, 'Not Found', 'text/plain', 'Not Found')
        return
      }

      const md5 = segments[0]
      const filename = segments[1]
      const filePath = `${this.filesDir}/m3u8files/${md5}/${filename}`

      try {
        const stat = fileIo.statSync(filePath)
        const contentType = this.getContentType(filename)
        const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY)
        const buffer = new ArrayBuffer(stat.size)
        fileIo.readSync(file.fd, buffer)
        fileIo.closeSync(file)
        this.sendBinaryResponse(client, 200, 'OK', contentType, buffer)
      } catch (err) {
        LogBus.instance.error(TAG, `file not found: ${filePath}`)
        this.sendTextResponse(client, 404, 'Not Found', 'text/plain', 'Not Found')
      }
    })
  }

  private getContentType(filename: string): string {
    if (filename.endsWith('.m3u8')) {
      return 'application/vnd.apple.mpegurl'
    }
    if (filename.endsWith('.ts')) {
      return 'video/mp2t'
    }
    return 'application/octet-stream'
  }

  private sendTextResponse(
    client: socket.TCPSocketConnection,
    status: number,
    statusText: string,
    contentType: string,
    body: string
  ) {
    const bodyBytes = this.stringToArrayBuffer(body)
    const headers = `HTTP/1.1 ${status} ${statusText}\r\nContent-Type: ${contentType}\r\nContent-Length: ${bodyBytes.byteLength}\r\nConnection: close\r\n\r\n`
    const combined = this.concatBuffers(this.stringToArrayBuffer(headers), bodyBytes)
    client.send({ data: combined })
      .then(() => { client.close().catch(() => {}) })
      .catch(() => {})
  }

  private sendBinaryResponse(
    client: socket.TCPSocketConnection,
    status: number,
    statusText: string,
    contentType: string,
    body: ArrayBuffer
  ) {
    const headers = `HTTP/1.1 ${status} ${statusText}\r\nContent-Type: ${contentType}\r\nContent-Length: ${body.byteLength}\r\nConnection: close\r\n\r\n`
    const combined = this.concatBuffers(this.stringToArrayBuffer(headers), body)
    client.send({ data: combined })
      .then(() => { client.close().catch(() => {}) })
      .catch(() => {})
  }

  private arrayBufferToString(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer)
    const len = Math.min(bytes.length, 8192)
    let result = ''
    for (let i = 0; i < len; i++) {
      result += String.fromCharCode(bytes[i])
    }
    return result
  }

  private stringToArrayBuffer(str: string): ArrayBuffer {
    const buffer = new ArrayBuffer(str.length)
    const view = new Uint8Array(buffer)
    for (let i = 0; i < str.length; i++) {
      view[i] = str.charCodeAt(i) & 0xFF
    }
    return buffer
  }

  private concatBuffers(a: ArrayBuffer, b: ArrayBuffer): ArrayBuffer {
    const result = new ArrayBuffer(a.byteLength + b.byteLength)
    const view = new Uint8Array(result)
    view.set(new Uint8Array(a), 0)
    view.set(new Uint8Array(b), a.byteLength)
    return result
  }
}
