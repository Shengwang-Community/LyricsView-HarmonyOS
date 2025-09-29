# LyricsView HarmonyOS

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%209+-blue.svg)](https://developer.harmonyos.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-orange.svg)](releases/)

## 📑 目录

- [📖 简介](#-简介)
  - [🌟 核心特性](#-核心特性)
  - [🏗️ 架构设计](#️-架构设计)
- [🚀 跑通Examples](#-跑通examples)
  - [环境要求](#环境要求)
  - [1. 克隆项目](#1-克隆项目)
  - [2. 配置本地参数](#2-配置本地参数)
  - [3. 在DevEco Studio中运行](#3-在deveco-studio中运行)
- [📦 集成组件](#-集成组件)
  - [方式一：HAR包集成（推荐）](#方式一har包集成推荐)
  - [方式二：源码集成](#方式二源码集成)
- [🎯 使用方法](#-使用方法)
  - [基础歌词显示](#基础歌词显示)
  - [卡拉OK评分显示](#卡拉ok评分显示)
  - [KaraokeView 组件集成示例](#karaokeview-组件集成示例)
  - [完整集成示例](#完整集成示例)
- [📚 API文档](#-api文档)
  - [KaraokeView 主组件](#karaokeview-主组件)
  - [IKaraokeEvent 事件接口](#ikaraokeevent-事件接口)
  - [LyricsView 歌词显示组件](#lyricsview-歌词显示组件)
  - [ScoringView 评分显示组件](#scoringview-评分显示组件)
  - [数据模型](#数据模型)
- [🎵 RTC MCC集成](#-rtc-mcc集成)
  - [1. RTC MCC初始化](#1-rtc-mcc初始化)
  - [2. 音乐供应商配置](#2-音乐供应商配置)
  - [3. 打分系统开启](#3-打分系统开启)
  - [4. 音乐播放控制](#4-音乐播放控制)
  - [5. 歌词同步](#5-歌词同步)
  - [6. 权限配置](#6-权限配置)
  - [7. 完整集成示例](#7-完整集成示例)
- [🏗️ 构建指南](#️-构建指南)
  - [统一构建脚本](#统一构建脚本)
  - [构建配置](#构建配置)
  - [发布流程](#发布流程)
- [📋 变更记录](#-变更记录)

## 📖 简介

LyricsView HarmonyOS 是一个功能强大的 HarmonyOS 歌词显示组件库，专为卡拉OK应用设计。支持实时歌词显示、音高评分、粒子特效等丰富功能，支持与
声网 RTC SDK 深度集成。

### 🌟 核心特性

- 🎵 **实时歌词显示**: 支持多种歌词格式，流畅的滚动和高亮效果
- 🎤 **卡拉OK模式**: 实时音调匹配，支持原唱/伴唱切换
- 🎯 **智能评分系统**: 基于音高匹配的实时评分算法
- 🎨 **粒子特效**: 丰富的视觉效果，提升用户体验
- 📱 **触摸交互**: 支持手势拖拽定位和进度控制
- 🔄 **MCC集成**: 与声网Rtc SDK 无缝集成
- 📦 **HAR包支持**: 支持源码和HAR包两种集成方式

### 🏗️ 架构设计

```
LyricsView-HarmonyOS/
├── lyrics_view/              # 核心组件模块
│   ├── components/           # UI组件
│   │   ├── LyricsView.ets   # 歌词显示组件
│   │   └── ScoringView.ets  # 评分显示组件
│   ├── KaraokeView.ets      # 卡拉OK主组件
│   └── interfaces/          # 接口定义
└── entry/                   # 示例应用
    ├── pages/MccIndex.ets   # MCC集成示例
    └── viewmodels/          # 业务逻辑
```

## 🚀 跑通Examples

### 环境要求

- **HarmonyOS**: API 9 或更高版本
- **DevEco Studio**: 4.0 或更高版本
- **Node.js**: 16.0 或更高版本

### 1. 克隆项目

   ```bash
git clone git@github.com:Shengwang-Community/LyricsView-HarmonyOS.git
cd LyricsView-HarmonyOS
```

### 2. 配置本地参数

在 `local.properties` 文件中配置您的参数：

```properties
# Agora 配置
APP_ID=your_agora_app_id
APP_CERTIFICATE=your_agora_app_certificate
# RTC/RTM Token
RTC_TOKEN=your_rtc_token
RTM_TOKEN=your_rtm_token
# 音速达配置 (Vendor2)
VENDOR_2_APP_ID=your_yinsuda_app_id
VENDOR_2_APP_KEY=your_yinsuda_app_key
VENDOR_2_TOKEN_HOST=https://your-token-server.com/getUserData?uid=
# 频道配置
CHANNEL_NAME=Karaoke-Test-HarmonyOS
```

### 3. 在DevEco Studio中运行

1. 打开 DevEco Studio
2. 导入项目
3. 连接 HarmonyOS 设备或启动模拟器
4. 点击运行按钮

## 📦 集成组件

### 方式一：HAR包集成（推荐）

#### 1. 构建HAR包

   ```bash
# 构建Release版本HAR包
./build.sh
   ```

   构建完成后，HAR包将生成在以下位置：

- **主要输出位置**: `releases/v1.0.0/Agora-LyricsView-HarmonyOS-1.0.0.har`
- **构建目录**: `lyrics_view/build/default/outputs/default/lyrics_view-default-unsigned.har`
- **SHA256校验文件**: `releases/v1.0.0/Agora-LyricsView-HarmonyOS-1.0.0.har.sha256`

   > 💡 **提示**: 推荐使用 `releases/` 目录下的版本化HAR包，该包已经过完整的构建和验证流程。

#### 2. 添加依赖

在您的项目 `oh-package.json5` 中添加：

   ```json5
   {
     "dependencies": {
    "@shengwang/lyrics-view": "file:./libs/AgoraLyricsView.har"
     }
   }
   ```

#### 3. 导入组件

   ```typescript
import {
  LyricsView, ScoringView, KaraokeView, IKaraokeEvent
} from '@shengwang/lyrics-view';
   ```

### 方式二：源码集成

#### 1. 复制源码

   ```bash
   cp -r lyrics_view /path/to/your/project/
   ```

#### 2. 配置依赖

   ```json5
   {
     "dependencies": {
    "@shengwang/lyrics-view": "file:../lyrics_view"
     }
   }
   ```

#### 3. 导入组件

```typescript
import {
  LyricsView, ScoringView, KaraokeView, IKaraokeEvent
} from '@shengwang/lyrics-view';
```

## 🎯 使用方法

### 基础歌词显示

```typescript
@Entry
@ComponentV2
struct LyricsExample {
  build()
  {
    Column()
    {
      LyricsView({
        textSize: 16,
        currentLineTextSize: 20,
        currentLineTextColor: '#FFFFFF',
        currentLineHighlightedTextColor: '#FF6B35',
        previousLineTextColor: '#CCCCCC',
        upcomingLineTextColor: '#999999',
        lineSpacing: 15,
        enableDragging: true,
        enableAnimation: true
      })
        .width('100%')
        .height('100%')
    }
  }
}
```

### 卡拉OK评分显示

```typescript
@Entry
@ComponentV2
struct ScoringExample {
  build()
  {
    Column()
    {
      ScoringView({
        enableParticleEffect: true,
        pitchIndicatorColor: '#F0F0F0F0',
        localPitchIndicatorColor: '#F0F0F0F0',
        highlightedPitchStickColor: '#FFF44336',
        hitScoreThreshold: 0.7
      })
        .width('100%')
        .height('100%')
    }
  }
}
```

### KaraokeView 组件集成示例

KaraokeView 是核心的卡拉OK组件，以下是完整的集成流程：

#### 1. 初始化 KaraokeView

```typescript
import { KaraokeView, IKaraokeEvent, LyricModel } from '@shengwang/lyrics-view';

class KaraokeManager {
  private karaokeView: KaraokeView;

  constructor() {
    // 初始化 KaraokeView
    this.karaokeView = new KaraokeView();
    
    // 设置事件监听器
    this.karaokeView.setKaraokeEvent({
      onDragTo: (progress: number) => {
        console.log(`拖拽到位置: ${progress}ms`);
        // 处理拖拽事件，更新播放进度
      },
      onLineFinished: (line: number, score: number, cumulativeScore: number, lineWords: number, lineScore: number) => {
        console.log(`行完成 - 行号: ${line}, 得分: ${score}`);
        // 处理行完成事件
      }
    });
  }
}
```

#### 2. 解析歌词数据 (parseLyrics)

```typescript
class LyricsParser {
  private karaokeView: KaraokeView;

  // 从字符串解析歌词
  parseLyricsFromString(lyricContent: string, pitchContent?: string): LyricModel | null {
    try {
      // 解析歌词和音调数据
      const lyricModel = this.karaokeView.parseLyrics(
        lyricContent,           // 歌词内容 (字符串)
        pitchContent,           // 音调数据 (可选)
        true,                   // 包含版权信息
        0                       // 歌词偏移时间(ms)
      );
      
      if (lyricModel) {
        console.log(`解析成功: ${lyricModel.lines.length} 行歌词`);
        return lyricModel;
      }
      return null;
    } catch (error) {
      console.error('歌词解析失败:', error);
      return null;
    }
  }

  // 从字节数组解析歌词
  parseLyricsFromBytes(lyricBytes: Uint8Array, pitchBytes?: Uint8Array): LyricModel | null {
    return this.karaokeView.parseLyrics(
      lyricBytes,             // 歌词字节数据
      pitchBytes,             // 音调字节数据 (可选)
      true,                   // 包含版权信息
      0                       // 歌词偏移时间(ms)
    );
  }
}
```

#### 3. 设置歌词数据 (setLyricData)

```typescript
class KaraokeController {
  private karaokeView: KaraokeView;

  // 设置歌词数据到组件
  setLyricsData(lyricModel: LyricModel, enableScoring: boolean = true): void {
    if (!lyricModel) {
      console.error('歌词数据为空');
      return;
    }

    try {
      // 设置歌词数据到 KaraokeView
      this.karaokeView.setLyricData(
        lyricModel,           // 解析后的歌词模型
        enableScoring        // 是否启用内部评分算法
      );
      
      console.log('歌词数据设置成功');
      console.log(`歌词行数: ${lyricModel.lines.length}`);
      console.log(`歌曲时长: ${lyricModel.duration}ms`);
      console.log(`前奏结束: ${lyricModel.preludeEndTime}ms`);
      
    } catch (error) {
      console.error('设置歌词数据失败:', error);
    }
  }
}
```

#### 4. 更新播放进度 (setProgress)

```typescript
class PlaybackController {
  private karaokeView: KaraokeView;
  private currentProgress: number = 0;

  // 更新播放进度 (通常在音频播放回调中调用)
  updateProgress(progressMs: number): void {
    if (progressMs < 0) {
      console.warn('播放进度不能为负数');
      return;
    }

    this.currentProgress = progressMs;
    
    // 更新 KaraokeView 的播放进度
    this.karaokeView.setProgress(progressMs);
    
    // 可选: 添加进度变化日志 (建议仅在调试时启用)
    // console.log(`播放进度更新: ${progressMs}ms`);
  }

  // 跳转到指定位置
  seekTo(positionMs: number): void {
    this.updateProgress(positionMs);
    console.log(`跳转到: ${positionMs}ms`);
  }
}
```

#### 5. 更新音调数据 (setPitch)

```typescript
class PitchController {
  private karaokeView: KaraokeView;

  // 更新用户演唱的音调数据 (通常在音频处理回调中调用)
  updatePitch(userPitch: number, pitchScore: number): void {
    // 验证音调范围 (0-5000 Hz)
    if (userPitch < 0 || userPitch > 5000) {
      console.warn(`音调超出范围: ${userPitch}Hz`);
      return;
    }

    // 验证评分范围 (0-100)
    if (pitchScore < 0 || pitchScore > 100) {
      console.warn(`音调评分超出范围: ${pitchScore}`);
      return;
    }

    // 更新音调数据到 KaraokeView
    this.karaokeView.setPitch(
      userPitch,              // 用户演唱音调 (Hz)
      pitchScore             // 音调匹配评分 (0-100)
    );
  }

  // 处理静音状态
  handleSilence(): void {
    this.updatePitch(0, 0);
  }
}
```

#### 6. 重置组件 (reset)

```typescript
class KaraokeSession {
  private karaokeView: KaraokeView;

  // 重置卡拉OK组件 (切换歌曲或重新开始时调用)
  resetKaraoke(): void {
    try {
      // 重置所有组件状态
      this.karaokeView.reset();
      
      console.log('KaraokeView 重置成功');
      
      // 可选: 重置其他相关状态
      this.resetPlaybackState();
      this.resetScoringState();
      
    } catch (error) {
      console.error('重置 KaraokeView 失败:', error);
    }
  }

  private resetPlaybackState(): void {
    // 重置播放相关状态
    console.log('播放状态已重置');
  }

  private resetScoringState(): void {
    // 重置评分相关状态
    console.log('评分状态已重置');
  }

  // 销毁资源
  destroy(): void {
    this.resetKaraoke();
    // 清理其他资源
  }
}
```

### 完整集成示例

```typescript
import { KaraokeView, IKaraokeEvent, LyricModel } from '@shengwang/lyrics-view';

@Entry
@ComponentV2
struct KaraokeExample {
  @State private karaokeView: KaraokeView = new KaraokeView();
  @State private currentScore: number = 0;
  @State private currentLine: number = 0;

  aboutToAppear() {
    this.initializeKaraoke();
  }

  aboutToDisappear() {
    this.karaokeView.reset();
  }

  private initializeKaraoke(): void {
    // 设置事件监听
    this.karaokeView.setKaraokeEvent({
      onDragTo: (progress: number) => {
        // 处理拖拽跳转
        console.log(`跳转到: ${progress}ms`);
      },
      onLineFinished: (line: number, score: number, cumulativeScore: number, lineWords: number, lineScore: number) => {
        this.currentLine = line;
        this.currentScore = cumulativeScore;
        console.log(`第${line}行完成，累计得分: ${cumulativeScore}`);
      }
    });

    // 加载示例歌词
    this.loadSampleLyrics();
  }

  private loadSampleLyrics(): void {
    const sampleLyrics = `
[00:10.00]第一行歌词
[00:15.00]第二行歌词
[00:20.00]第三行歌词
    `;

    // 解析歌词
    const lyricModel = this.karaokeView.parseLyrics(sampleLyrics);
    if (lyricModel) {
      // 设置歌词数据
      this.karaokeView.setLyricData(lyricModel, true);
    }
  }

  // 模拟播放进度更新
  private simulatePlayback(): void {
    let progress = 0;
    const timer = setInterval(() => {
      progress += 100; // 每100ms更新一次
      this.karaokeView.setProgress(progress);
      
      // 模拟音调数据
      const pitch = 200 + Math.random() * 300; // 200-500Hz
      const score = Math.random() * 100; // 0-100分
      this.karaokeView.setPitch(pitch, score);
      
      if (progress > 30000) { // 30秒后停止
        clearInterval(timer);
      }
    }, 100);
  }

  build() {
    Column() {
      // 显示当前状态
      Text(`当前行: ${this.currentLine}, 得分: ${this.currentScore}`)
        .fontSize(16)
        .margin(10)

      // 歌词显示区域
      LyricsView({
        textSize: 16,
        currentLineTextSize: 20,
        currentLineTextColor: '#FFFF00',
        currentLineHighlightedTextColor: '#FFF44336'
      })
        .layoutWeight(1)

      // 评分显示区域
      ScoringView({
        enableParticleEffect: true
      })
        .height(180)

      // 控制按钮
      Row() {
        Button('开始播放')
          .onClick(() => {
            this.simulatePlayback();
          })
        
        Button('重置')
          .onClick(() => {
            this.karaokeView.reset();
            this.currentScore = 0;
            this.currentLine = 0;
          })
      }
      .justifyContent(FlexAlign.SpaceEvenly)
      .width('100%')
      .height(60)
    }
    .width('100%')
    .height('100%')
  }
}
```

## 📚 API文档

### KaraokeView 主组件

`KaraokeView` 是核心的卡拉OK控制器，负责管理歌词显示、评分和组件间同步。

#### 主要方法

```typescript
class KaraokeView {
  /**
   * 解析歌词数据
   * @param lyricSource 歌词文件路径(string)或字节数据(Uint8Array)
   * @param pitchSource 音调文件路径(string)或字节数据(Uint8Array)，可选
   * @param includeCopyrightSentence 是否包含版权信息，默认true
   * @param lyricOffset 歌词时间偏移(ms)，默认0
   * @returns 解析后的歌词模型或null
   */
  parseLyrics(
    lyricSource: string | Uint8Array,
    pitchSource?: string | Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null;

  /**
   * 设置歌词数据到组件
   * @param model 歌词模型
   * @param usingInternalScoring 是否使用内部评分算法，默认false
   */
  setLyricData(model: LyricModel, usingInternalScoring: boolean = false): void;

  /**
   * 更新播放进度
   * @param progress 当前播放进度(毫秒)
   */
  setProgress(progress: number): void;

  /**
   * 更新音调数据
   * @param speakerPitch 用户演唱音调(Hz，范围0-5000)
   * @param pitchScore 音调匹配评分(0-100)
   */
  setPitch(speakerPitch: number, pitchScore: number): void;

  /**
   * 重置所有组件状态
   */
  reset(): void;

  /**
   * 设置事件监听器
   * @param event 事件监听器接口
   */
  setKaraokeEvent(event: IKaraokeEvent): void;

  /**
   * 销毁资源
   */
  destroy(): void;
}
```

### IKaraokeEvent 事件接口

```typescript
interface IKaraokeEvent {
  /**
   * 歌词拖拽事件
   * @param progress 拖拽到的进度位置(毫秒)
   */
  onDragTo(progress: number): void;

  /**
   * 歌词行完成事件
   * @param line 完成的歌词行数据
   * @param score 当前行得分(0-100)
   * @param cumulativeScore 累计总分
   * @param index 当前行索引(从0开始)
   * @param lineCount 总行数
   */
  onLineFinished(
    line: LyricsLineModel,
    score: number,
    cumulativeScore: number,
    index: number,
    lineCount: number
  ): void;
}
```

### LyricsView 歌词显示组件

专门用于歌词显示的UI组件。

```typescript
@Component
struct LyricsView {
  // 背景配置
  @Prop viewBackgroundColor: string = '#CE93D8';

  // 文字样式
  @Prop textSize: number = 16; // 普通歌词字体大小
  @Prop currentLineTextSize: number = 20; // 当前行字体大小
  @Prop currentLineTextColor: string = '#FFFFFF'; // 当前行文字颜色
  @Prop currentLineHighlightedTextColor: string = '#FF6B35'; // 当前行高亮颜色
  @Prop previousLineTextColor: string = '#999999'; // 上一行文字颜色
  @Prop upcomingLineTextColor: string = '#999999'; // 下一行文字颜色

  // 布局配置
  @Prop lineSpacing: number = 12; // 行间距
  @Prop paddingTop: number = 5; // 顶部内边距
  @Prop textGravity: number = 0; // 文字对齐方式(0=居中, 1=左对齐, 2=右对齐)

  // 功能开关
  @Prop enableLineWrap: boolean = false; // 是否启用自动换行
  @Prop enableDragging: boolean = true; // 是否启用拖拽
  @Prop enableOpacityEffect: boolean = true; // 是否启用透明度渐变效果
  @Prop enablePreviousLines: boolean = true; // 是否显示上一行
  @Prop enableUpcomingLines: boolean = true; // 是否显示下一行

  // 前奏指示器
  @Prop enablePreludeEndPositionIndicator: boolean = true; // 是否显示前奏结束指示器
  @Prop preludeEndPositionIndicatorPaddingTop: number = 3; // 指示器顶部间距
  @Prop preludeEndPositionIndicatorRadius: number = 4; // 指示器圆点半径
  @Prop preludeEndPositionIndicatorColor: string = '#FF6B35'; // 指示器颜色

  // 无歌词时显示
  @Prop labelWhenNoLyrics: string = '暂无歌词'; // 无歌词时的提示文字
}
```

### ScoringView 评分显示组件

专门用于显示评分和音调匹配的UI组件。

```typescript
@Component
struct ScoringView {
  // 背景配置
  @Prop viewBackgroundColor: string = '#ffffbb33';

  // 导线配置
  @Prop leadingLinesColor: string = '#4DFFFFFF'; // 导线颜色
  @Prop leadingLinesHeight: number = 1; // 导线高度

  // 音调指示器
  @Prop pitchIndicatorColor: string = '#F0F0F0F0'; // 音调指示器颜色
  @Prop pitchIndicatorWidth: number = 3; // 音调指示器宽度
  @Prop localPitchIndicatorColor: string = '#F0F0F0F0'; // 本地音调指示器颜色
  @Prop localPitchIndicatorRadius: number = 8; // 本地音调指示器半径

  // 音调条
  @Prop pitchStickHeight: number = 4; // 音调条高度
  @Prop pitchStickRadius: number = 4; // 音调条圆角
  @Prop refPitchStickDefaultColor: string = '#99FFFFFF'; // 参考音调条默认颜色
  @Prop highlightedPitchStickColor: string = '#FFF44336'; // 高亮音调条颜色

  // 评分配置
  @Prop initialScore: number = 0; // 初始分数
  @Prop hitScoreThreshold: number = 0.7; // 命中分数阈值(0-1)

  // 动画配置
  @Prop movingPixelsPerMs: number = 0.2; // 移动像素/毫秒
  @Prop startPointHorizontalBias: number = 0.4; // 起始点水平偏移(0-1)

  // 特效配置
  @Prop enableParticleEffect: boolean = true; // 是否启用粒子特效
}
```

### 数据模型

#### LyricModel - 歌词模型

```typescript
class LyricModel {
  /** 歌词类型 */
  type: LyricType;
  
  /** 歌曲名称 */
  name: string = '';
  
  /** 歌手名称 */
  singer: string = '';
  
  /** 歌词行数组 */
  lines: LyricsLineModel[] = [];
  
  /** 前奏结束位置(毫秒) */
  preludeEndPosition: number = 0;
  
  /** 歌曲总时长(毫秒) */
  duration: number = 0;
  
  /** 是否包含音调信息 */
  hasPitch: boolean = false;
  
  /** 版权信息行数 */
  copyrightSentenceLineCount: number = 0;
  
  /** 音调数据列表 */
  pitchDataList: PitchData[] | null = null;

  /**
   * 创建深拷贝
   */
  copy(): LyricModel;

  /**
   * 转换为字符串表示
   */
  toString(): string;
}
```

#### LyricsLineModel - 歌词行模型

```typescript
class LyricsLineModel {
  /** 行开始时间(毫秒) */
  startTime: number = 0;
  
  /** 行结束时间(毫秒) */
  endTime: number = 0;
  
  /** 歌词文本内容 */
  content: string = '';
  
  /** 音调数据数组 */
  tones: Tone[] = [];
  
  /** 是否为独白 */
  isMonolog: boolean = false;

  /**
   * 获取行持续时间
   */
  getDuration(): number;

  /**
   * 转换为字符串表示
   */
  toString(): string;
}
```

#### Tone - 音调数据模型

```typescript
class Tone {
  /** 开始时间(毫秒) */
  begin: number = 0;
  
  /** 结束时间(毫秒) */
  end: number = 0;
  
  /** 文字内容 */
  word: string = '';
  
  /** 语言类型 */
  lang: Lang = Lang.Chinese;
  
  /** 音调值 */
  pitch: number = 0;
  
  /** 是否为整行 */
  isFullLine: boolean = false;

  /**
   * 获取持续时间
   */
  getDuration(): number;

  /**
   * 转换为字符串表示
   */
  toString(): string;
}
```

#### Lang - 语言枚举

```typescript
enum Lang {
  Chinese = 'Chinese',
  English = 'English'
}
```

#### LyricType - 歌词类型枚举

```typescript
enum LyricType {
  LRC = 'LRC',    // 标准LRC格式
  KRC = 'KRC',    // 酷狗KRC格式
  XML = 'XML'     // XML格式
}
```

## 🎵 RTC MCC集成

### 1. RTC MCC初始化

#### 1.1 创建RTC引擎和MCC

```typescript
import { RtcEngine, RtcEngineConfig, IAgoraMusicContentCenter, MusicContentCenterConfiguration } from '@shengwang/rtc-full';

class RtcMccManager {
  private rtcEngine: RtcEngine | null = null;
  private musicCenter: IAgoraMusicContentCenter | null = null;
  private musicPlayer: IAgoraMusicPlayer | null = null;

  /**
   * 初始化RTC MCC管理器
   */
  async init(
    context: common.UIAbilityContext,
    appId: string,
    channelId: string,
    rtcToken: string,
    rtmToken: string,
    userId: string,
    ysdAppId: string,
    ysdAppKey: string,
    ysdUserId: string,
    ysdToken: string,
    callback: IMccCallback
  ): Promise<void> {
    try {
      // 初始化RTC引擎
      await this.initRtcEngine(context, appId);
      
      // 初始化音乐内容中心
      await this.initMusicContentCenter();
      
      console.log('RTC MCC初始化成功');
    } catch (error) {
      console.error('RTC MCC初始化失败:', error);
      throw error;
    }
  }

  /**
   * 初始化RTC引擎
   */
  private async initRtcEngine(context: common.UIAbilityContext, appId: string): Promise<void> {
    console.log(`RTC引擎版本: ${RtcEngine.getSdkVersion()}`);

    const rtcEngineConfig: RtcEngineConfig = new RtcEngineConfig();
    rtcEngineConfig.mContext = context;
    rtcEngineConfig.mAppId = appId;
    
    // 设置RTC事件监听器
    rtcEngineConfig.mEventHandler = {
      onJoinChannelSuccess: (channel: string, uid: number, elapsed: number) => {
        console.log(`成功加入频道: ${channel}, UID: ${uid}`);
        this.localUid = uid;
        this.isJoined = true;
        
        // 加入频道成功后添加音乐供应商
        Promise.resolve().then(() => {
          this.addMccVendors();
        });
      },
      
      onLeaveChannel: (stats: RtcStats | null) => {
        console.log('离开频道');
        this.isJoined = false;
      },
      
      onUserJoined: (uid: number, elapsed: number) => {
        console.log(`用户加入: ${uid}`);
      },
      
      onUserOffline: (uid: number, reason: number) => {
        console.log(`用户离线: ${uid}, 原因: ${reason}`);
      }
    };

    // 创建RTC引擎
    this.rtcEngine = RtcEngine.create(rtcEngineConfig);
    this.rtcEngine.enableAudio();
    this.rtcEngine.setDefaultAudioRoutetoSpeakerphone(true);
  }

  /**
   * 初始化音乐内容中心
   */
  private async initMusicContentCenter(): Promise<void> {
    if (!this.rtcEngine) {
      throw new Error('RTC引擎未初始化');
    }

    // 创建MCC配置
    const mccConfig: MusicContentCenterConfiguration = new MusicContentCenterConfiguration();
    mccConfig.appId = this.appId;
    mccConfig.token = this.rtmToken;
    mccConfig.mccUid = parseInt(this.userId);

    // 创建音乐内容中心
    this.musicCenter = this.rtcEngine.getMusicContentCenter();
    
    // 设置MCC事件监听器
    this.musicCenter.registerEventHandler(this.mccEventHandler);
    
    // 初始化MCC
    const ret = this.musicCenter.initialize(mccConfig);
    if (ret !== 0) {
      throw new Error(`MCC初始化失败: ${ret}`);
    }

    console.log('音乐内容中心初始化成功');
  }
}
```

#### 1.2 加入RTC频道

```typescript
/**
 * 加入RTC频道
 */
async joinChannel(): Promise<void> {
  if (!this.rtcEngine) {
    throw new Error('RTC引擎未初始化');
  }

  const channelMediaOptions = new ChannelMediaOptions();
  channelMediaOptions.channelProfile = Constants.ChannelProfile.LIVE_BROADCASTING;
  channelMediaOptions.clientRoleType = Constants.ClientRole.BROADCASTER;
  channelMediaOptions.autoSubscribeAudio = true;
  channelMediaOptions.autoSubscribeVideo = false;
  channelMediaOptions.publishMicrophoneTrack = true;

  const ret = await this.rtcEngine.joinChannel(
    this.rtcToken,
    this.channelId,
    parseInt(this.userId),
    channelMediaOptions
  );

  if (ret !== 0) {
    throw new Error(`加入频道失败: ${ret}`);
  }

  console.log(`正在加入频道: ${this.channelId}`);
}
```

### 2. 音乐供应商配置

#### 2.1 配置Vendor1 (音集协)

```typescript
/**
 * 添加音乐供应商
 */
private addMccVendors(): void {
  if (!this.musicCenter) {
    console.error('音乐内容中心未初始化');
    return;
  }

  // 配置Vendor1 (音集协)
  const vendor1Config: IVendor1Config = {
    appId: this.appId,
    token: this.rtcToken,
    userId: this.userId,
    channelId: this.channelId
  };

  let addVendorRet = this.musicCenter.addVendor(
    MusicContentCenterVendorId.DEFAULT,
    JSON.stringify(vendor1Config)
  );
  
  console.log(`添加Vendor1结果: ${addVendorRet}`);
}
```

#### 2.2 配置Vendor2 (音速达)

```typescript
// 配置Vendor2 (音速达)
const vendor2Config: IVendor2Config = {
  appId: this.ysdAppId,           // 音速达应用ID
  appKey: this.ysdAppKey,         // 音速达应用密钥
  token: this.ysdToken,           // 音速达Token
  userId: this.ysdUserId,         // 音速达用户ID
  deviceId: Utils.generateDeviceId(), // 设备ID
  urlTokenExpireTime: 15 * 60,    // URL Token过期时间(秒)
  chargeMode: 2,                  // 计费模式
  channelId: this.channelId,      // RTC频道ID
  channelUserId: this.userId      // RTC用户ID
};

addVendorRet = this.musicCenter.addVendor(
  MusicContentCenterVendorId.VENDOR_2,
  JSON.stringify(vendor2Config)
);

console.log(`添加Vendor2结果: ${addVendorRet}`);
```

#### 2.3 本地配置文件

在 `local.properties` 中配置音速达参数：

```properties
# 声网配置
APP_ID=your_agora_app_id
APP_CERTIFICATE=your_agora_app_certificate
RTC_TOKEN=your_rtc_token
RTM_TOKEN=your_rtm_token

# 音速达配置 (Vendor2)
VENDOR_2_APP_ID=your_yinsuda_app_id
VENDOR_2_APP_KEY=your_yinsuda_app_key
VENDOR_2_TOKEN_HOST=https://your-token-server.com/getUserData?uid=

# 频道配置
CHANNEL_NAME=Karaoke-Test-HarmonyOS
```

### 3. 打分系统开启

#### 3.1 开始打分

```typescript
/**
 * 开始打分
 * @param vendorId 供应商ID
 * @param songCode 歌曲代码
 * @param jsonOption JSON选项
 */
startScore(vendorId: MusicContentCenterVendorId, songCode: string, jsonOption: string): void {
  if (!this.musicCenter) {
    console.error('MCC未初始化');
    return;
  }

  try {
    // 获取内部歌曲代码
    const internalSongCode: bigint = this.musicCenter.getInternalSongCode(
      vendorId,
      songCode,
      jsonOption
    );
    
    if (internalSongCode === BigInt(0)) {
      console.error(`获取内部歌曲代码失败: ${songCode}`);
      return;
    }

    // 开始打分
    const ret: number = this.musicCenter.startScore(internalSongCode);
    console.log(`开始打分结果: ${ret}, 歌曲代码: ${internalSongCode}`);
    
  } catch (error) {
    console.error('开始打分失败:', error);
  }
}
```

#### 3.2 停止打分

```typescript
/**
 * 停止打分
 */
stopScore(): void {
  if (!this.musicCenter) {
    console.error('MCC未初始化');
    return;
  }

  try {
    this.musicCenter.stopScore();
    console.log('打分已停止');
  } catch (error) {
    console.error('停止打分失败:', error);
  }
}
```

#### 3.3 打分事件处理

```typescript
/**
 * MCC事件处理器
 */
private mccEventHandler: IMusicContentCenterEventHandler = {
  // 打分开始结果
  onStartScoreResult: (internalSongCode: bigint, state: Constants.MusicContentCenterState, reason: Constants.MusicContentCenterStateReason) => {
    console.log(`打分开始结果 - 歌曲: ${internalSongCode}, 状态: ${state}, 原因: ${reason}`);
    
    if (state === Constants.MusicContentCenterState.SCORE_OK) {
      console.log('打分系统启动成功');
      // 通知应用打分已开始
      this.callback?.onScoringStarted?.(internalSongCode);
    }
  },

  // 实时打分数据
  onScoreResult: (internalSongCode: bigint, scoreData: RawScoreData) => {
    // 处理实时打分数据
    this.callback?.onScoringUpdate?.(scoreData);
  },

  // 行打分结果
  onLineScoreResult: (internalSongCode: bigint, lineScoreData: LineScoreData) => {
    // 处理行打分结果
    this.callback?.onLineScoreUpdate?.(lineScoreData);
  }
};
```

### 4. 音乐播放控制

#### 4.1 播放音乐

```typescript
/**
 * 播放音乐
 * @param vendorId 供应商ID
 * @param songCode 歌曲代码
 * @param jsonOption JSON选项
 */
async playMusic(vendorId: MusicContentCenterVendorId, songCode: string, jsonOption: string): Promise<void> {
  if (!this.musicCenter) {
    throw new Error('MCC未初始化');
  }

  try {
    // 获取内部歌曲代码
    const internalSongCode: bigint = this.musicCenter.getInternalSongCode(
      vendorId,
      songCode,
      jsonOption
    );

    if (internalSongCode === BigInt(0)) {
      throw new Error(`获取内部歌曲代码失败: ${songCode}`);
    }

    // 打开音乐
    await this.openMusicBySongCode(internalSongCode);
    
    console.log(`开始播放音乐: ${internalSongCode}`);
    
  } catch (error) {
    console.error('播放音乐失败:', error);
    throw error;
  }
}

/**
 * 通过歌曲代码打开音乐
 */
private openMusicBySongCode(internalSongCode: bigint): void {
  if (!this.musicPlayer) {
    // 创建音乐播放器
    this.musicPlayer = this.musicCenter?.createMusicPlayer();
    if (!this.musicPlayer) {
      throw new Error('创建音乐播放器失败');
    }
    
    // 设置播放器事件监听器
    this.musicPlayer.registerPlayerObserver(this.playerObserver);
  }

  // 打开音乐文件
  const ret = this.musicPlayer.open(internalSongCode, 0);
  if (ret !== 0) {
    throw new Error(`打开音乐失败: ${ret}`);
  }
}
```

#### 4.2 播放控制

```typescript
/**
 * 播放
 */
play(): void {
  if (!this.musicPlayer) {
    console.error('音乐播放器未创建');
    return;
  }
  
  const ret = this.musicPlayer.play();
  console.log(`播放结果: ${ret}`);
}

/**
 * 暂停
 */
pause(): void {
  if (!this.musicPlayer) {
    console.error('音乐播放器未创建');
    return;
  }
  
  const ret = this.musicPlayer.pause();
  console.log(`暂停结果: ${ret}`);
}

/**
 * 恢复播放
 */
resume(): void {
  if (!this.musicPlayer) {
    console.error('音乐播放器未创建');
    return;
  }
  
  const ret = this.musicPlayer.resume();
  console.log(`恢复播放结果: ${ret}`);
}

/**
 * 停止播放
 */
stop(): void {
  if (!this.musicPlayer) {
    console.error('音乐播放器未创建');
    return;
  }
  
  this.musicPlayer.stop();
  this.musicCenter?.stopScore();
  console.log('音乐已停止');
}

/**
 * 跳转到指定位置
 * @param positionMs 位置(毫秒)
 */
seek(positionMs: number): void {
  if (!this.musicPlayer) {
    console.error('音乐播放器未创建');
    return;
  }
  
  const ret = this.musicPlayer.seek(positionMs);
  console.log(`跳转结果: ${ret}, 位置: ${positionMs}ms`);
}
```

### 5. 歌词同步

#### 5.1 歌词数据处理

```typescript
/**
 * 处理歌词结果
 */
private handleLyricResult(internalSongCode: bigint, payload: string): void {
  try {
    const jsonObject: Record<string, Object> = JSON.parse(payload);
    const lyricPath = (jsonObject.lyricPath as string) || "";
    const pitchPath = (jsonObject.pitchPath as string) || "";
    const songOffsetBegin = (jsonObject.songOffsetBegin as number) || 0;
    const songOffsetEnd = (jsonObject.songOffsetEnd as number) || 0;
    const lyricOffset = (jsonObject.lyricOffset as number) || 0;

    console.log(`歌词数据 - 歌曲: ${internalSongCode}, 歌词路径: ${lyricPath}`);

    // 通知应用处理歌词
    Promise.resolve().then(() => {
      this.callback?.onMusicLyricRequest?.(
        internalSongCode,
        lyricPath,
        pitchPath,
        songOffsetBegin,
        songOffsetEnd,
        lyricOffset
      );
    });
    
  } catch (error) {
    console.error('处理歌词结果失败:', error);
  }
}
```

#### 5.2 播放进度同步

```typescript
/**
 * 音乐播放器事件监听器
 */
private playerObserver: IMediaPlayerObserver = {
  onPositionChanged: (positionMs: number, timestampMs: number) => {
    // 更新播放进度到歌词组件
    this.callback?.onMusicProgressUpdate?.(positionMs);
  },

  onPlayerStateChanged: (state: Constants.MediaPlayerState, reason: Constants.MediaPlayerReason) => {
    switch (state) {
      case Constants.MediaPlayerState.PLAYING:
        console.log('音乐开始播放');
        this.callback?.onMusicPlay?.();
        break;
        
      case Constants.MediaPlayerState.PAUSED:
        console.log('音乐暂停');
        this.callback?.onMusicPause?.();
        break;
        
      case Constants.MediaPlayerState.STOPPED:
        console.log('音乐停止');
        this.callback?.onMusicStop?.();
        break;
        
      case Constants.MediaPlayerState.FAILED:
        console.error('音乐播放失败');
        this.callback?.onMusicError?.(reason);
        break;
    }
  }
};
```

#### 5.3 歌词组件集成

```typescript
/**
 * MCC回调接口实现
 */
class MccCallbackImpl implements IMccCallback {
  private karaokeView: KaraokeView;

  constructor(karaokeView: KaraokeView) {
    this.karaokeView = karaokeView;
  }

  /**
   * 歌词请求回调
   */
  onMusicLyricRequest(
    internalSongCode: bigint,
    lyricPath: string,
    pitchPath: string,
    songOffsetBegin: number,
    songOffsetEnd: number,
    lyricOffset: number
  ): void {
    // 加载并解析歌词
    this.loadAndParseLyrics(lyricPath, pitchPath, lyricOffset);
  }

  /**
   * 播放进度更新回调
   */
  onMusicProgressUpdate(positionMs: number): void {
    // 更新歌词组件进度
    this.karaokeView.setProgress(positionMs);
  }

  /**
   * 打分数据更新回调
   */
  onScoringUpdate(scoreData: RawScoreData): void {
    // 更新音调数据到歌词组件
    this.karaokeView.setPitch(scoreData.pitch, scoreData.score);
  }

  /**
   * 加载并解析歌词
   */
  private async loadAndParseLyrics(lyricPath: string, pitchPath: string, lyricOffset: number): Promise<void> {
    try {
      // 从MCC路径加载歌词数据
      const lyricContent = await this.loadLyricContent(lyricPath);
      const pitchContent = pitchPath ? await this.loadPitchContent(pitchPath) : undefined;

      // 解析歌词
      const lyricModel = this.karaokeView.parseLyrics(
        lyricContent,
        pitchContent,
        true,
        lyricOffset
      );

      if (lyricModel) {
        // 设置歌词数据到组件
        this.karaokeView.setLyricData(lyricModel, true);
        console.log('歌词加载成功');
      }
      
    } catch (error) {
      console.error('加载歌词失败:', error);
    }
  }
}
```

### 6. 权限配置

#### 6.1 模块权限声明

在 `entry/src/main/module.json5` 中添加必要权限：

```json5
{
  "requestPermissions": [
    {
      "name": "ohos.permission.INTERNET",
      "reason": "$string:internet_permission_reason",
      "usedScene": {
        "abilities": ["EntryAbility"],
        "when": "always"
      }
    },
    {
      "name": "ohos.permission.MICROPHONE",
      "reason": "$string:microphone_permission_reason",
      "usedScene": {
        "abilities": ["EntryAbility"],
        "when": "always"
      }
    }
  ]
}
```

#### 6.2 权限申请理由

在 `entry/src/main/resources/base/element/string.json` 中添加权限说明：

```json5
{
  "string": [
    {
      "name": "internet_permission_reason",
      "value": "访问网络下载歌词和音乐文件"
    },
    {
      "name": "microphone_permission_reason",
      "value": "录制用户演唱音频进行卡拉OK评分"
    }
  ]
}
```

#### 6.3 动态权限申请

```typescript
import { PermissionUtil } from '../utils/PermissionUtil';

/**
 * 检查并申请权限
 */
async checkAndRequestPermissions(): Promise<boolean> {
  const context = this.context;
  if (!context) {
    console.error('应用上下文不可用');
    return false;
  }

  try {
    // 检查核心权限
    const hasPermissions = await PermissionUtil.hasEssentialPermissions(context);
    
    if (hasPermissions) {
      console.log('权限已授予');
      return true;
    }

    // 申请权限
    console.log('申请必要权限');
    const result = await PermissionUtil.requestEssentialPermissions(context);
    PermissionUtil.logPermissionResult(result);

    return result.success;
    
  } catch (error) {
    console.error('权限申请失败:', error);
    return false;
  }
}
```

### 7. 完整集成示例

```typescript
import { RtcMccManager } from '../managers/RtcMccManager';
import { KaraokeView, LyricModel } from '@shengwang/lyrics-view';

@Entry
@ComponentV2
struct MccKaraokeExample {
  @State private rtcMccManager: RtcMccManager = new RtcMccManager();
  @State private karaokeView: KaraokeView = new KaraokeView();
  @State private isInitialized: boolean = false;

  aboutToAppear() {
    this.initializeMccKaraoke();
  }

  aboutToDisappear() {
    this.cleanup();
  }

  /**
   * 初始化MCC卡拉OK
   */
  private async initializeMccKaraoke(): Promise<void> {
    try {
      // 1. 检查权限
      const hasPermissions = await this.checkAndRequestPermissions();
      if (!hasPermissions) {
        console.error('权限申请失败');
        return;
      }

      // 2. 初始化RTC MCC
      await this.rtcMccManager.init(
        this.context,
        'your_app_id',
        'your_channel_id',
        'your_rtc_token',
        'your_rtm_token',
        'your_user_id',
        'your_ysd_app_id',
        'your_ysd_app_key',
        'your_ysd_user_id',
        'your_ysd_token',
        new MccCallbackImpl(this.karaokeView)
      );

      // 3. 加入频道
      await this.rtcMccManager.joinChannel();

      // 4. 设置卡拉OK事件监听
      this.karaokeView.setKaraokeEvent({
        onDragTo: (progress: number) => {
          // 处理拖拽跳转
          this.rtcMccManager.seek(progress);
        },
        onLineFinished: (line, score, cumulativeScore, index, lineCount) => {
          console.log(`第${index}行完成，得分: ${score}`);
        }
      });

      this.isInitialized = true;
      console.log('MCC卡拉OK初始化成功');
      
    } catch (error) {
      console.error('MCC卡拉OK初始化失败:', error);
    }
  }

  /**
   * 播放歌曲
   */
  private async playSong(songCode: string): Promise<void> {
    if (!this.isInitialized) {
      console.error('MCC未初始化');
      return;
    }

    try {
      // 开始播放音乐
      await this.rtcMccManager.playMusic(
        MusicContentCenterVendorId.DEFAULT,
        songCode,
        '{}'
      );

      // 开始打分
      this.rtcMccManager.startScore(
        MusicContentCenterVendorId.DEFAULT,
        songCode,
        '{}'
      );
      
    } catch (error) {
      console.error('播放歌曲失败:', error);
    }
  }

  /**
   * 清理资源
   */
  private cleanup(): void {
    this.rtcMccManager.stop();
    this.rtcMccManager.leaveChannel();
    this.karaokeView.reset();
  }

  build() {
    Column() {
      if (this.isInitialized) {
        // 歌词显示区域
        LyricsView({
          textSize: 16,
          currentLineTextSize: 20,
          currentLineTextColor: '#FFFF00',
          currentLineHighlightedTextColor: '#FFF44336'
        })
          .layoutWeight(1)

        // 评分显示区域
        ScoringView({
          enableParticleEffect: true
        })
          .height(180)

        // 控制按钮
        Row() {
          Button('播放歌曲')
            .onClick(() => {
              this.playSong('example_song_code');
            })
          
          Button('暂停')
            .onClick(() => {
              this.rtcMccManager.pause();
            })
          
          Button('恢复')
            .onClick(() => {
              this.rtcMccManager.resume();
            })
        }
        .justifyContent(FlexAlign.SpaceEvenly)
        .width('100%')
        .height(60)
      } else {
        Text('正在初始化...')
          .fontSize(16)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
```

## 🏗️ 构建指南

### 统一构建脚本

项目提供了统一的构建脚本 `build.sh`：

```bash
# 显示帮助信息
./build.sh help

# 构建HAR包 (默认Release版本)
./build.sh

# 切换SDK模式
node scripts/config-manager.js set-sdk-mode true   # HAR包模式
node scripts/config-manager.js set-sdk-mode false  # 源码模式

# 清理构建文件
./build.sh clean
```

### 构建配置

#### SDK模式切换

- **源码模式** (`sdk.mode: false`):
  - 使用 `"@shengwang/lyrics-view": "file:../lyrics_view"`
  - 删除 `entry/libs/AgoraLyricsView.har`

- **HAR包模式** (`sdk.mode: true`):
  - 使用 `"@shengwang/lyrics-view": "file:./libs/AgoraLyricsView.har"`
  - 复制HAR包到 `entry/libs/`

#### 混淆配置

Release版本未启用代码混淆，可以开启保护导出的API：

```txt
# obfuscation-rules.txt
-keep-global-name LyricsView
-keep-global-name ScoringView
-keep-global-name KaraokeView
-keep-global-name IKaraokeEvent
# ... 其他API
```

### 发布流程

1. **更新版本号**

   ```typescript
   // lyrics_view/src/main/ets/constants/Version.ets
   public static readonly MINOR_VERSION: number = 1; // 升级版本
   ```

2. **构建发布包**

   ```bash
   ./build.sh
   ```

3. **验证发布包**

   ```bash
   ls -la releases/v1.0.0/
   # Agora-LyricsView-HarmonyOS-1.0.0.har
   # Agora-LyricsView-HarmonyOS-1.0.0.har.sha256
   # RELEASE_NOTES.md
   ```

## 📋 变更记录

### v1.0.0 (2024-09-29)

#### 🎉 首次发布

**新增功能**

- ✨ 实时歌词显示组件 `LyricsView`
- ✨ 卡拉OK评分组件 `ScoringView`
- ✨ 卡拉OK主组件 `KaraokeView`
- ✨ MCC (Music Content Center) 集成
- ✨ 支持音集协和音速达两种音乐供应商
- ✨ 智能评分算法和粒子特效
- ✨ 触摸交互和手势拖拽
- ✨ 动态权限管理系统

**API接口**

- 📚 `IKaraokeEvent` 事件接口
- 📚 `LyricModel` 和 `LyricsLineModel` 数据模型
- 📚 丰富的组件配置属性
- 📚 完整的回调事件系统

---

<div align="center">
  <p>Made with ❤️ by 声网</p>
  <p>
    <a href="https://www.shengwang.cn//">官网</a> •
    <a href="https://github.com/Shengwang-Community">GitHub</a> •
    <a href="https://developer.harmonyos.com/">HarmonyOS</a>
  </p>
</div>
