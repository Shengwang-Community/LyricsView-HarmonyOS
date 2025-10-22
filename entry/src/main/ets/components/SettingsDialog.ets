import { Constants, SettingsConfig, VendorType } from '../models/SettingsConfig';
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

  aboutToAppear() {
    // 加载当前设置
    this.selectedVendorId = SettingsConfig.getVendorId();
    this.selectedLyricsType = SettingsConfig.getLyricsType();
    this.updateAvailableLyricsTypes();
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
  private handleConfirm(): void {
    // 调用回调通知外部配置已更改
    if (this.onConfirm) {
      this.onConfirm();
    }

    // 关闭对话框
    this.controller.close();
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

      // Karaoke 设置区域
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

      // 底部确定按钮
      Button('确定')
        .type(ButtonType.Normal)
        .fontSize(14)
        .height(44)
        .width('100%')
        .backgroundColor('#4CAF50')
        .fontColor('#FFFFFF')
        .margin({ top: 24 })
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
