import { PhoneEntry, CallManager, AudioPlayer, CallRecorder, CallStateListener, CallState, FileImportUtils } from '../utils/AutoCallUtils'
import common from '@ohos.app.ability.common'
import fs from '@ohos.file.fs'
import { BusinessError } from '@ohos.base'
import abilityAccessCtrl from '@ohos.abilityAccessCtrl'
import util from '@ohos.util'
import dataPreferences from '@ohos.data.preferences'

@Entry
@Component
struct Index {
  @State phoneList: PhoneEntry[] = []
  @State currentStatus: string = '准备就绪'
  @State isRunning: boolean = false
  @State isPaused: boolean = false
  @State progress: number = 0
  @State statistics: string = ''
  @State sortByBalance: number = 0 // 0: 不排序, 1: 从小到大, 2: 从大到小
  @State sortByCallCount: number = 0 // 0: 不排序, 1: 从小到大, 2: 从大到小
  @State showDisclaimer: boolean = true
  @State showAboutDialog: boolean = false
  @State showSettings: boolean = false
  @State isRecordingEnabled: boolean = false
  @State isAudioPlaybackEnabled: boolean = false
  @State selectedAudioIndex: number = 0
  @State simCardMode: number = 0 // 0: 默认卡, 1: SIM1, 2: SIM2, 3: 双卡交替
  @State callInterval: number = 3000
  @State currentIndex: number = 0

  private context = getContext(this) as common.UIAbilityContext
  private audioPlayer: AudioPlayer = new AudioPlayer()
  private callRecorder: CallRecorder = new CallRecorder()
  private callStateListener: CallStateListener = new CallStateListener()
  private sampleAudios: string[] = ['yu_peng_buzu.wav', 'ding.wav', 'no.wav']
  private userAudios: string[] = []

  aboutToAppear() {
    this.checkDisclaimer()
    this.loadPhoneList()
    this.setupCallListener()
    this.checkPermissions()
  }

  aboutToDisappear() {
    this.callStateListener.stopListening()
  }

  setupCallListener() {
    this.callStateListener.startListening((state: CallState, number?: string) => {
      switch (state) {
        case CallState.OFFHOOK:
          this.onCallConnected()
          break
        case CallState.DISCONNECTED:
          this.onCallDisconnected()
          break
        case CallState.RINGING:
          console.log(`来电: ${number}`)
          break
      }
    })
  }

  async checkPermissions() {
    const hasPermissions = await CallManager.checkPermissions()
    if (!hasPermissions) {
      this.currentStatus = '请授予必要的权限以使用完整功能'
    }
  }

  checkDisclaimer() {
    try {
      const options: dataPreferences.Options = { name: 'app_prefs' }
      dataPreferences.getPreferences(this.context, options, (err, prefs) => {
        if (!err && prefs) {
          const accepted: boolean = prefs.getSync('disclaimer_accepted', false) as boolean
          this.showDisclaimer = !accepted
        }
      })
    } catch (err) {
      console.error('检查免责声明失败:', JSON.stringify(err))
    }
  }

  acceptDisclaimer() {
    try {
      const options: dataPreferences.Options = { name: 'app_prefs' }
      dataPreferences.getPreferences(this.context, options, (err, prefs) => {
        if (!err && prefs) {
          prefs.putSync('disclaimer_accepted', true)
          prefs.flush()
          this.showDisclaimer = false
        }
      })
    } catch (err) {
      console.error('接受免责声明失败:', JSON.stringify(err))
    }
  }

  declineDisclaimer() {
    this.currentStatus = '已拒绝协议，请重新打开应用'
  }

  loadPhoneList() {
    try {
      const filePath = `${this.context.filesDir}/phone_list.json`
      if (fs.accessSync(filePath)) {
        const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY)
        const stat = fs.statSync(filePath)
        const buffer = new ArrayBuffer(stat.size)
        const readLen = fs.readSync(file.fd, buffer)
        fs.closeSync(file)
        
        let decoder = new util.TextDecoder()
        let uint8Array = new Uint8Array(buffer)
        let content = decoder.decodeWithStream(uint8Array, { stream: false })
        this.phoneList = JSON.parse(content) as PhoneEntry[]
      }
    } catch (err) {
      console.error('加载电话列表失败:', JSON.stringify(err))
    }
  }

  savePhoneList() {
    try {
      const filePath = `${this.context.filesDir}/phone_list.json`
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      
      let encoder = new util.TextEncoder()
      let encodeResult = encoder.encodeInto(JSON.stringify(this.phoneList))
      fs.writeSync(file.fd, encodeResult.buffer)
      fs.closeSync(file)
    } catch (err) {
      console.error('保存电话列表失败:', JSON.stringify(err))
    }
  }

  async startAutoCall() {
    if (this.phoneList.length === 0) {
      this.currentStatus = '没有可拨打的电话'
      return
    }
    
    if (!CallManager.hasVoiceCapability()) {
      this.currentStatus = '设备不支持语音功能'
      return
    }
    
    this.isRunning = true
    this.isPaused = false
    this.progress = 0
    this.currentStatus = '开始自动拨打...'
    
    this.makeNextCall()
  }

  async makeNextCall() {
    if (!this.isRunning || this.isPaused) return
    
    const nextIndex = this.phoneList.findIndex(entry => !entry.isCalled)
    if (nextIndex === -1) {
      this.currentStatus = '所有电话已拨打完成'
      this.isRunning = false
      this.updateStatistics()
      return
    }
    
    const entry = this.phoneList[nextIndex]
    this.currentIndex = nextIndex
    this.currentStatus = `正在拨打: ${entry.contactName || entry.phoneNumber}`
    this.progress = nextIndex + 1
    
    try {
      // 发起呼叫
      const success = await CallManager.makeCall(entry.phoneNumber)
      
      if (success) {
        // 等待通话结束（这里需要根据实际通话状态来调整）
        await this.sleep(10000) // 等待10秒模拟通话
        
        // 更新状态
        entry.isCalled = true
        entry.callCount++
        this.savePhoneList()
        
        // 等待指定间隔
        await this.sleep(this.callInterval)
        
        // 继续下一个
        if (this.isRunning && !this.isPaused) {
          this.makeNextCall()
        }
      } else {
        this.currentStatus = `拨打失败: ${entry.phoneNumber}`
      }
    } catch (err) {
      console.error('拨打电话失败:', err)
      this.currentStatus = `拨打失败: ${entry.phoneNumber}`
    }
  }

  onCallConnected() {
    if (this.isAudioPlaybackEnabled) {
      this.playAudioToCall()
    }
    
    if (this.isRecordingEnabled) {
      const currentEntry = this.phoneList[this.currentIndex]
      if (currentEntry) {
        this.callRecorder.startRecording(currentEntry.phoneNumber)
      }
    }
  }

  onCallDisconnected() {
    if (this.isAudioPlaybackEnabled) {
      this.audioPlayer.stop()
    }
    
    if (this.isRecordingEnabled) {
      this.callRecorder.stopRecording()
    }
  }

  async playAudioToCall() {
    try {
      const audioName = this.getCurrentAudioName()
      if (audioName) {
        const audioPath = FileImportUtils.getAudioPath(this.context, audioName)
        await this.audioPlayer.playAudio(audioPath)
      }
    } catch (err) {
      console.error('播放音频失败:', err)
    }
  }

  pauseAutoCall() {
    this.isPaused = true
    this.currentStatus = '已暂停'
  }

  resumeAutoCall() {
    this.isPaused = false
    this.currentStatus = '继续拨打...'
    this.makeNextCall()
  }

  stopAutoCall() {
    this.isRunning = false
    this.isPaused = false
    this.currentStatus = '已停止'
    this.updateStatistics()
  }

  updateStatistics() {
    const total = this.phoneList.length
    const called = this.phoneList.filter(e => e.isCalled).length
    const success = called
    const rate = total > 0 ? ((success / total) * 100).toFixed(1) : '0.0'
    
    this.statistics = `总计: ${total} | 已拨打: ${called} | 成功率: ${rate}%`
  }

  toggleSortByCallCount() {
    this.sortByCallCount = (this.sortByCallCount + 1) % 3
    
    if (this.sortByCallCount === 1) {
      this.phoneList.sort((a, b) => a.callCount - b.callCount)
    } else if (this.sortByCallCount === 2) {
      this.phoneList.sort((a, b) => b.callCount - a.callCount)
    }
  }

  toggleSortByBalance() {
    this.sortByBalance = (this.sortByBalance + 1) % 3
    
    if (this.sortByBalance === 1) {
      this.phoneList.sort((a, b) => {
        const balA = FileImportUtils.parseBalance(a.balance || '0')
        const balB = FileImportUtils.parseBalance(b.balance || '0')
        return balA - balB
      })
    } else if (this.sortByBalance === 2) {
      this.phoneList.sort((a, b) => {
        const balA = FileImportUtils.parseBalance(a.balance || '0')
        const balB = FileImportUtils.parseBalance(b.balance || '0')
        return balB - balA
      })
    }
  }

  clearPhoneList() {
    this.phoneList = []
    this.savePhoneList()
    this.currentStatus = '列表已清空'
  }

  importFromClipboard() {
    try {
      // TODO: HarmonyOS剪贴板功能需要单独实现
      this.currentStatus = '剪贴板导入功能待实现'
    } catch (err) {
      console.error('从剪贴板导入失败:', JSON.stringify(err))
      this.currentStatus = '导入失败'
    }
  }

  parseAndImport(text: string) {
    const lines = text.split('\n')
    let count = 0
    
    for (const line of lines) {
      const trimmed = line.trim()
      if (trimmed && FileImportUtils.isValidPhoneNumber(trimmed)) {
        const exists = this.phoneList.some(e => e.phoneNumber === trimmed)
        if (!exists) {
          this.phoneList.push({
            phoneNumber: trimmed,
            contactName: '',
            isCalled: false,
            callCount: 0
          })
          count++
        }
      }
    }
    
    this.savePhoneList()
    this.currentStatus = `成功导入 ${count} 个号码`
  }

  getAllAudios(): string[] {
    return this.sampleAudios.concat(this.userAudios)
  }

  getCurrentAudioName(): string {
    const all = this.getAllAudios()
    const idx = this.selectedAudioIndex
    return idx < all.length ? all[idx] : all[0] || ''
  }

  selectAudio(index: number) {
    const all = this.getAllAudios()
    if (index < all.length) {
      this.selectedAudioIndex = index
    }
  }

  toggleRecording() {
    this.isRecordingEnabled = !this.isRecordingEnabled
    this.currentStatus = this.isRecordingEnabled ? '录音已开启' : '录音已关闭'
  }

  toggleAudioPlayback() {
    this.isAudioPlaybackEnabled = !this.isAudioPlaybackEnabled
    this.currentStatus = this.isAudioPlaybackEnabled ? '音频播放已开启' : '音频播放已关闭'
  }

  setSimCardMode(mode: number) {
    if (mode >= 0 && mode <= 3) {
      this.simCardMode = mode
      const modeText = this.getSimCardModeText()
      this.currentStatus = `已设置为${modeText}`
    }
  }

  getSimCardModeText(): string {
    switch (this.simCardMode) {
      case 0: return '默认卡'
      case 1: return 'SIM卡1'
      case 2: return 'SIM卡2'
      case 3: return '双卡交替'
      default: return '默认卡'
    }
  }

  setCallInterval(seconds: number) {
    if (seconds >= 1 && seconds <= 10) {
      this.callInterval = seconds * 1000
    }
  }

  sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  build() {
    Column() {
      if (this.showDisclaimer) {
        this.DisclaimerDialog()
      } else if (this.showSettings) {
        this.SettingsView()
      } else {
        this.MainView()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  MainView() {
    Column() {
      // 顶部栏
      Row() {
        Text('自动电话拨打系统')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .onClick(() => {
            this.showAboutDialog = true
          })
        
        Blank()
        
        Button('设置')
          .onClick(() => {
            this.showSettings = true
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#1976D2')
      
      Scroll() {
        Column() {
          // 状态卡片
          this.StatusCard()
          
          // 控制按钮
          this.ControlButtons()
          
          // 电话列表标题
          Text(`电话列表 (${this.phoneList.length}个)`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 16 })
          
          // 排序按钮
          this.SortButtons()
          
          // 电话列表
          this.PhoneListView()
          
          // 统计信息
          if (this.statistics) {
            this.StatisticsCard()
          }
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  StatusCard() {
    Column() {
      Text('当前状态')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
      
      Text(this.currentStatus)
        .fontSize(16)
        .margin({ top: 8 })
      
      if (this.phoneList.length > 0) {
        Progress({ value: this.progress, total: this.phoneList.length, type: ProgressType.Linear })
          .width('100%')
          .margin({ top: 8 })
        
        Text(`进度: ${this.progress} / ${this.phoneList.length}`)
          .fontSize(12)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#E3F2FD')
    .borderRadius(8)
  }

  @Builder
  ControlButtons() {
    Column() {
      Row() {
        Button('导入文件')
          .enabled(!this.isRunning)
          .layoutWeight(1)
          .margin({ right: 4 })
        
        Button('导入剪贴板')
          .enabled(!this.isRunning)
          .layoutWeight(1)
          .margin({ left: 4 })
          .onClick(() => {
            this.importFromClipboard()
          })
      }
      .width('100%')
      .margin({ bottom: 8 })
      
      Row() {
        Button('开始拨打')
          .enabled(!this.isRunning)
          .layoutWeight(1)
          .margin({ right: 4 })
          .onClick(() => {
            this.startAutoCall()
          })
        
        if (this.isRunning && !this.isPaused) {
          Button('暂停')
            .layoutWeight(1)
            .margin({ left: 4, right: 4 })
            .backgroundColor('#FF9800')
            .onClick(() => {
              this.pauseAutoCall()
            })
        } else if (this.isRunning && this.isPaused) {
          Button('继续')
            .layoutWeight(1)
            .margin({ left: 4, right: 4 })
            .onClick(() => {
              this.resumeAutoCall()
            })
        }
        
        Button('停止')
          .enabled(this.isRunning)
          .layoutWeight(1)
          .margin({ left: 4 })
          .backgroundColor('#F44336')
          .onClick(() => {
            this.stopAutoCall()
          })
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  SortButtons() {
    Row() {
      Button(this.sortByCallCount === 0 ? '按拨打次数' : (this.sortByCallCount === 1 ? '✓ 次数升序' : '✓ 次数降序'))
        .fontSize(12)
        .layoutWeight(1)
        .margin({ right: 4 })
        .onClick(() => {
          this.toggleSortByCallCount()
        })
      
      if (this.phoneList.some(e => e.balance && e.balance.length > 0)) {
        Button(this.sortByBalance === 0 ? '按余额' : (this.sortByBalance === 1 ? '✓ 余额升序' : '✓ 余额降序'))
          .fontSize(12)
          .layoutWeight(1)
          .margin({ left: 4, right: 4 })
          .onClick(() => {
            this.toggleSortByBalance()
          })
      }
      
      if (this.phoneList.length > 0) {
        Button('🗑️ 清空')
          .fontSize(12)
          .layoutWeight(1)
          .margin({ left: 4 })
          .backgroundColor('#FFEBEE')
          .fontColor('#F44336')
          .onClick(() => {
            AlertDialog.show({
              title: '确认清空',
              message: '确定要清空所有联系人吗？此操作不可恢复。',
              primaryButton: {
                value: '取消',
                action: () => {}
              },
              secondaryButton: {
                value: '确认清空',
                action: () => {
                  this.clearPhoneList()
                }
              }
            })
          })
      }
    }
    .width('100%')
    .margin({ top: 8, bottom: 8 })
  }

  @Builder
  PhoneListView() {
    List() {
      ForEach(this.phoneList, (entry: PhoneEntry, index: number) => {
        ListItem() {
          this.PhoneItem(entry)
        }
      }, (entry: PhoneEntry) => entry.phoneNumber)
    }
    .width('100%')
    .height(this.phoneList.length > 0 ? 400 : 100)
    .backgroundColor('#F5F5F5')
    .borderRadius(8)
  }

  @Builder
  PhoneItem(entry: PhoneEntry) {
    Row() {
      Column() {
        Text(entry.contactName || '未知联系人')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(entry.isCalled ? '#999999' : '#000000')
        
        Text(entry.phoneNumber)
          .fontSize(16)
          .fontColor(entry.isCalled ? '#64B5F6' : '#1976D2')
          .margin({ top: 4 })
        
        Text(entry.isCalled ? `✓ 已拨打 (${entry.callCount}次)` : '○ 未拨打')
          .fontSize(12)
          .fontColor(entry.isCalled ? '#1976D2' : '#999999')
          .margin({ top: 4 })
        
        if (entry.accountNumber) {
          Text(`户号: ${entry.accountNumber}`)
            .fontSize(12)
            .fontColor('#666666')
            .margin({ top: 2 })
        }
        
        if (entry.balance) {
          Text(`余额: ${entry.balance}`)
            .fontSize(12)
            .fontColor(entry.isCalled ? '#64B5F6' : '#1976D2')
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(entry.isCalled ? '#FAFAFA' : '#FFFFFF')
    .borderRadius(4)
    .margin({ bottom: 8 })
    .onClick(() => {
      // 手动拨打
      CallManager.makeCall(entry.phoneNumber)
      entry.callCount++
      this.savePhoneList()
    })
  }

  @Builder
  StatisticsCard() {
    Column() {
      Text('通话统计')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
      
      Text(this.statistics)
        .fontSize(14)
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#E8F5E9')
    .borderRadius(8)
    .margin({ top: 16 })
  }

  @Builder
  SettingsView() {
    Column() {
      // 顶部栏
      Row() {
        Button('返回')
          .onClick(() => {
            this.showSettings = false
          })
        
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#1976D2')
      
      Scroll() {
        Column() {
          // 音频播放开关
          Row() {
            Column() {
              Text('音频播放')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
              
              Text(this.isAudioPlaybackEnabled ? '✅ 开启：通话时自动播放音频' : '❌ 关闭：不播放音频')
                .fontSize(12)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            
            Toggle({ type: ToggleType.Switch })
              .onChange((isOn: boolean) => {
                this.toggleAudioPlayback()
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.isAudioPlaybackEnabled ? '#E3F2FD' : '#F5F5F5')
          .borderRadius(8)
          
          // 通话录音开关
          Row() {
            Column() {
              Text('通话录音')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
              
              Text(this.isRecordingEnabled ? '✅ 开启：通话时自动录音' : '❌ 关闭：不录音')
                .fontSize(12)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            
            Toggle({ type: ToggleType.Switch })
              .onChange((isOn: boolean) => {
                this.toggleRecording()
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.isRecordingEnabled ? '#E3F2FD' : '#F5F5F5')
          .borderRadius(8)
          .margin({ top: 16 })
          
          // SIM卡选择
          this.SimCardSelector()
          
          // 拨打间隔设置
          this.CallIntervalSetting()
          
          // 音频选择
          this.AudioSelector()
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SimCardSelector() {
    Column() {
      Text('SIM卡选择')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      
      Text(`当前模式: ${this.getSimCardModeText()}`)
        .fontSize(12)
        .margin({ top: 4 })
      
      Row() {
        Button('默认卡')
          .fontSize(12)
          .layoutWeight(1)
          .margin({ right: 4 })
          .backgroundColor(this.simCardMode === 0 ? '#1976D2' : '#E0E0E0')
          .fontColor(this.simCardMode === 0 ? '#FFFFFF' : '#000000')
          .onClick(() => {
            this.setSimCardMode(0)
          })
        
        Button('SIM卡1')
          .fontSize(12)
          .layoutWeight(1)
          .margin({ left: 4, right: 4 })
          .backgroundColor(this.simCardMode === 1 ? '#1976D2' : '#E0E0E0')
          .fontColor(this.simCardMode === 1 ? '#FFFFFF' : '#000000')
          .onClick(() => {
            this.setSimCardMode(1)
          })
        
        Button('SIM卡2')
          .fontSize(12)
          .layoutWeight(1)
          .margin({ left: 4, right: 4 })
          .backgroundColor(this.simCardMode === 2 ? '#1976D2' : '#E0E0E0')
          .fontColor(this.simCardMode === 2 ? '#FFFFFF' : '#000000')
          .onClick(() => {
            this.setSimCardMode(2)
          })
        
        Button('双卡交替')
          .fontSize(12)
          .layoutWeight(1)
          .margin({ left: 4 })
          .backgroundColor(this.simCardMode === 3 ? '#1976D2' : '#E0E0E0')
          .fontColor(this.simCardMode === 3 ? '#FFFFFF' : '#000000')
          .onClick(() => {
            this.setSimCardMode(3)
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F5F5F5')
    .borderRadius(8)
    .margin({ top: 16 })
  }

  @Builder
  CallIntervalSetting() {
    Column() {
      Text('⏱️ 拨打间隔设置')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      
      Text(`当前间隔: ${this.callInterval / 1000}秒`)
        .fontSize(12)
        .fontColor('#1976D2')
        .margin({ top: 4 })
      
      Row() {
        ForEach([1, 2, 3, 5, 8], (seconds: number) => {
          Button(`${seconds}秒`)
            .fontSize(12)
            .layoutWeight(1)
            .margin(seconds === 1 ? { right: 4 } : (seconds === 8 ? { left: 4 } : { left: 4, right: 4 }))
            .backgroundColor(this.callInterval === seconds * 1000 ? '#1976D2' : '#E0E0E0')
            .fontColor(this.callInterval === seconds * 1000 ? '#FFFFFF' : '#000000')
            .onClick(() => {
              this.setCallInterval(seconds)
            })
        })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F5F5F5')
    .borderRadius(8)
    .margin({ top: 16 })
  }

  @Builder
  AudioSelector() {
    Column() {
      Text('🎵 音频选择')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
      
      Text(`当前音频: ${this.getCurrentAudioName()}`)
        .fontSize(12)
        .fontColor('#1976D2')
        .margin({ top: 4 })
      
      List() {
        ForEach(this.getAllAudios(), (audio: string, index: number) => {
          ListItem() {
            Row() {
              Text(audio)
                .fontSize(14)
                .layoutWeight(1)
              
              if (index === this.selectedAudioIndex) {
                Text('✓')
                  .fontSize(16)
                  .fontColor('#1976D2')
              }
            }
            .width('100%')
            .padding(12)
          }
          .onClick(() => {
            this.selectAudio(index)
          })
        })
      }
      .height(200)
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F5F5F5')
    .borderRadius(8)
    .margin({ top: 16 })
  }

  @Builder
  DisclaimerDialog() {
    Column() {
      Text('⚠️ 用户协议与隐私政策')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F44336')
        .margin({ bottom: 16 })
      
      Scroll() {
        Column() {
          Text('🔒 重要声明')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F44336')
          
          Text('• 本软件仅供学习研究使用，严禁用于任何非法用途')
            .fontSize(12)
            .margin({ top: 8 })
          
          Text('• 使用者需自行承担全部法律责任')
            .fontSize(12)
            .margin({ top: 4 })
          
          Text('• 开发者不对任何使用后果负责')
            .fontSize(12)
            .margin({ top: 4 })
          
          Text('• 请勿骚扰他人或进行恶意拨打')
            .fontSize(12)
            .margin({ top: 4 })
          
          Text('❗ 功能限制说明')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F44336')
            .margin({ top: 16 })
          
          Text('• 通话录音功能需要用户授权麦克风权限')
            .fontSize(12)
            .margin({ top: 8 })
          
          Text('• 音频播放功能在通话中可能受到系统限制')
            .fontSize(12)
            .margin({ top: 4 })
          
          Text('📋 权限使用说明')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F44336')
            .margin({ top: 16 })
          
          Text('• 麦克风权限：用于通话录音功能')
            .fontSize(12)
            .margin({ top: 8 })
          
          Text('• 通话记录权限：用于获取通话状态信息')
            .fontSize(12)
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(8)
      }
      .height(300)
      .margin({ bottom: 16 })
      
      Row() {
        Button('拒绝')
          .layoutWeight(1)
          .margin({ right: 8 })
          .backgroundColor('#F44336')
          .onClick(() => {
            this.declineDisclaimer()
          })
        
        Button('同意')
          .layoutWeight(1)
          .margin({ left: 8 })
          .backgroundColor('#4CAF50')
          .onClick(() => {
            this.acceptDisclaimer()
          })
      }
      .width('100%')
    }
    .width('90%')
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .align(Alignment.Center)
  }
}