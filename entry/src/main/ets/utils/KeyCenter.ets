import { BuildConfig } from './BuildConfig';
import { ExampleConstants } from './ExampleConstants';
import { ExampleLogUtils } from './ExmapleLogUtils';
import { HttpClient, HttpResponse } from './HttpClient';
import { RtmTokenBuilder } from '../token/RtmTokenBuilder2';
import { Role, RtcTokenBuilder } from '../token/RtcTokenBuilder2';

/**
 * Token generation response interface
 */
export interface TokenResponse {
  success: boolean;
  token?: string;
  error?: string;
}

/**
 * Token generation callback interface
 */
export interface TokenCallback {
  onTokenGenerated(response: TokenResponse): void;
}

/**
 * YinSuDa API response data structure
 */
interface YSDApiData {
  yinsuda_uid: string;
  token: string;
}

/**
 * YinSuDa API response structure
 */
interface YSDApiResponse {
  error: number;
  data: YSDApiData;
}

/**
 * YinSuDa token response interface
 */
export interface YSDTokenResponse {
  success: boolean;
  ysdUserId?: string;
  ysdToken?: string;
  error?: string;
}

/**
 * YinSuDa token callback interface
 */
export interface YSDTokenCallback {
  onYSDTokenGenerated(response: YSDTokenResponse): void;
}

/**
 * KeyCenter - Key and Token management center
 * Reference Android KeyCenter.kt implementation
 * Responsible for generating RTC Token and managing user ID, channel name, etc.
 */
export class KeyCenter {
  private static readonly TAG: string = ExampleConstants.APP_TAG + '-KeyCenter';
  private static readonly USER_MAX_UID: number = 10000;
  // Read configuration from BuildConfig (generated from local.properties at build time)
  public static readonly APP_ID: string = BuildConfig.APP_ID;
  private static readonly APP_CERTIFICATE: string = BuildConfig.APP_CERTIFICATE;
  // YinSuDa (Vendor2) configuration
  public static readonly VENDOR_2_APP_ID: string = BuildConfig.VENDOR_2_APP_ID;
  public static readonly VENDOR_2_APP_KEY: string = BuildConfig.VENDOR_2_APP_KEY;
  public static readonly VENDOR_2_TOKEN_HOST: string = BuildConfig.VENDOR_2_TOKEN_HOST;
  // Channel name
  private static CHANNEL_NAME: string = '';
  // User UID cache
  private static USER_RTC_UID: number = -1;

  /**
   * Get user UID
   * Generate a random one if not set
   */
  public static getUserUid(): number {
    if (KeyCenter.USER_RTC_UID === -1) {
      KeyCenter.USER_RTC_UID = Math.floor(Math.random() * KeyCenter.USER_MAX_UID);
    }
    return KeyCenter.USER_RTC_UID;
  }

  /**
   * Generate random channel name
   */
  public static getChannelName(): string {
    if (KeyCenter.CHANNEL_NAME === '') {
      const timestamp = Date.now();
      const random = Math.floor(Math.random() * 1000);
      KeyCenter.CHANNEL_NAME = `Karaoke_${timestamp}_${random}`;
    }
    return KeyCenter.CHANNEL_NAME;
  }

  /**
   * Get configuration information (for debugging)
   */
  public static getConfigInfo(): Record<string, Object> {
    return BuildConfig.getConfigInfo();
  }

  /**
   * Get YinSuDa (Vendor2) user ID and token
   * @param uid User ID, used to construct request URL
   * @param callback Callback interface
   */
  public static async getYSDToken(uid: number, callback: YSDTokenCallback): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: uid=${uid}`)

    try {
      // Construct request URL
      const requestUrl = `${KeyCenter.VENDOR_2_TOKEN_HOST}${uid}`;
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: requestUrl=${requestUrl}`)

      // Send GET request
      const requestHeaders: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };
      const response: HttpResponse = await HttpClient.get(requestUrl, requestHeaders);

      if (response.success && response.data) {
        ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: response=${response.data}`)

        try {
          const ysdResponse: YSDApiResponse = JSON.parse(response.data);

          if (ysdResponse.error === 0 && ysdResponse.data) {
            ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: YSD API response: ${ysdResponse}`)

            callback.onYSDTokenGenerated({
              success: true,
              ysdUserId: ysdResponse.data.yinsuda_uid,
              ysdToken: ysdResponse.data.token
            });
          } else {
            ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: YSD API error: ${ysdResponse.error}`)
            callback.onYSDTokenGenerated({
              success: false,
              error: `YSD API error: ${ysdResponse.error}`
            });
          }
        } catch (parseError) {
          ExampleLogUtils.logDebug(KeyCenter.TAG,
            `getYSDToken: Failed to parse YSD response: ${JSON.stringify(parseError)}`)
          callback.onYSDTokenGenerated({
            success: false,
            error: `Failed to parse YSD response: ${JSON.stringify(parseError)}`
          });
        }
      } else {
        ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: HTTP error: ${JSON.stringify(response.error)}`)
        callback.onYSDTokenGenerated({
          success: false,
          error: response.error || 'Unknown HTTP error'
        });
      }

    } catch (error) {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: Network error: ${JSON.stringify(error)}`)
      callback.onYSDTokenGenerated({
        success: false,
        error: `Network error: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * Generate RTC Token using RtcTokenBuilder2
   * @param channelName - Channel name
   * @param uid - User ID (number)
   * @param callback - Callback interface
   * @param role - User role (default: PUBLISHER)
   * @param tokenExpire - Token expiration in seconds (default: 24 hours)
   * @param privilegeExpire - Privilege expiration in seconds (default: 24 hours)
   */
  public static async getRtcToken(
    channelName: string,
    uid: number,
    callback: TokenCallback,
    role: Role = Role.PUBLISHER,
    tokenExpire: number = 24 * 60 * 60,
    privilegeExpire: number = 24 * 60 * 60
  ): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG,
      `getRtcToken: channel=${channelName}, uid=${uid}, role=${role}`);

    if (!KeyCenter.APP_CERTIFICATE || KeyCenter.APP_CERTIFICATE.trim() === '') {
      ExampleLogUtils.logError(KeyCenter.TAG, `getRtcToken: APP_CERTIFICATE not configured`);
      callback.onTokenGenerated({
        success: false,
        token: KeyCenter.APP_ID
      });
      return;
    }

    try {
      // Generate token using RtcTokenBuilder2
      const token: string = await RtcTokenBuilder.buildTokenWithUid(
        KeyCenter.APP_ID,
        KeyCenter.APP_CERTIFICATE,
        channelName,
        uid,
        role,
        tokenExpire,
        privilegeExpire
      );

      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtcToken: token generated successfully`);
      callback.onTokenGenerated({
        success: true,
        token: token
      });

    } catch (error) {
      ExampleLogUtils.logError(KeyCenter.TAG, `getRtcToken: error - ${JSON.stringify(error)}`);
      callback.onTokenGenerated({
        success: false,
        error: `Failed to generate RTC token: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * 使用RtmTokenBuilder生成RTM Token
   * 参考Agora官方Java实现，使用HTTP请求生成真正可用的token
   * @param userId 用户ID（字符串）
   * @param callback 回调接口
   */
  public static async getRtmToken(userId: string, callback: TokenCallback): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: userId=${userId}`)

    if (!KeyCenter.APP_CERTIFICATE || KeyCenter.APP_CERTIFICATE.trim() === '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: APP_CERTIFICATE not configured`)
      callback.onTokenGenerated({
        success: false,
        token: KeyCenter.APP_ID
      });
      return;
    }

    try {
      // 使用RtmTokenBuilder生成token（异步）
      const token: string = await RtmTokenBuilder.buildToken(
        KeyCenter.APP_ID,
        KeyCenter.APP_CERTIFICATE,
        userId,
        24 * 60 * 60 // 默认24小时过期
      );

      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmTokenV2: token generated successfully`)
      callback.onTokenGenerated({
        success: true,
        token: token
      });

    } catch (error) {
      ExampleLogUtils.logError(KeyCenter.TAG, `getRtmTokenV2: error - ${JSON.stringify(error)}`)
      callback.onTokenGenerated({
        success: false,
        error: `Failed to generate RTM token: ${JSON.stringify(error)}`
      });
    }
  }
}
