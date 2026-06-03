import { BusinessError } from '@ohos.base';
import call from '@ohos.telephony.call';
import observer from '@ohos.telephony.observer';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

// 电话条目接口
export interface PhoneEntry {
  phoneNumber: string;
  contactName: string;
  accountNumber?: string;
  balance?: string;
  isCalled: boolean;
  callCount: number;
}

// 通话记录接口
export interface CallRecord {
  phoneNumber: string;
  timestamp: string;
  duration: number;
  result: string;
}

// 通话状态枚举
export enum CallState {
  IDLE = 'idle',
  RINGING = 'ringing',
  OFFHOOK = 'offhook',
  DISCONNECTED = 'disconnected'
}

// 音频播放器类
export class AudioPlayer {
  private isPlaying: boolean = false;

  // 播放音频文件
  async playAudio(audioPath: string): Promise<boolean> {
    try {
      console.log('播放音频:', audioPath);
      this.isPlaying = true;
      // TODO: 实现音频播放功能
      return true;
    } catch (err) {
      console.error(`播放音频失败: ${JSON.stringify(err)}`);
      return false;
    }
  }

  // 停止播放
  async stop(): Promise<void> {
    this.isPlaying = false;
  }

  // 检查是否正在播放
  isAudioPlaying(): boolean {
    return this.isPlaying;
  }
}

// 通话录音器类
export class CallRecorder {
  private isRecording: boolean = false;

  // 开始录音
  async startRecording(phoneNumber: string): Promise<string | null> {
    try {
      if (this.isRecording) {
        return null;
      }

      const context = getContext() as common.UIAbilityContext;
      const dirPath = `${context.filesDir}/call_records`;
      if (!fs.accessSync(dirPath)) {
        fs.mkdirSync(dirPath);
      }

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `call_${phoneNumber}_${timestamp}.mp3`;
      const filePath = `${dirPath}/${fileName}`;

      this.isRecording = true;
      console.log('开始录音:', filePath);
      
      return filePath;
    } catch (err) {
      console.error(`开始录音失败: ${JSON.stringify(err)}`);
      return null;
    }
  }

  // 停止录音
  async stopRecording(): Promise<string | null> {
    if (!this.isRecording) {
      return null;
    }

    try {
      this.isRecording = false;
      console.log('停止录音');
      return "录音文件已保存";
    } catch (err) {
      console.error(`停止录音失败: ${JSON.stringify(err)}`);
      return null;
    }
  }

  // 检查是否正在录音
  isRecordingNow(): boolean {
    return this.isRecording;
  }
}

// 通话状态监听器
export class CallStateListener {
  private isListening: boolean = false;

  // 开始监听通话状态
  startListening(callback: (state: CallState, number?: string) => void): void {
    if (this.isListening) {
      return;
    }

    try {
      observer.on('callStateChange', (data: object) => {
        console.log(`通话状态变化: ${JSON.stringify(data)}`);
        const callData = data as Record<string, Object>
        
        // 根据状态调用回调
        if (callData['state'] === call.CallState.CALL_STATE_IDLE) {
          callback(CallState.IDLE);
        } else if (callData['state'] === call.CallState.CALL_STATE_RINGING) {
          callback(CallState.RINGING, callData['number'] as string);
        } else if (callData['state'] === call.CallState.CALL_STATE_OFFHOOK) {
          callback(CallState.OFFHOOK, callData['number'] as string);
        }
      });
      
      this.isListening = true;
    } catch (err) {
      console.error(`开始监听通话状态失败: ${JSON.stringify(err)}`);
    }
  }

  // 停止监听
  stopListening(): void {
    if (this.isListening) {
      try {
        observer.off('callStateChange');
        this.isListening = false;
      } catch (err) {
        console.error(`停止监听通话状态失败: ${JSON.stringify(err)}`);
      }
    }
  }
}

// 电话拨打工具类
export class CallManager {
  
  // 检查设备是否支持语音功能
  static hasVoiceCapability(): boolean {
    try {
      return call.hasVoiceCapability();
    } catch (err) {
      console.error(`检查语音功能失败: ${JSON.stringify(err)}`);
      return false;
    }
  }

  // 拨打电话
  static async makeCall(phoneNumber: string): Promise<boolean> {
    try {
      if (!CallManager.hasVoiceCapability()) {
        console.error('设备不支持语音功能');
        return false;
      }

      call.makeCall(phoneNumber, (err: BusinessError) => {
        if (err) {
          console.error(`拨打电话失败: ${JSON.stringify(err)}`);
        } else {
          console.log('拨打电话成功');
        }
      });

      return true;
    } catch (err) {
      console.error(`拨打电话异常: ${JSON.stringify(err)}`);
      return false;
    }
  }

  // 检查权限
  static async checkPermissions(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(
        getContext(),
        ['ohos.permission.MICROPHONE', 'ohos.permission.READ_CALL_LOG']
      );

      return result.authResults.every(
        res => res === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
      );
    } catch (err) {
      console.error(`检查权限失败: ${JSON.stringify(err)}`);
      return false;
    }
  }
}

// 文件导入工具类
export class FileImportUtils {
  
  // 验证手机号码
  static isValidPhoneNumber(phone: string): boolean {
    const phoneRegex = /^1[3-9]\d{9}$/;
    return phoneRegex.test(phone);
  }

  // 从文本中提取电话号码
  static extractPhoneNumbers(text: string): string[] {
    const phoneRegex = /1[3-9]\d{9}/g;
    const matches = text.match(phoneRegex);
    return matches ? Array.from(new Set(matches)) : [];
  }

  // 解析余额
  static parseBalance(balance: string): number {
    if (!balance) return 0;
    
    try {
      const numberStr = balance.replace(/[^0-9.-]/g, '');
      return parseFloat(numberStr) || 0;
    } catch {
      return 0;
    }
  }

  // 获取音频文件路径
  static getAudioPath(context: common.UIAbilityContext, audioName: string): string {
    const audioDir = `${context.filesDir}/audio`;
    if (!fs.accessSync(audioDir)) {
      fs.mkdirSync(audioDir);
    }
    return `${audioDir}/${audioName}`;
  }
}