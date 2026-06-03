import { M3U8Logger } from './M3U8Logger'

class DefaultLogger implements M3U8Logger {
  debug(tag: string, msg: string): void {
    console.debug(`[${tag}] ${msg}`)
  }
  info(tag: string, msg: string): void {
    console.info(`[${tag}] ${msg}`)
  }
  warn(tag: string, msg: string): void {
    console.warn(`[${tag}] ${msg}`)
  }
  error(tag: string, msg: string): void {
    console.error(`[${tag}] ${msg}`)
  }
}

export class LogBus {

  private static _instance = new LogBus()

  static get instance(): LogBus {
    return LogBus._instance
  }

  private constructor() {}

  private logger: M3U8Logger = new DefaultLogger()

  setLogger(logger: M3U8Logger): void {
    this.logger = logger
  }

  debug(tag: string, msg: string): void {
    this.logger.debug(tag, msg)
  }

  info(tag: string, msg: string): void {
    this.logger.info(tag, msg)
  }

  warn(tag: string, msg: string): void {
    this.logger.warn(tag, msg)
  }

  error(tag: string, msg: string): void {
    this.logger.error(tag, msg)
  }
}
