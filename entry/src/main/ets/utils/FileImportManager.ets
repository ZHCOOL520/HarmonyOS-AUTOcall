import { PhoneEntry, FileImportUtils } from './AutoCallUtils'
import common from '@ohos.app.ability.common'
import fs from '@ohos.file.fs'
import { BusinessError } from '@ohos.base'

// 文件导入管理器
export class FileImportManager {
  
  // 从CSV文件导入电话列表
  static async importFromCSV(context: common.UIAbilityContext, filePath: string): Promise<PhoneEntry[]> {
    try {
      if (!fs.accessSync(filePath)) {
        throw new Error('CSV文件不存在')
      }

      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY)
      const buffer = new ArrayBuffer(1024 * 1024) // 1MB buffer
      const readLen = fs.readSync(file.fd, buffer)
      fs.closeSync(file)

      const decoder = new util.TextDecoder('utf-8')
      const content = decoder.decodeWithStream(new Uint8Array(buffer.slice(0, readLen)))

      return this.parseCSVContent(content)
    } catch (err) {
      console.error(`导入CSV失败: ${JSON.stringify(err)}`)
      throw err
    }
  }

  // 解析CSV内容
  private static parseCSVContent(content: string): PhoneEntry[] {
    const phoneList: PhoneEntry[] = []
    const lines = content.split('\n').filter(line => line.trim())
    
    if (lines.length === 0) {
      return phoneList
    }

    // 解析标题行，确定列索引
    const headers = lines[0].split(',').map(h => h.trim().toLowerCase())
    const phoneCol = this.findColumnIndex(headers, ['phone', '手机', '手机号', '电话', '电话号码'])
    const nameCol = this.findColumnIndex(headers, ['name', '姓名', '联系人', '名字'])
    const accountCol = this.findColumnIndex(headers, ['account', '户号', '账号', '账户'])
    const balanceCol = this.findColumnIndex(headers, ['balance', '余额', '金额', '余额(元)'])

    // 从第二行开始解析数据
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i]
      const values = this.parseCSVLine(line)
      
      if (values.length > phoneCol && values[phoneCol]) {
        const phone = values[phoneCol].trim()
        if (FileImportUtils.isValidPhoneNumber(phone)) {
          const entry: PhoneEntry = {
            phoneNumber: phone,
            contactName: nameCol >= 0 && values[nameCol] ? values[nameCol].trim() : '',
            accountNumber: accountCol >= 0 && values[accountCol] ? values[accountCol].trim() : undefined,
            balance: balanceCol >= 0 && values[balanceCol] ? values[balanceCol].trim() : undefined,
            isCalled: false,
            callCount: 0
          }
          phoneList.push(entry)
        }
      }
    }

    return phoneList
  }

  // 解析CSV行（处理逗号在引号内的情况）
  private static parseCSVLine(line: string): string[] {
    const result: string[] = []
    let current = ''
    let inQuotes = false

    for (let i = 0; i < line.length; i++) {
      const char = line[i]
      
      if (char === '"') {
        inQuotes = !inQuotes
      } else if (char === ',' && !inQuotes) {
        result.push(current.trim())
        current = ''
      } else {
        current += char
      }
    }
    
    result.push(current.trim())
    return result
  }

  // 查找列索引
  private static findColumnIndex(headers: string[], keywords: string[]): number {
    for (let i = 0; i < headers.length; i++) {
      const header = headers[i]
      if (keywords.some(keyword => header.includes(keyword))) {
        return i
      }
    }
    return -1
  }

  // 从文本导入（剪贴板等）
  static importFromText(text: string): PhoneEntry[] {
    const phoneList: PhoneEntry[] = []
    const lines = text.split('\n').filter(line => line.trim())
    
    for (const line of lines) {
      const phoneNumbers = FileImportUtils.extractPhoneNumbers(line)
      for (const phone of phoneNumbers) {
        if (FileImportUtils.isValidPhoneNumber(phone)) {
          // 检查是否已存在
          if (!phoneList.some(entry => entry.phoneNumber === phone)) {
            phoneList.push({
              phoneNumber: phone,
              contactName: '',
              isCalled: false,
              callCount: 0
            })
          }
        }
      }
    }

    return phoneList
  }

  // 导出通话记录到CSV
  static async exportCallRecords(context: common.UIAbilityContext, phoneList: PhoneEntry[]): Promise<string> {
    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
      const fileName = `call_records_${timestamp}.csv`
      const filePath = `${context.filesDir}/${fileName}`

      // 创建CSV内容
      let csvContent = '电话号码,联系人姓名,户号,余额,拨打状态,拨打次数\n'
      
      for (const entry of phoneList) {
        const line = [
          `"${entry.phoneNumber}"`,
          `"${entry.contactName || ''}"`,
          `"${entry.accountNumber || ''}"`,
          `"${entry.balance || ''}"`,
          entry.isCalled ? '已拨打' : '未拨打',
          entry.callCount.toString()
        ].join(',')
        csvContent += line + '\n'
      }

      // 写入文件
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      const encoder = new util.TextEncoder()
      const content = encoder.encodeInto(csvContent)
      fs.writeSync(file.fd, content.buffer)
      fs.closeSync(file)

      return filePath
    } catch (err) {
      console.error(`导出通话记录失败: ${JSON.stringify(err)}`)
      throw err
    }
  }

  // 检查文件类型
  static getFileType(fileName: string): string {
    const ext = fileName.toLowerCase().split('.').pop()
    switch (ext) {
      case 'csv':
        return 'csv'
      case 'xlsx':
      case 'xls':
        return 'excel'
      case 'txt':
        return 'text'
      default:
        return 'unknown'
    }
  }

  // 复制示例音频文件
  static async copySampleAudios(context: common.UIAbilityContext): Promise<void> {
    try {
      const audioDir = `${context.filesDir}/audio`
      if (!fs.accessSync(audioDir)) {
        fs.mkdirSync(audioDir)
      }

      // 这里可以添加复制示例音频文件的逻辑
      // 由于鸿蒙系统资源管理限制，需要用户自行提供音频文件
      console.log('音频目录已创建，请手动添加音频文件')
    } catch (err) {
      console.error(`复制示例音频失败: ${JSON.stringify(err)}`)
    }
  }

  // 获取音频文件列表
  static getAudioFiles(context: common.UIAbilityContext): string[] {
    try {
      const audioDir = `${context.filesDir}/audio`
      if (!fs.accessSync(audioDir)) {
        return []
      }

      const dir = fs.opendirSync(audioDir)
      const files: string[] = []
      let entry = dir.readSync()
      
      while (entry) {
        if (entry.isFile() && this.isAudioFile(entry.name)) {
          files.push(entry.name)
        }
        entry = dir.readSync()
      }
      
      dir.closeSync()
      return files
    } catch (err) {
      console.error(`获取音频文件列表失败: ${JSON.stringify(err)}`)
      return []
    }
  }

  // 检查是否为音频文件
  private static isAudioFile(fileName: string): boolean {
    const audioExtensions = ['wav', 'mp3', 'aac', 'm4a', 'ogg']
    const ext = fileName.toLowerCase().split('.').pop()
    return audioExtensions.includes(ext || '')
  }

  // 删除音频文件
  static deleteAudioFile(context: common.UIAbilityContext, fileName: string): boolean {
    try {
      const filePath = `${context.filesDir}/audio/${fileName}`
      if (fs.accessSync(filePath)) {
        fs.unlink(filePath)
        return true
      }
      return false
    } catch (err) {
      console.error(`删除音频文件失败: ${JSON.stringify(err)}`)
      return false
    }
  }
}