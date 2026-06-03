import { fileIo } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { LogBus } from '../logger/LogBus'

export declare type M3U8FileManageCompleteHandler = (error?: BusinessError) => void

export class M3U8FileManager {

  static instance = new M3U8FileManager()

  async saveData(aData: string | ArrayBuffer, file: string, completeHandler: M3U8FileManageCompleteHandler) {
    let saveError: BusinessError | undefined
    try {
      const fileObj = await fileIo.open(file, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      await fileIo.write(fileObj.fd, aData)
      await fileIo.close(fileObj)
    } catch (err) {
      saveError = err as BusinessError
      LogBus.instance.error('M3U8FileManager', 'file operation failed: ' + JSON.stringify(err))
    } finally {
      completeHandler?.(saveError)
    }
  }

  removeFileWithPath(path: string) {
    try {
      fileIo.rmdirSync(path)
    } catch (error) {
      const err = error as BusinessError
      if (err?.code !== 13900002) {
        LogBus.instance.error('M3U8FileManager', `delete failed: ${err.message} ${path}`)
      }
    }
  }
}
