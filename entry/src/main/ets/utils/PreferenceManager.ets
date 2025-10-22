import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Constants, MusicContentCenterVendorId } from '@shengwang/rtc-full';
import { ExampleConstants } from './ExampleConstants';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';

/**
 * Preference Manager
 * 类似 Android SharedPreferences 的配置管理工具类
 * 用于持久化保存应用配置
 */
export class PreferenceManager {
  private static readonly TAG = ExampleConstants.APP_TAG + 'PreferenceManager';
  private static readonly PREFERENCES_NAME = 'app_settings';
  private static instance: PreferenceManager | null = null;
  private preferencesInstance: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;
  // 配置键常量
  public static readonly KEY_VENDOR_TYPE = 'vendor_type';
  public static readonly KEY_LYRICS_TYPE = 'lyrics_type';
  // 默认值常量（使用 RTC SDK 定义的类型）
  public static readonly DEFAULT_VENDOR_TYPE = MusicContentCenterVendorId.DEFAULT;
  public static readonly DEFAULT_LYRICS_TYPE = Constants.LyricSourceType.XML

  private constructor() {
  }

  /**
   * 获取单例实例
   */
  static getInstance(): PreferenceManager {
    if (!PreferenceManager.instance) {
      PreferenceManager.instance = new PreferenceManager();
    }
    return PreferenceManager.instance;
  }

  /**
   * 初始化 Preferences
   * 必须在使用前调用，通常在 Ability onCreate 中调用
   */
  async initialize(context: common.UIAbilityContext): Promise<boolean> {
    try {
      this.context = context;
      this.preferencesInstance = await preferences.getPreferences(context, PreferenceManager.PREFERENCES_NAME);
      ExampleLogUtils.logDebug(PreferenceManager.TAG, 'PreferenceManager initialized successfully');
      return true;
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG,
        `Failed to initialize PreferenceManager: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 检查是否已初始化
   */
  isInitialized(): boolean {
    return this.preferencesInstance !== null;
  }

  /**
   * 保存字符串值
   */
  async putString(key: string, value: string): Promise<boolean> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return false;
    }

    try {
      await this.preferencesInstance.put(key, value);
      await this.preferencesInstance.flush();
      ExampleLogUtils.logDebug(PreferenceManager.TAG, `Saved string: ${key} = ${value}`);
      return true;
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to save string ${key}: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 获取字符串值
   */
  async getString(key: string, defaultValue: string = ''): Promise<string> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return defaultValue;
    }

    try {
      const value = await this.preferencesInstance.get(key, defaultValue);
      return value as string;
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to get string ${key}: ${JSON.stringify(error)}`);
      return defaultValue;
    }
  }

  /**
   * 保存数字值
   */
  async putNumber(key: string, value: number): Promise<boolean> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return false;
    }

    try {
      await this.preferencesInstance.put(key, value);
      await this.preferencesInstance.flush();
      ExampleLogUtils.logDebug(PreferenceManager.TAG, `Saved number: ${key} = ${value}`);
      return true;
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to save number ${key}: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 获取数字值
   */
  async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return defaultValue;
    }

    try {
      const value = await this.preferencesInstance.get(key, defaultValue);
      return value as number;
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to get number ${key}: ${JSON.stringify(error)}`);
      return defaultValue;
    }
  }

  /**
   * 保存布尔值
   */
  async putBoolean(key: string, value: boolean): Promise<boolean> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return false;
    }

    try {
      await this.preferencesInstance.put(key, value);
      await this.preferencesInstance.flush();
      ExampleLogUtils.logDebug(PreferenceManager.TAG, `Saved boolean: ${key} = ${value}`);
      return true;
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to save boolean ${key}: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 获取布尔值
   */
  async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return defaultValue;
    }

    try {
      const value = await this.preferencesInstance.get(key, defaultValue);
      return value as boolean;
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to get boolean ${key}: ${JSON.stringify(error)}`);
      return defaultValue;
    }
  }

  /**
   * 删除指定键
   */
  async remove(key: string): Promise<boolean> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return false;
    }

    try {
      await this.preferencesInstance.delete(key);
      await this.preferencesInstance.flush();
      ExampleLogUtils.logDebug(PreferenceManager.TAG, `Removed key: ${key}`);
      return true;
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to remove ${key}: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 检查键是否存在
   */
  async has(key: string): Promise<boolean> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return false;
    }

    try {
      return await this.preferencesInstance.has(key);
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to check key ${key}: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 清空所有配置
   */
  async clear(): Promise<boolean> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return false;
    }

    try {
      await this.preferencesInstance.clear();
      await this.preferencesInstance.flush();
      ExampleLogUtils.logDebug(PreferenceManager.TAG, 'Cleared all preferences');
      return true;
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to clear preferences: ${JSON.stringify(error)}`);
      return false;
    }
  }

  /**
   * 获取所有键
   */
  async getAllKeys(): Promise<string[]> {
    if (!this.preferencesInstance) {
      ExampleLogUtils.logWarn(PreferenceManager.TAG, 'PreferenceManager not initialized');
      return [];
    }

    try {
      // 注意：Preferences API 可能没有直接获取所有键的方法
      // 这里可以维护一个键的列表或使用其他方式
      return [];
    } catch (error) {
      ExampleLogUtils.logError(PreferenceManager.TAG, `Failed to get all keys: ${JSON.stringify(error)}`);
      return [];
    }
  }

  // ==================== 业务相关的便捷方法 ====================

  /**
   * 保存 Vendor 类型
   */
  async saveVendorType(vendorType: number): Promise<boolean> {
    return await this.putNumber(PreferenceManager.KEY_VENDOR_TYPE, vendorType);
  }

  /**
   * 获取 Vendor 类型
   */
  async getVendorType(): Promise<number> {
    return await this.getNumber(PreferenceManager.KEY_VENDOR_TYPE, PreferenceManager.DEFAULT_VENDOR_TYPE);
  }

  /**
   * 保存歌词类型
   */
  async saveLyricsType(lyricsType: number): Promise<boolean> {
    return await this.putNumber(PreferenceManager.KEY_LYRICS_TYPE, lyricsType);
  }

  /**
   * 获取歌词类型
   */
  async getLyricsType(): Promise<number> {
    return await this.getNumber(PreferenceManager.KEY_LYRICS_TYPE, PreferenceManager.DEFAULT_LYRICS_TYPE);
  }
}

/**
 * 导出单例实例
 */
export const preferenceManager = PreferenceManager.getInstance();
