import { Constants, MusicContentCenterVendorId } from '@shengwang/rtc-full';
import { ExampleConstants } from '../utils/ExampleConstants';
import { preferenceManager } from '../utils/PreferenceManager';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';

/**
 * 设置配置类
 * 用于管理应用的各种设置项
 * 使用 PreferenceManager 进行持久化存储
 * 使用 RTC SDK 中的类型定义
 */
class SettingsConfigImpl {
  private readonly TAG = ExampleConstants.APP_TAG + 'SettingsConfig';
  // 当前配置（缓存在内存中，避免频繁读取 Preferences）
  private currentVendorId: MusicContentCenterVendorId = MusicContentCenterVendorId.DEFAULT;
  private currentLyricsType: Constants.LyricSourceType = Constants.LyricSourceType.XML;

  /**
   * 初始化设置配置
   * 从 PreferenceManager 加载已保存的配置
   */
  async initialize(): Promise<void> {
    try {
      // 确保 PreferenceManager 已初始化
      if (!preferenceManager.isInitialized()) {
        ExampleLogUtils.logWarn(SettingsConfig.TAG, 'PreferenceManager not initialized yet, using default values');
        return;
      }

      // 加载已保存的配置
      await this.loadSettings();

      ExampleLogUtils.logDebug(SettingsConfig.TAG,
        `Settings initialized: vendor=${this.currentVendorId}, lyrics=${this.currentLyricsType}`);
    } catch (error) {
      ExampleLogUtils.logError(SettingsConfig.TAG, `Failed to initialize settings: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 加载设置
   */
  private async loadSettings(): Promise<void> {
    try {
      // 从 PreferenceManager 加载 vendor 类型
      const vendorValue = await preferenceManager.getVendorType();
      this.currentVendorId = vendorValue as MusicContentCenterVendorId;

      // 从 PreferenceManager 加载歌词类型
      const lyricsValue = await preferenceManager.getLyricsType();
      this.currentLyricsType = lyricsValue;

      // 验证配置的合法性
      this.validateLyricsType();
    } catch (error) {
      ExampleLogUtils.logError(SettingsConfig.TAG, `Failed to load settings: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 歌词类型转换为字符串
   */
  private lyricsTypeToString(lyricsType: Constants.LyricSourceType): string {
    switch (lyricsType) {
      case Constants.LyricSourceType.XML:
        return 'xml';
      case Constants.LyricSourceType.LRC:
        return 'lrc';
      case Constants.LyricSourceType.KRC:
        return 'krc';
      default:
        return 'xml';
    }
  }

  /**
   * 验证歌词类型是否符合当前 vendor
   */
  private validateLyricsType(): void {
    const availableTypes = this.getAvailableLyricsTypes(this.currentVendorId);
    if (!availableTypes.includes(this.currentLyricsType)) {
      // 如果当前歌词类型不可用，设置为第一个可用类型
      this.currentLyricsType = availableTypes[0];
    }
  }

  /**
   * 获取当前 Vendor 类型
   */
  getVendorId(): MusicContentCenterVendorId {
    return this.currentVendorId;
  }

  /**
   * 设置 Vendor 类型
   */
  async setVendorId(vendorId: MusicContentCenterVendorId): Promise<void> {
    try {
      this.currentVendorId = vendorId;

      // 保存到 PreferenceManager
      await preferenceManager.saveVendorType(vendorId);

      // 验证并调整歌词类型
      this.validateLyricsType();
      await this.setLyricsType(this.currentLyricsType);

      ExampleLogUtils.logDebug(SettingsConfig.TAG, `Vendor type updated to: ${vendorId}`);
    } catch (error) {
      ExampleLogUtils.logError(SettingsConfig.TAG, `Failed to set vendor type: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 获取当前歌词类型
   */
  getLyricsType(): Constants.LyricSourceType {
    return this.currentLyricsType;
  }

  /**
   * 设置歌词类型
   */
  async setLyricsType(lyricsType: Constants.LyricSourceType): Promise<void> {
    // 检查歌词类型是否可用
    const availableTypes = this.getAvailableLyricsTypes(this.currentVendorId);
    if (!availableTypes.includes(lyricsType)) {
      ExampleLogUtils.logWarn(SettingsConfig.TAG,
        `Lyrics type ${lyricsType} not available for vendor ${this.currentVendorId}`);
      return;
    }

    try {
      this.currentLyricsType = lyricsType;

      await preferenceManager.saveLyricsType(this.currentLyricsType);

      ExampleLogUtils.logDebug(SettingsConfig.TAG, `Lyrics type updated to: ${lyricsType}`);
    } catch (error) {
      ExampleLogUtils.logError(SettingsConfig.TAG, `Failed to set lyrics type: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 获取指定 Vendor 可用的歌词类型
   */
  getAvailableLyricsTypes(vendorId: MusicContentCenterVendorId): Constants.LyricSourceType[] {
    switch (vendorId) {
      case MusicContentCenterVendorId.DEFAULT:
        // 音集协：支持 XML 和 LRC
        return [Constants.LyricSourceType.XML, Constants.LyricSourceType.LRC];
      case MusicContentCenterVendorId.VENDOR_2:
        // 音速达：只支持 KRC
        return [Constants.LyricSourceType.KRC];
      default:
        return [Constants.LyricSourceType.XML];
    }
  }

  /**
   * 获取 Vendor 类型名称
   */
  getVendorName(vendorId: MusicContentCenterVendorId): string {
    switch (vendorId) {
      case MusicContentCenterVendorId.DEFAULT:
        return '音集协';
      case MusicContentCenterVendorId.VENDOR_2:
        return '音速达';
      default:
        return '未知';
    }
  }

  /**
   * 获取歌词类型名称
   */
  getLyricsTypeName(lyricsType: Constants.LyricSourceType): string {
    switch (lyricsType) {
      case Constants.LyricSourceType.XML:
        return 'XML';
      case Constants.LyricSourceType.LRC:
        return 'LRC';
      case Constants.LyricSourceType.KRC:
        return 'KRC';
      default:
        return 'UNKNOWN';
    }
  }
}

// 导出单例
export const SettingsConfig = new SettingsConfigImpl();

// 为了向后兼容，导出 RTC SDK 的类型
export { MusicContentCenterVendorId as VendorType, Constants };

export type LyricsType = Constants.LyricSourceType;
