import { MccKaraokeViewModel } from '../viewmodels/MccKaraokeViewModel';

import { KaraokeView, LyricsView, ScoringView } from '@shengwang/lyrics-view';

/**
 * MCC集成的卡拉OK页面
 * 使用MCC (Music Content Center) 进行音乐播放和歌词同步
 *
 * 功能特性：
 * - 支持Vendor1和Vendor2两种音乐供应商，默认为Vendor1，vendor1：音集协，vendor2：音速达
 * - 从MCC获取歌词数据
 * - 实时音乐播放和歌词同步
 * - 支持原唱/伴唱切换
 * - 支持音高评分和粒子效果
 */
@Entry
@ComponentV2
struct MccIndex {
  @Local private viewModel: MccKaraokeViewModel = new MccKaraokeViewModel();

  aboutToAppear() {
    // 初始化 ViewModel
    this.viewModel.initialize();
  }

  aboutToDisappear() {
    // 销毁 ViewModel，释放资源
    this.viewModel.destroy();
  }

  @Builder
  HeaderBuilder() {
    Row() {
      Column() {
        Text('MCC 卡拉OK演示')
          .fontSize(16)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)

        Text(this.viewModel.songInfo.getDescription())
          .fontSize(12)
          .fontColor('#666666')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })

        Row() {
          Text(`Vendor: ${this.viewModel.songInfo.vendorName}`)
            .fontSize(10)
            .fontColor('#2196F3')
        }
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  ScoringViewBuilder() {
    ScoringView({
      enableParticleEffect: true
    })
      .width('100%')
      .height('100%')
  }

  @Builder
  LyricsViewBuilder() {
    LyricsView({
      textSize: 16,
      currentLineTextSize: 20,
      currentLineTextColor: '#FFFF00',
      currentLineHighlightedTextColor: '#FFF44336',
      previousLineTextColor: '#FFFFFF',
      upcomingLineTextColor: '#FFFFFF',
      lineSpacing: 15,
      paddingTop: 15,
      labelWhenNoLyrics: '暂无歌词',
      enableLineWrap: false,
      enableDragging: true,
      enablePreviousLines: true,
      enableUpcomingLines: true,
      enablePreludeEndPositionIndicator: true,
      preludeEndPositionIndicatorPaddingTop: 5,
      preludeEndPositionIndicatorRadius: 4,
      preludeEndPositionIndicatorColor: '#FF6B35',
      textGravity: 0
    })
      .width('100%')
      .height('100%')
  }

  @Builder
  StatusBarBuilder() {
    Column({ space: 8 }) {
      // 频道和UID信息
      Row() {
        Text('频道: ')
          .fontSize(12)
          .fontColor('#666666')

        Text(this.viewModel.channelName || '未设置')
          .fontSize(12)
          .fontColor('#2196F3')
          .fontWeight(FontWeight.Medium)
          .margin({ right: 16 })

        Text('UID: ')
          .fontSize(12)
          .fontColor('#666666')

        Text(this.viewModel.rtcUid.toString())
          .fontSize(12)
          .fontColor('#2196F3')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      // 播放进度显示
      Row() {
        Text('播放进度: ')
          .fontSize(12)
          .fontColor('#666666')

        Text(this.viewModel.playbackState.playingProgress)
          .fontSize(12)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      // 状态信息显示
      Row() {
        // 加载指示器
        if (this.viewModel.uiState.isLoading) {
          LoadingProgress()
            .width(16)
            .height(16)
            .margin({ right: 8 })
        }

        // 状态标签
        Text('状态: ')
          .fontSize(12)
          .fontColor('#666666')

        // 状态文本
        Text(this.viewModel.uiState.callBackInfo || '就绪')
          .fontSize(12)
          .fontColor(this.viewModel.uiState.hasError ? '#FF5722' : '#4CAF50')
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      // 歌曲打分结果显示
      Row() {
        Text('打分: ')
          .fontSize(12)
          .fontColor('#666666')

        Text(`当前行: ${this.viewModel.currentLineIndex + 1}/${this.viewModel.totalLines}`)
          .fontSize(12)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .margin({ right: 16 })

        Text(`当前行分数: ${this.viewModel.currentLineScore}`)
          .fontSize(12)
          .fontColor('#FF6B35')
          .fontWeight(FontWeight.Medium)
          .margin({ right: 16 })

        Text(`总分数: ${this.viewModel.totalScore}`)
          .fontSize(12)
          .fontColor('#4CAF50')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      // 权限请求按钮（仅在权限未授予时显示）
      if (!this.viewModel.uiState.hasError &&
        !this.viewModel.uiState.isLoading &&
      this.viewModel.uiState.callBackInfo.includes('权限')) {
        Row() {
          Button('重新授权')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#2196F3')
            .borderRadius(6)
            .padding({
              left: 16,
              right: 16,
              top: 6,
              bottom: 6
            })
            .onClick(() => {
              this.viewModel.retryInitialization();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 8,
      bottom: 8
    })
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ left: 16, right: 16, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ScoringInfoBuilder() {
    Column({ space: 8 }) {
      // 歌曲打分结果显示
      Row() {
        Text('歌曲打分: ')
          .fontSize(12)
          .fontColor('#666666')

        Text(`当前行: ${this.viewModel.currentLineIndex + 1}/${this.viewModel.totalLines}`)
          .fontSize(12)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
          .margin({ right: 16 })

        Text(`当前行分数: ${this.viewModel.currentLineScore}`)
          .fontSize(12)
          .fontColor('#FF6B35')
          .fontWeight(FontWeight.Medium)
          .margin({ right: 16 })

        Text(`总分数: ${this.viewModel.totalScore}`)
          .fontSize(12)
          .fontColor('#4CAF50')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(40)
    .padding({
      left: 16,
      right: 16,
      top: 8,
      bottom: 8
    })
    .backgroundColor('#F8F9FA')
    .borderRadius(8)
    .margin({ left: 16, right: 16, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  MainControlButtonsBuilder() {
    Row({ space: 8 }) {
      Button(this.viewModel.playbackState.isPlaying ? '暂停' : '播放')
        .fontSize(14)
        .backgroundColor(this.viewModel.playbackState.isPlaying ? '#FF9800' : '#4CAF50')
        .enabled(!this.viewModel.uiState.isLoading)
        .onClick(() => {
          if (this.viewModel.playbackState.isPlaying) {
            this.viewModel.pausePlayback();
          } else {
            this.viewModel.startPlayback();
          }
        })

      Button('停止')
        .fontSize(14)
        .backgroundColor('#F44336')
        .enabled(this.viewModel.playbackState.isPlaying)
        .onClick(() => {
          this.viewModel.stopPlayback();
        })

      Button('切歌')
        .fontSize(14)
        .backgroundColor('#2196F3')
        .enabled(!this.viewModel.uiState.isLoading)
        .onClick(() => {
          this.viewModel.switchToNext();
        })

    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  SecondaryControlButtonsBuilder() {
    Row({ space: 8 }) {
      Button('跳过前奏')
        .fontSize(14)
        .backgroundColor('#9C27B0')
        .enabled(!this.viewModel.uiState.isLoading && this.viewModel.songInfo.hasLyrics())
        .onClick(() => {
          this.viewModel.skipIntro();
        })

      Button(this.viewModel.playbackState.isOriginalTrack ? '伴唱' : '原唱')
        .fontSize(14)
        .backgroundColor('#607D8B')
        .enabled(!this.viewModel.uiState.isLoading)
        .onClick(() => {
          this.viewModel.toggleOriginalTrack();
        })

      Button('切换Vendor')
        .fontSize(14)
        .backgroundColor('#795548')
        .enabled(!this.viewModel.uiState.isLoading)
        .onClick(() => {
          this.viewModel.switchServiceType();
        })

    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ControlButtonsBuilder() {
    Column({ space: 8 }) {
      // 主要控制按钮
      this.MainControlButtonsBuilder()

      // 次要控制按钮
      this.SecondaryControlButtonsBuilder()
    }
    .padding({ bottom: 8 })
  }

  @Builder
  VersionInfoBuilder() {
    Row() {
      Text(`version:${KaraokeView.getSdkVersion()}`)
        .fontSize(10)
        .fontColor('#999999')
        .opacity(0.7)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 4, bottom: 8 })
  }

  build() {
    Stack() {
      Column() {
        // 头部信息
        this.HeaderBuilder()

        // 评分视图区域
        Row() {
          this.ScoringViewBuilder()
        }
        .width('100%')
        .height(180)
        .margin({ bottom: 15 })

        // 歌词视图区域（纯净，无覆盖层）
        Row() {
          this.LyricsViewBuilder()
        }
        .width('100%')
        .height(260)
        .margin({ bottom: 10 })

        // 状态信息区域（独立区域）
        this.StatusBarBuilder()

        // 控制按钮区域
        this.ControlButtonsBuilder()

        // 版本信息
        this.VersionInfoBuilder()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
