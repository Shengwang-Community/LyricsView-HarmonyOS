import { Constants, SettingsConfig, VendorType } from '../models/SettingsConfig';
import { LyricsViewConfig } from '../models/LyricsViewConfig';
import { ScoringViewConfig } from '../models/ScoringViewConfig';
import { promptAction } from '@kit.ArkUI';

/**
 * 设置对话框组件
 */
@CustomDialog
export struct SettingsDialog {
  controller: CustomDialogController;
  onConfirm?: () => void; // 确定按钮回调
  onClearCache?: () => void;
  @State private selectedVendorId: VendorType = VendorType.DEFAULT;
  @State private selectedLyricsType: Constants.LyricSourceType = Constants.LyricSourceType.XML;
  @State private availableLyricsTypes: Constants.LyricSourceType[] = [];
  @State private selectedScoreLevel: number = 5; // 打分等级 1-5
  // LyricsView 配置
  @State private lyricsConfig: LyricsViewConfig = new LyricsViewConfig();
  // ScoringView 配置
  @State private scoringConfig: ScoringViewConfig = new ScoringViewConfig();
  @State private currentTabIndex: number = 0; // 0: Karaoke设置, 1: 歌词视图设置, 2: 打分视图设置
  // 用于强制刷新 UI 的时间戳
  @State private refreshTimestamp: number = 0;
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    // 加载当前设置
    this.selectedVendorId = SettingsConfig.getVendorId();
    this.selectedLyricsType = SettingsConfig.getLyricsType();
    this.selectedScoreLevel = SettingsConfig.getScoreLevel();
    this.updateAvailableLyricsTypes();

    // 加载 LyricsView 配置
    this.lyricsConfig = SettingsConfig.getLyricsViewConfig();

    // 加载 ScoringView 配置
    this.scoringConfig = SettingsConfig.getScoringViewConfig();
  }

  /**
   * 更新可用的歌词类型
   */
  private updateAvailableLyricsTypes(): void {
    this.availableLyricsTypes = SettingsConfig.getAvailableLyricsTypes(this.selectedVendorId);

    // 如果当前选中的歌词类型不可用，选择第一个可用的
    if (!this.availableLyricsTypes.includes(this.selectedLyricsType)) {
      this.selectedLyricsType = this.availableLyricsTypes[0];
    }
  }

  /**
   * Vendor 类型改变 - 立即保存
   */
  private async onVendorIdChange(vendorId: VendorType): Promise<void> {
    this.selectedVendorId = vendorId;
    this.updateAvailableLyricsTypes();

    // 立即保存到配置
    await SettingsConfig.setVendorId(vendorId);
  }

  /**
   * 歌词类型改变 - 立即保存
   */
  private async onLyricsTypeChange(lyricsType: Constants.LyricSourceType): Promise<void> {
    this.selectedLyricsType = lyricsType;

    // 立即保存到配置
    await SettingsConfig.setLyricsType(lyricsType);
  }

  /**
   * 打分等级改变 - 立即保存
   */
  private async onScoreLevelChange(level: number): Promise<void> {
    this.selectedScoreLevel = level;

    // 立即保存到配置
    await SettingsConfig.setScoreLevel(level);
  }

  /**
   * 清空缓存
   */
  private async clearCache(): Promise<void> {
    try {
      // 调用清空缓存回调
      if (this.onClearCache) {
        this.onClearCache();
      }

      promptAction.showToast({
        message: '缓存已清空',
        duration: 2000
      });

    } catch (error) {
      promptAction.showToast({
        message: '清空缓存失败',
        duration: 2000
      });
    }
  }

  /**
   * 确定按钮 - 关闭对话框并触发回调
   */
  private async handleConfirm(): Promise<void> {
    // 保存 LyricsView 配置
    await SettingsConfig.updateLyricsViewConfig(this.lyricsConfig);

    // 保存 ScoringView 配置
    await SettingsConfig.updateScoringViewConfig(this.scoringConfig);

    // 调用回调通知外部配置已更改
    if (this.onConfirm) {
      this.onConfirm();
    }

    // 关闭对话框
    this.controller.close();
  }

  /**
   * 重置 LyricsView 配置
   */
  private async resetLyricsViewConfig(): Promise<void> {
    try {
      await SettingsConfig.resetLyricsViewConfig();
      // 重新加载配置并强制触发 UI 更新
      const newConfig = SettingsConfig.getLyricsViewConfig();
      // 创建新对象以触发 @State 更新
      this.lyricsConfig = newConfig.copy();
      // 更新时间戳以强制刷新 UI 组件
      this.refreshTimestamp = Date.now();

      promptAction.showToast({
        message: '歌词视图配置已重置',
        duration: 2000
      });
    } catch (error) {
      promptAction.showToast({
        message: '重置配置失败',
        duration: 2000
      });
    }
  }

  /**
   * 重置 ScoringView 配置
   */
  private async resetScoringViewConfig(): Promise<void> {
    try {
      await SettingsConfig.resetScoringViewConfig();
      // 重新加载配置并强制触发 UI 更新
      const newConfig = SettingsConfig.getScoringViewConfig();
      // 创建新对象以触发 @State 更新
      this.scoringConfig = newConfig.copy();
      // 更新时间戳以强制刷新 UI 组件
      this.refreshTimestamp = Date.now();

      promptAction.showToast({
        message: '打分视图配置已重置',
        duration: 2000
      });
    } catch (error) {
      promptAction.showToast({
        message: '重置配置失败',
        duration: 2000
      });
    }
  }

  @Builder
  SettingItemTitle(title: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor('#333333')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  ColorPickerItem(label: string, getCurrentColor: () => string, colorOptions: string[],
    colorLabels: string[], onChange: (color: string) => void) {
    Column() {
      Row() {
        Text(label)
          .fontSize(12)
          .fontColor('#666666')
          .layoutWeight(1)

        // 颜色预览块
        Column()
          .width(28)
          .height(28)
          .backgroundColor(getCurrentColor())
          .borderRadius(4)
          .border({ width: 1, color: '#CCCCCC' })
          .margin({ right: 8 })

        // 下拉选择器
        Select(colorLabels.map((colorLabel: string, index: number): SelectOption => {
          return { value: colorLabel };
        }))
          .key(`${label}_${getCurrentColor()}_${this.refreshTimestamp}`)
          .selected(colorOptions.indexOf(getCurrentColor()))
          .value(colorLabels[colorOptions.indexOf(getCurrentColor())])
          .font({ size: 12 })
          .fontColor('#333333')
          .selectedOptionFont({ size: 12 })
          .optionFont({ size: 12 })
          .width(120)
          .height(32)
          .onSelect((index: number) => {
            onChange(colorOptions[index]);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  NumberInputItem(label: string, value: number, onChange: (value: number) => void, isDecimal: boolean = false) {
    Column() {
      Row() {
        Text(label)
          .fontSize(12)
          .fontColor('#666666')
          .layoutWeight(1)

        TextInput({
          text: isDecimal ? value.toFixed(2) : value.toString()
        })
          .key(`${label}_${value}_${this.refreshTimestamp}`)
          .width(80)
          .height(32)
          .fontSize(12)
          .type(isDecimal ? InputType.NUMBER_DECIMAL : InputType.Number)
          .onChange((value: string) => {
            const num = parseFloat(value);
            if (!isNaN(num)) {
              onChange(num);
            }
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  SwitchItem(label: string, checked: boolean, onChange: (checked: boolean) => void) {
    Column() {
      Row() {
        Text(label)
          .fontSize(12)
          .fontColor('#666666')
          .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: checked })
          .key(`${label}_${checked}_${this.refreshTimestamp}`)
          .onChange((isOn: boolean) => {
            onChange(isOn);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  RadioGroupItem(label: string, options: string[], getSelectedIndex: () => number, onChange: (index: number) => void) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#666666')
        .width('100%')
        .margin({ bottom: 8 })

      Row({ space: 8 }) {
        ForEach(options, (option: string, index: number) => {
          Button(option)
            .key(`${label}_${option}_${getSelectedIndex()}_${this.refreshTimestamp}`)
            .type(ButtonType.Normal)
            .fontSize(12)
            .height(32)
            .layoutWeight(1)
            .backgroundColor(getSelectedIndex() === index ? '#2196F3' : '#E0E0E0')
            .fontColor(getSelectedIndex() === index ? '#FFFFFF' : '#666666')
            .onClick(() => {
              onChange(index);
            })
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  KaraokeSettingsPanel() {
    Column() {
      Text('Karaoke 设置')
        .fontSize(16)
        .fontColor('#666666')
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 12 })

      // Vendor 类型选择
      Column() {
        this.SettingItemTitle('Vendor 类型')

        Row({ space: 12 }) {
          Button(SettingsConfig.getVendorName(VendorType.DEFAULT))
            .type(ButtonType.Normal)
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .backgroundColor(this.selectedVendorId === VendorType.DEFAULT ? '#2196F3' : '#E0E0E0')
            .fontColor(this.selectedVendorId === VendorType.DEFAULT ? '#FFFFFF' : '#666666')
            .onClick(() => {
              this.onVendorIdChange(VendorType.DEFAULT);
            })

          Button(SettingsConfig.getVendorName(VendorType.VENDOR_2))
            .type(ButtonType.Normal)
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .backgroundColor(this.selectedVendorId === VendorType.VENDOR_2 ? '#2196F3' : '#E0E0E0')
            .fontColor(this.selectedVendorId === VendorType.VENDOR_2 ? '#FFFFFF' : '#666666')
            .onClick(() => {
              this.onVendorIdChange(VendorType.VENDOR_2);
            })
        }
        .width('100%')
        .padding({ left: 8, right: 8 })
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .borderRadius(8)
      .backgroundColor('#F5F5F5')
      .margin({ bottom: 12 })

      // 歌词类型选择
      Column() {
        this.SettingItemTitle('歌词类型')

        Row({ space: 12 }) {
          Button(SettingsConfig.getLyricsTypeName(Constants.LyricSourceType.XML))
            .type(ButtonType.Normal)
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .backgroundColor(this.selectedLyricsType === Constants.LyricSourceType.XML ? '#2196F3' : '#E0E0E0')
            .fontColor(this.selectedLyricsType === Constants.LyricSourceType.XML ? '#FFFFFF' : '#666666')
            .enabled(this.availableLyricsTypes.includes(Constants.LyricSourceType.XML))
            .opacity(this.availableLyricsTypes.includes(Constants.LyricSourceType.XML) ? 1.0 : 0.3)
            .onClick(() => {
              if (this.availableLyricsTypes.includes(Constants.LyricSourceType.XML)) {
                this.onLyricsTypeChange(Constants.LyricSourceType.XML);
              }
            })

          Button(SettingsConfig.getLyricsTypeName(Constants.LyricSourceType.LRC))
            .type(ButtonType.Normal)
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .backgroundColor(this.selectedLyricsType === Constants.LyricSourceType.LRC ? '#2196F3' : '#E0E0E0')
            .fontColor(this.selectedLyricsType === Constants.LyricSourceType.LRC ? '#FFFFFF' : '#666666')
            .enabled(this.availableLyricsTypes.includes(Constants.LyricSourceType.LRC))
            .opacity(this.availableLyricsTypes.includes(Constants.LyricSourceType.LRC) ? 1.0 : 0.3)
            .onClick(() => {
              if (this.availableLyricsTypes.includes(Constants.LyricSourceType.LRC)) {
                this.onLyricsTypeChange(Constants.LyricSourceType.LRC);
              }
            })

          Button(SettingsConfig.getLyricsTypeName(Constants.LyricSourceType.KRC))
            .type(ButtonType.Normal)
            .fontSize(14)
            .height(36)
            .layoutWeight(1)
            .backgroundColor(this.selectedLyricsType === Constants.LyricSourceType.KRC ? '#2196F3' : '#E0E0E0')
            .fontColor(this.selectedLyricsType === Constants.LyricSourceType.KRC ? '#FFFFFF' : '#666666')
            .enabled(this.availableLyricsTypes.includes(Constants.LyricSourceType.KRC))
            .opacity(this.availableLyricsTypes.includes(Constants.LyricSourceType.KRC) ? 1.0 : 0.3)
            .onClick(() => {
              if (this.availableLyricsTypes.includes(Constants.LyricSourceType.KRC)) {
                this.onLyricsTypeChange(Constants.LyricSourceType.KRC);
              }
            })
        }
        .width('100%')
        .padding({ left: 8, right: 8 })
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .borderRadius(8)
      .backgroundColor('#F5F5F5')
      .margin({ bottom: 12 })

      // 打分等级选择
      Column() {
        this.SettingItemTitle('打分等级')

        Row({ space: 8 }) {
          ForEach([1, 2, 3, 4, 5], (level: number) => {
            Button(`${level}`)
              .type(ButtonType.Normal)
              .fontSize(14)
              .height(36)
              .layoutWeight(1)
              .backgroundColor(this.selectedScoreLevel === level ? '#2196F3' : '#E0E0E0')
              .fontColor(this.selectedScoreLevel === level ? '#FFFFFF' : '#666666')
              .onClick(() => {
                this.onScoreLevelChange(level);
              })
          })
        }
        .width('100%')
        .padding({ left: 8, right: 8 })
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .borderRadius(8)
      .backgroundColor('#F5F5F5')
      .margin({ bottom: 12 })

      // 清空缓存按钮
      Button('清空歌曲缓存')
        .type(ButtonType.Normal)
        .fontSize(14)
        .height(40)
        .width('100%')
        .backgroundColor('#FF9800')
        .fontColor('#FFFFFF')
        .margin({ top: 4 })
        .onClick(() => {
          this.clearCache();
        })
    }
    .width('100%')
  }

  @Builder
  LyricsViewSettingsPanel() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        // 隐藏的刷新触发器
        Text(`${this.refreshTimestamp}`)
          .width(0)
          .height(0)
          .opacity(0)

        // ========== 颜色配置 ==========
        Column() {
          this.SettingItemTitle('颜色配置')

          this.ColorPickerItem('背景颜色', () => this.lyricsConfig.viewBackgroundColor,
            ['#CE93D8', '#424242', '#1E88E5'],
            ['紫色', '深灰', '蓝色'], (color: string) => {
              this.lyricsConfig.viewBackgroundColor = color;
            })

          this.ColorPickerItem('当前行文本颜色', () => this.lyricsConfig.currentLineTextColor,
            ['#FFFF00', '#FFFFFF', '#00E5FF'],
            ['黄色', '白色', '青色'], (color: string) => {
              this.lyricsConfig.currentLineTextColor = color;
            })

          this.ColorPickerItem('当前行高亮颜色', () => this.lyricsConfig.currentLineHighlightedTextColor,
            ['#FFF44336', '#00E5FF', '#76FF03'],
            ['红色', '青色', '亮绿'], (color: string) => {
              this.lyricsConfig.currentLineHighlightedTextColor = color;
            })

          this.ColorPickerItem('已唱歌词颜色', () => this.lyricsConfig.previousLineTextColor,
            ['#FFFFFF', '#FFAB91', '#CE93D8'],
            ['白色', '浅橙', '浅紫'], (color: string) => {
              this.lyricsConfig.previousLineTextColor = color;
            })

          this.ColorPickerItem('未唱歌词颜色', () => this.lyricsConfig.upcomingLineTextColor,
            ['#FFFFFF', '#80DEEA', '#A5D6A7'],
            ['白色', '浅蓝', '浅绿'], (color: string) => {
              this.lyricsConfig.upcomingLineTextColor = color;
            })

          this.ColorPickerItem('前奏指示器颜色', () => this.lyricsConfig.preludeEndPositionIndicatorColor,
            ['#FF6B35', '#F44336', '#2196F3'],
            ['橙色', '红色', '蓝色'], (color: string) => {
              this.lyricsConfig.preludeEndPositionIndicatorColor = color;
            })
        }
        .width('100%')
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')

        // ========== 文本大小配置 ==========
        Column() {
          this.SettingItemTitle('文本大小配置')

          this.NumberInputItem('普通文本大小', this.lyricsConfig.textSize, (value: number) => {
            this.lyricsConfig.textSize = value;
          })

          this.NumberInputItem('当前行文本大小', this.lyricsConfig.currentLineTextSize, (value: number) => {
            this.lyricsConfig.currentLineTextSize = value;
          })
        }
        .width('100%')
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')

        // ========== 间距配置 ==========
        Column() {
          this.SettingItemTitle('间距配置')

          this.NumberInputItem('行间距', this.lyricsConfig.lineSpacing, (value: number) => {
            this.lyricsConfig.lineSpacing = value;
          })

          this.NumberInputItem('顶部边距', this.lyricsConfig.paddingTop, (value: number) => {
            this.lyricsConfig.paddingTop = value;
          })

          this.NumberInputItem('前奏指示器顶部边距', this.lyricsConfig.preludeEndPositionIndicatorPaddingTop,
            (value: number) => {
              this.lyricsConfig.preludeEndPositionIndicatorPaddingTop = value;
            })

          this.NumberInputItem('前奏指示器半径', this.lyricsConfig.preludeEndPositionIndicatorRadius,
            (value: number) => {
              this.lyricsConfig.preludeEndPositionIndicatorRadius = value;
            })
        }
        .width('100%')
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')

        // ========== 功能开关 ==========
        Column() {
          this.SettingItemTitle('功能开关')

          this.SwitchItem('启用自动换行', this.lyricsConfig.enableLineWrap, (checked: boolean) => {
            this.lyricsConfig.enableLineWrap = checked;
          })

          this.SwitchItem('启用拖拽', this.lyricsConfig.enableDragging, (checked: boolean) => {
            this.lyricsConfig.enableDragging = checked;
          })

          this.SwitchItem('启用透明度渐变', this.lyricsConfig.enableOpacityEffect, (checked: boolean) => {
            this.lyricsConfig.enableOpacityEffect = checked;
          })

          this.SwitchItem('显示已唱歌词', this.lyricsConfig.enablePreviousLines, (checked: boolean) => {
            this.lyricsConfig.enablePreviousLines = checked;
          })

          this.SwitchItem('显示未唱歌词', this.lyricsConfig.enableUpcomingLines, (checked: boolean) => {
            this.lyricsConfig.enableUpcomingLines = checked;
          })

          this.SwitchItem('显示前奏指示器', this.lyricsConfig.enablePreludeEndPositionIndicator, (checked: boolean) => {
            this.lyricsConfig.enablePreludeEndPositionIndicator = checked;
          })
        }
        .width('100%')
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')

        // ========== 其他配置 ==========
        Column() {
          this.SettingItemTitle('其他配置')

          this.RadioGroupItem('文本对齐方式', ['居中', '居左', '居右'], () => this.lyricsConfig.textGravity,
            (index: number) => {
              this.lyricsConfig.textGravity = index;
            })
        }
        .width('100%')
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')

        // 重置按钮
        Button('重置为默认配置')
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(40)
          .width('100%')
          .backgroundColor('#FF5722')
          .fontColor('#FFFFFF')
          .margin({ top: 8 })
          .onClick(() => {
            this.resetLyricsViewConfig();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  @Builder
  ScoringViewSettingsPanel() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        // 隐藏的刷新触发器
        Text(`${this.refreshTimestamp}`)
          .width(0)
          .height(0)
          .opacity(0)

        // 标题
        this.SettingItemTitle('打分视图配置')

        // ===== 颜色配置部分 =====
        Column({ space: 12 }) {
          // 视图背景颜色
          this.ColorPickerItem('视图背景颜色', () => this.scoringConfig.viewBackgroundColor,
            ['#ffffbb33', '#ffff6b6b', '#ff4ecdc4'], ['默认黄', '红色', '青色'],
            (color: string) => {
              this.scoringConfig.viewBackgroundColor = color;
            })

          // 导航线颜色
          this.ColorPickerItem('导航线颜色', () => this.scoringConfig.leadingLinesColor,
            ['#4DFFFFFF', '#4D00FF00', '#4DFF0000'], ['默认白', '绿色', '红色'],
            (color: string) => {
              this.scoringConfig.leadingLinesColor = color;
            })

          // 音高指示器颜色
          this.ColorPickerItem('音高指示器颜色', () => this.scoringConfig.pitchIndicatorColor,
            ['#F0F0F0F0', '#F0FFD700', '#F0FF1493'], ['默认白', '金色', '粉色'],
            (color: string) => {
              this.scoringConfig.pitchIndicatorColor = color;
            })

          // 本地音高指示器颜色
          this.ColorPickerItem('本地音高指示器颜色', () => this.scoringConfig.localPitchIndicatorColor,
            ['#F0F0F0F0', '#F00000FF', '#F0FF6347'], ['默认白', '蓝色', '番茄色'],
            (color: string) => {
              this.scoringConfig.localPitchIndicatorColor = color;
            })

          // 参考音高条默认颜色
          this.ColorPickerItem('参考音高条默认颜色', () => this.scoringConfig.refPitchStickDefaultColor,
            ['#99FFFFFF', '#99CCCCCC', '#9900FFFF'], ['默认白', '灰色', '青色'],
            (color: string) => {
              this.scoringConfig.refPitchStickDefaultColor = color;
            })

          // 高亮音高条颜色
          this.ColorPickerItem('高亮音高条颜色', () => this.scoringConfig.highlightedPitchStickColor,
            ['#FFF44336', '#FF4CAF50', '#FFFFEB3B'], ['默认红', '绿色', '黄色'],
            (color: string) => {
              this.scoringConfig.highlightedPitchStickColor = color;
            })
        }

        // ===== 尺寸配置部分 =====
        Column({ space: 12 }) {
          this.SettingItemTitle('尺寸配置')

          // 导航线高度
          this.NumberInputItem('导航线高度', this.scoringConfig.leadingLinesHeight, (value: number) => {
            this.scoringConfig.leadingLinesHeight = value;
          })

          // 音高指示器宽度
          this.NumberInputItem('音高指示器宽度', this.scoringConfig.pitchIndicatorWidth, (value: number) => {
            this.scoringConfig.pitchIndicatorWidth = value;
          })

          // 本地音高指示器半径
          this.NumberInputItem('本地音高指示器半径', this.scoringConfig.localPitchIndicatorRadius, (value: number) => {
            this.scoringConfig.localPitchIndicatorRadius = value;
          })

          // 音高条高度
          this.NumberInputItem('音高条高度', this.scoringConfig.pitchStickHeight, (value: number) => {
            this.scoringConfig.pitchStickHeight = value;
          })

          // 音高条圆角半径
          this.NumberInputItem('音高条圆角半径', this.scoringConfig.pitchStickRadius, (value: number) => {
            this.scoringConfig.pitchStickRadius = value;
          })
        }

        // ===== 行为配置部分 =====
        Column({ space: 12 }) {
          this.SettingItemTitle('行为配置')

          // 初始分数
          this.NumberInputItem('初始分数', this.scoringConfig.initialScore, (value: number) => {
            this.scoringConfig.initialScore = value;
          })

          // 每毫秒移动像素数
          this.NumberInputItem('每毫秒移动像素数', this.scoringConfig.movingPixelsPerMs, (value: number) => {
            this.scoringConfig.movingPixelsPerMs = value;
          }, true)

          // 命中分数阈值
          this.NumberInputItem('命中分数阈值 (0-1)', this.scoringConfig.hitScoreThreshold, (value: number) => {
            this.scoringConfig.hitScoreThreshold = value;
          }, true)

          // 起点水平偏移比例
          this.NumberInputItem('起点水平偏移比例 (0-1)', this.scoringConfig.startPointHorizontalBias,
            (value: number) => {
              this.scoringConfig.startPointHorizontalBias = value;
            }, true)

          // 是否启用粒子效果
          this.SwitchItem('启用粒子效果', this.scoringConfig.enableParticleEffect, (checked: boolean) => {
            this.scoringConfig.enableParticleEffect = checked;
          })
        }

        // 重置按钮
        Button('重置为默认值')
          .type(ButtonType.Normal)
          .fontSize(14)
          .width('100%')
          .backgroundColor('#FF5722')
          .fontColor('#FFFFFF')
          .margin({ top: 8 })
          .onClick(() => {
            this.resetScoringViewConfig();
          })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  build() {
    Column() {
      // 标题
      Row() {
        Text('设置')
          .fontSize(18)
          .fontColor('#333333')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ bottom: 16 })

      // 标签页切换
      Row({ space: 8 }) {
        Button('基础设置')
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(36)
          .layoutWeight(1)
          .backgroundColor(this.currentTabIndex === 0 ? '#2196F3' : '#E0E0E0')
          .fontColor(this.currentTabIndex === 0 ? '#FFFFFF' : '#666666')
          .onClick(() => {
            this.currentTabIndex = 0;
          })

        Button('歌词设置')
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(36)
          .layoutWeight(1)
          .backgroundColor(this.currentTabIndex === 1 ? '#2196F3' : '#E0E0E0')
          .fontColor(this.currentTabIndex === 1 ? '#FFFFFF' : '#666666')
          .onClick(() => {
            this.currentTabIndex = 1;
          })

        Button('打分设置')
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(36)
          .layoutWeight(1)
          .backgroundColor(this.currentTabIndex === 2 ? '#2196F3' : '#E0E0E0')
          .fontColor(this.currentTabIndex === 2 ? '#FFFFFF' : '#666666')
          .onClick(() => {
            this.currentTabIndex = 2;
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 内容区域
      Column() {
        if (this.currentTabIndex === 0) {
          this.KaraokeSettingsPanel()
        } else if (this.currentTabIndex === 1) {
          this.LyricsViewSettingsPanel()
        } else {
          this.ScoringViewSettingsPanel()
        }
      }
      .width('100%')
      .height(400)

      // 底部确定按钮
      Button('确定')
        .type(ButtonType.Normal)
        .fontSize(14)
        .height(44)
        .width('100%')
        .backgroundColor('#4CAF50')
        .fontColor('#FFFFFF')
        .margin({ top: 16 })
        .onClick(() => {
          this.handleConfirm();
        })
    }
    .padding(20)
    .width('90%')
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }
}
