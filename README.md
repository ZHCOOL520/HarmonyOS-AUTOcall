# 自动电话拨打系统 - 鸿蒙版
## MD由AI生成
## 项目概述

本项目是将Android版本的自动电话拨打系统转译为鸿蒙系统可用的版本。基于HarmonyOS的ArkTS语言和ArkUI框架开发，实现了与Android版本相同的核心功能。

## 功能特性

### ✅ 已实现功能
- **电话拨打**: 使用鸿蒙系统的`call.makeCall` API实现电话拨打
- **通话状态监听**: 通过`telephony.observer`监听通话状态变化
- **通话录音**: 使用`AVRecorder`实现通话录音功能
- **音频播放**: 使用`AVPlayer`实现在通话中播放音频
- **文件导入**: 支持从CSV文件导入电话列表
- **剪贴板导入**: 支持从剪贴板导入电话号码
- **通话统计**: 显示拨打进度和成功率统计
- **SIM卡选择**: 支持默认卡、SIM1、SIM2、双卡交替模式
- **拨打间隔设置**: 可设置1-10秒的拨打间隔
- **排序功能**: 支持按拨打次数和余额排序

### 🔄 转译差异说明

| 功能 | Android实现 | 鸿蒙实现 | 差异说明 |
|------|-------------|----------|----------|
| 电话拨打 | `Intent.ACTION_CALL` | `call.makeCall()` | 鸿蒙跳转到拨号界面，用户确认后拨打 |
| 通话录音 | `MediaRecorder` | `AVRecorder` | API不同但功能相同 |
| 音频播放 | `MediaPlayer` | `AVPlayer` | API不同但功能相同 |
| 权限管理 | Android权限系统 | HarmonyOS权限系统 | 权限申请流程不同 |
| 文件操作 | Java文件API | HarmonyOS文件API | 文件路径和操作方式不同 |

## 权限配置

### 必需权限
在`module.json5`中配置的权限：

```json5
{
  "name": "ohos.permission.MICROPHONE",
  "reason": "用于通话录音功能",
  "usedScene": {
    "abilities": ["EntryAbility"],
    "when": "inuse"
  }
},
{
  "name": "ohos.permission.READ_CALL_LOG", 
  "reason": "用于获取通话状态信息",
  "usedScene": {
    "abilities": ["EntryAbility"],
    "when": "inuse"
  }
}
```

### 隐式权限
- **电话拨打权限**: 通过`call.makeCall()`调用，系统自动处理
- **文件读写权限**: 应用沙箱内文件操作无需额外权限

## 项目结构

```
entry/src/main/ets/
├── entryability/           # 应用入口能力
│   └── EntryAbility.ets    # 应用主能力
├── pages/                  # 页面组件
│   └── Index.ets          # 主页面
└── utils/                  # 工具类
    ├── AutoCallUtils.ets   # 核心工具类（电话、音频、录音）
    └── FileImportManager.ets # 文件导入管理
```

## 核心类说明

### AutoCallUtils.ets
- **PhoneEntry**: 电话条目数据模型
- **CallManager**: 电话拨打管理
- **AudioPlayer**: 音频播放器
- **CallRecorder**: 通话录音器
- **CallStateListener**: 通话状态监听器
- **FileImportUtils**: 文件导入工具

### FileImportManager.ets
- **importFromCSV()**: CSV文件导入
- **importFromText()**: 文本导入
- **exportCallRecords()**: 导出通话记录
- **音频文件管理**: 音频文件的增删查

## 使用说明

### 1. 首次使用
- 应用启动时会显示用户协议
- 需要授予麦克风和通话记录权限
- 建议在设置中手动添加音频文件

### 2. 导入电话列表
- **CSV导入**: 支持标准CSV格式，自动识别电话号码、姓名、户号、余额等字段
- **剪贴板导入**: 从剪贴板文本中自动提取电话号码
- **文件格式要求**: 电话号码必须是11位有效手机号

### 3. 拨打设置
- **SIM卡选择**: 可选择默认卡、SIM1、SIM2或双卡交替
- **拨打间隔**: 设置1-10秒的拨打间隔时间
- **音频播放**: 开启后通话中自动播放选定音频
- **通话录音**: 开启后自动录制通话内容

### 4. 拨打流程
1. 点击"开始拨打"按钮
2. 系统跳转到拨号界面显示号码
3. 用户确认后开始拨打
4. 通话中根据设置播放音频/录音
5. 通话结束后等待间隔时间
6. 自动拨打下一个号码

## 技术限制

### 鸿蒙系统限制
1. **直接拨打限制**: 鸿蒙系统出于安全考虑，不允许应用直接拨打电话，必须跳转到拨号界面
2. **音频注入限制**: 通话中音频播放可能受到系统音频路由策略的限制
3. **通话录音限制**: 需要用户明确授权，且录音质量受系统策略影响

### 兼容性要求
- **HarmonyOS版本**: API 9及以上
- **设备类型**: 支持电话功能的手机设备
- **权限要求**: 用户必须授予相关权限

## 开发说明

### 编译构建
```bash
# 使用hvigor构建
hvigor assembleHap
```

### 调试运行
```bash
# 连接到设备调试
hdc shell
# 安装应用
hdc install entry-debug.hap
```

### 关键API使用

#### 电话拨打
```typescript
import call from '@ohos.telephony.call';

// 检查语音能力
if (call.hasVoiceCapability()) {
  // 跳转到拨号界面
  call.makeCall("13800138000", (err) => {
    if (err) {
      console.error(`拨打电话失败: ${JSON.stringify(err)}`);
    }
  });
}
```

#### 通话状态监听
```typescript
import observer from '@ohos.telephony.observer';

observer.on('callStateChange', (data) => {
  console.log(`通话状态: ${JSON.stringify(data)}`);
});
```

#### 音频录制
```typescript
import media from '@kit.MediaKit';

const avRecorder = await media.createAVRecorder();
const config = {
  audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
  // ... 其他配置
};
await avRecorder.prepare(config);
await avRecorder.start();
```

## 注意事项

### 法律合规
- 本软件仅供学习研究使用
- 严禁用于骚扰、诈骗等非法用途
- 使用者需自行承担法律责任

### 技术注意事项
- 首次使用需要用户手动授权权限
- 音频文件需要用户手动添加到应用目录
- 通话录音功能受系统策略限制
- 不同设备可能存在兼容性差异

## 版本信息

- **版本号**: 1.0.0
- **HarmonyOS API**: 9+
- **构建工具**: hvigor
- **开发语言**: ArkTS

## 支持与反馈

如遇到问题或有改进建议，请通过项目仓库提交Issue。