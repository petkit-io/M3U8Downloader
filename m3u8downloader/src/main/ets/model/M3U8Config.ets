
import { M3U8Logger } from '../logger/M3U8Logger'

export interface M3U8ManagerConfig {
  context: Context
  saveFilePath: string
  defaultHeaders?: Record<string, string>
  /** Local HTTP server port. Default: 8080 */
  port?: number
  /** Concurrent TS segment download count. Valid range: 1–5. Default: 3. Out-of-range values fall back to 3. */
  concurrency?: number
  logger?: M3U8Logger
}
