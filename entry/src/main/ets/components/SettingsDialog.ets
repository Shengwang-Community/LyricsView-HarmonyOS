import { Constants, SettingsConfig, VendorType } from '../models/SettingsConfig';
import { LyricsViewConfig } from '../models/LyricsViewConfig';
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
  // LyricsView 配置
  @State private lyricsConfig: LyricsViewConfig = new LyricsViewConfig();
  @State private currentTabIndex: number = 0; // 0: Karaoke设置, 1: 歌词视图设置
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    // 加载当前设置
    this.selectedVendorId = SettingsConfig.getVendorId();
    this.selectedLyricsType = SettingsConfig.getLyricsType();
    this.updateAvailableLyricsTypes();

    // 加载 LyricsView 配置
    this.lyricsConfig = SettingsConfig.getLyricsViewConfig();
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
      this.lyricsConfig = SettingsConfig.getLyricsViewConfig();

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
  NumberInputItem(label: string, value: number, onChange: (value: number) => void) {
    Column() {
      Row() {
        Text(label)
          .fontSize(12)
          .fontColor('#666666')
          .layoutWeight(1)

        TextInput({ text: value.toString() })
          .width(80)
          .height(32)
          .fontSize(12)
          .type(InputType.Number)
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
        Button('Karaoke 设置')
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(36)
          .layoutWeight(1)
          .backgroundColor(this.currentTabIndex === 0 ? '#2196F3' : '#E0E0E0')
          .fontColor(this.currentTabIndex === 0 ? '#FFFFFF' : '#666666')
          .onClick(() => {
            this.currentTabIndex = 0;
          })

        Button('歌词视图设置')
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(36)
          .layoutWeight(1)
          .backgroundColor(this.currentTabIndex === 1 ? '#2196F3' : '#E0E0E0')
          .fontColor(this.currentTabIndex === 1 ? '#FFFFFF' : '#666666')
          .onClick(() => {
            this.currentTabIndex = 1;
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 内容区域
      Column() {
        if (this.currentTabIndex === 0) {
          this.KaraokeSettingsPanel()
        } else {
          this.LyricsViewSettingsPanel()
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
