import { BuildConfig } from './BuildConfig';
import { ExampleConstants } from './ExampleConstants';
import { ExampleLogUtils } from './ExmapleLogUtils';
import { TokenHttpClient, TokenHttpResponse } from './TokenHttpClient';
import {
  ChannelProfileType,
  ClientRoleType,
  TokenGenerateCallback,
  TokenGenerateParams,
  TokenGenerateResponse,
  TokenGenerator,
  TokenType
} from './TokenGenerator';

/**
 * Token生成回调适配器类
 * 用于适配TokenCallback到TokenGenerateCallback
 */
class TokenCallbackAdapter implements TokenGenerateCallback {
  private callback: TokenCallback;

  constructor(callback: TokenCallback) {
    this.callback = callback;
  }

  onTokenGenerated(response: TokenGenerateResponse): void {
    this.callback.onTokenGenerated({
      success: response.success,
      token: response.token,
      error: response.error
    });
  }
}

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
 * Agora server token generation response
 */
interface AgoraTokenData {
  token: string;
  expire_time: number;
}

interface AgoraTokenResponse {
  code: number;
  message: string;
  data?: AgoraTokenData;
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
  public static readonly RTC_TOKEN: string = BuildConfig.RTC_TOKEN;
  public static readonly RTM_TOKEN: string = BuildConfig.RTM_TOKEN;
  // YinSuDa (Vendor2) configuration
  public static readonly VENDOR_2_APP_ID: string = BuildConfig.VENDOR_2_APP_ID;
  public static readonly VENDOR_2_APP_KEY: string = BuildConfig.VENDOR_2_APP_KEY;
  public static readonly VENDOR_2_TOKEN_HOST: string = BuildConfig.VENDOR_2_TOKEN_HOST;
  // Channel name
  public static readonly CHANNEL_NAME: string = BuildConfig.CHANNEL_NAME;
  // User UID cache
  private static USER_RTC_UID: number = 123456;

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
   * Set user UID
   */
  public static setUserUid(uid: number): void {
    KeyCenter.USER_RTC_UID = uid;
  }

  /**
   * Generate RTM Token
   * Priority: predefined RTM_TOKEN > server API generation > APP_ID as fallback
   */
  public static async getRtmToken(uid: number, callback: TokenCallback): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: uid=${uid}`)

    // If RTM_TOKEN constant is defined, return it directly
    if (KeyCenter.RTM_TOKEN && KeyCenter.RTM_TOKEN.trim() !== '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: using predefined RTM_TOKEN`)
      callback.onTokenGenerated({
        success: true,
        token: KeyCenter.RTM_TOKEN
      });
      return;
    }

    // If no certificate, return APP_ID directly
    if (!KeyCenter.APP_CERTIFICATE || KeyCenter.APP_CERTIFICATE.trim() === '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: using APP_ID as token`)
      callback.onTokenGenerated({
        success: true,
        token: KeyCenter.APP_ID
      });
      return;
    }

    try {
      // Call server API to generate token
      await KeyCenter.generateTokenFromServer('', uid, 'rtm', callback);
    } catch (error) {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: failed to generate RTM token: ${JSON.stringify(error)}`)
      callback.onTokenGenerated({
        success: false,
        error: `Failed to generate RTM token: ${JSON.stringify(error)}`
      });
    }
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
      const response: TokenHttpResponse = await TokenHttpClient.get(requestUrl, requestHeaders);

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
   * Generate token from server
   * Reference Agora documentation's HTTP basic authentication method
   */
  private static async generateTokenFromServer(
    channelId: string,
    uid: number,
    tokenType: 'rtc' | 'rtm',
    callback: TokenCallback
  ): Promise<void> {
    try {
      // Construct request URL
      const baseUrl = 'https://api.agora.io/dev/v1/token';
      let requestUrl = '';
      let requestBody = '';

      if (tokenType === 'rtc') {
        // RTC Token request
        requestUrl = `${baseUrl}`;
        requestBody = JSON.stringify({
          appId: KeyCenter.APP_ID,
          appCertificate: KeyCenter.APP_CERTIFICATE,
          channelName: channelId,
          uid: uid.toString(),
          role: 1, // Publisher role
          expireTime: 3600 // Expires in 1 hour
        });
      } else {
        // RTM Token request
        requestUrl = `${baseUrl}/rtm`;
        requestBody = JSON.stringify({
          appId: KeyCenter.APP_ID,
          appCertificate: KeyCenter.APP_CERTIFICATE,
          userId: uid.toString(),
          expireTime: 3600 // Expires in 1 hour
        });
      }

      // Create HTTP basic authentication header
      const credentials = `${KeyCenter.APP_ID}:${KeyCenter.APP_CERTIFICATE}`;
      const base64Credentials = KeyCenter.base64Encode(credentials);
      const authHeader = `Basic ${base64Credentials}`;

      ExampleLogUtils.logDebug(KeyCenter.TAG, ` HTTP Basic Auth Header: ${authHeader}`);

      // Use TokenHttpClient to send request
      const headers: Record<string, string> = {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };

      const response: TokenHttpResponse = await TokenHttpClient.postForToken(requestUrl, headers, requestBody);

      if (response.success && response.data) {
        ExampleLogUtils.logDebug(KeyCenter.TAG, ` Token request URL: ${requestUrl}`);

        try {
          const tokenResponse: AgoraTokenResponse = JSON.parse(response.data);

          if (tokenResponse.code === 200 && tokenResponse.data?.token) {
            callback.onTokenGenerated({
              success: true,
              token: tokenResponse.data.token
            });
          } else {
            callback.onTokenGenerated({
              success: false,
              error: `Server error: ${tokenResponse.message || 'Unknown error'}`
            });
          }
        } catch (parseError) {
          ExampleLogUtils.logError(KeyCenter.TAG, ` Failed to parse response:` + JSON.stringify(parseError));
          callback.onTokenGenerated({
            success: false,
            error: `Failed to parse server response: ${JSON.stringify(parseError)}`
          });
        }
      } else {
        ExampleLogUtils.logError(KeyCenter.TAG, ` HTTP request failed:` + JSON.stringify(response.error));
        callback.onTokenGenerated({
          success: false,
          error: response.error || 'Unknown HTTP error'
        });
      }

    } catch (error) {
      ExampleLogUtils.logError(KeyCenter.TAG, ` generateTokenFromServer error:` + JSON.stringify(error));
      callback.onTokenGenerated({
        success: false,
        error: `Network error: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * Simple Base64 encoding implementation
   * Used for HTTP basic authentication
   */
  private static base64Encode(str: string): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    let i = 0;

    while (i < str.length) {
      const a = str.charCodeAt(i++);
      const b = i < str.length ? str.charCodeAt(i++) : 0;
      const c = i < str.length ? str.charCodeAt(i++) : 0;

      const bitmap = (a << 16) | (b << 8) | c;

      result += chars.charAt((bitmap >> 18) & 63);
      result += chars.charAt((bitmap >> 12) & 63);
      result += i - 2 < str.length ? chars.charAt((bitmap >> 6) & 63) : '=';
      result += i - 1 < str.length ? chars.charAt(bitmap & 63) : '=';
    }

    return result;
  }

  /**
   * Generate random channel name
   */
  public static generateChannelName(): string {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000);
    return `${KeyCenter.CHANNEL_NAME}_${timestamp}_${random}`;
  }

  /**
   * Get configuration information (for debugging)
   */
  public static getConfigInfo(): Record<string, Object> {
    return BuildConfig.getConfigInfo();
  }

  /**
   * 使用TokenGenerator生成RTC Token (V6版本)
   * 适配Python TokenGenerator的token_v6模式
   * @param channelId 频道名称
   * @param uid 用户ID
   * @param callback 回调接口
   * @param role 客户端角色(默认主播)
   */
  public static async getRtcTokenV6(
    channelId: string,
    uid: number,
    callback: TokenCallback, role: ClientRoleType = ClientRoleType.BROADCASTER
  ): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtcTokenV6: channelId=${channelId}, uid=${uid}, role=${role}`)

    // 检查是否配置了APP_CERTIFICATE
    if (!KeyCenter.APP_CERTIFICATE || KeyCenter.APP_CERTIFICATE.trim() === '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtcTokenV6: APP_CERTIFICATE not configured`)
      callback.onTokenGenerated({
        success: false,
        error: 'APP_CERTIFICATE not configured'
      });
      return;
    }

    // 如果RTC_TOKEN已配置，直接返回
    if (KeyCenter.RTC_TOKEN && KeyCenter.RTC_TOKEN.trim() !== '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtcTokenV6: using predefined RTC_TOKEN`)
      callback.onTokenGenerated({
        success: true,
        token: KeyCenter.RTC_TOKEN
      });
      return;
    }

    try {
      const tokenGenerator = new TokenGenerator(TokenType.TOKEN_V6);
      const params: TokenGenerateParams = {
        channelName: channelId,
        uid: uid,
        channelType: ChannelProfileType.BROADCASTING,
        expireTimestamp: 24 * 60 * 60,
        role: role,
        appId: KeyCenter.APP_ID,
        appCertificate: KeyCenter.APP_CERTIFICATE
      };

      const callbackAdapter = new TokenCallbackAdapter(callback);
      await tokenGenerator.generateToken(params, callbackAdapter);

    } catch (error) {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtcTokenV6: failed to generate token: ${JSON.stringify(error)}`)
      callback.onTokenGenerated({
        success: false,
        error: `Failed to generate token: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * 使用TokenGenerator生成Dynamic Key 5
   * 适配Python TokenGenerator的dy5模式
   * @param channelId 频道名称
   * @param uid 用户ID
   * @param callback 回调接口
   */
  public static async getDy5Token(
    channelId: string,
    uid: number,
    callback: TokenCallback
  ): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getDy5Token: channelId=${channelId}, uid=${uid}`)

    if (!KeyCenter.APP_CERTIFICATE || KeyCenter.APP_CERTIFICATE.trim() === '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getDy5Token: APP_CERTIFICATE not configured`)
      callback.onTokenGenerated({
        success: false,
        error: 'APP_CERTIFICATE not configured'
      });
      return;
    }

    try {
      const tokenGenerator = new TokenGenerator(TokenType.DY5);
      const params: TokenGenerateParams = {
        channelName: channelId,
        uid: uid,
        appId: KeyCenter.APP_ID,
        appCertificate: KeyCenter.APP_CERTIFICATE
      };

      const callbackAdapter = new TokenCallbackAdapter(callback);
      await tokenGenerator.generateToken(params, callbackAdapter);

    } catch (error) {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getDy5Token: failed to generate token: ${JSON.stringify(error)}`)
      callback.onTokenGenerated({
        success: false,
        error: `Failed to generate token: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * 生成观众Token
   * 适配Python TokenGenerator的generate_audience_token方法
   * @param channelId 频道名称
   * @param uid 用户ID
   * @param channelType 频道类型
   * @param callback 回调接口
   */
  public static async getAudienceToken(
    channelId: string,
    uid: number,
    channelType: ChannelProfileType = ChannelProfileType.BROADCASTING,
    callback: TokenCallback
  ): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getAudienceToken: channelId=${channelId}, uid=${uid}`)

    if (!KeyCenter.APP_CERTIFICATE || KeyCenter.APP_CERTIFICATE.trim() === '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getAudienceToken: APP_CERTIFICATE not configured`)
      callback.onTokenGenerated({
        success: false,
        error: 'APP_CERTIFICATE not configured'
      });
      return;
    }

    try {
      const tokenGenerator = new TokenGenerator(TokenType.TOKEN_V6);
      const callbackAdapter = new TokenCallbackAdapter(callback);
      await tokenGenerator.generateAudienceToken(
        channelId,
        uid,
        channelType,
        100000000,
        KeyCenter.APP_ID,
        KeyCenter.APP_CERTIFICATE,
        callbackAdapter
      );

    } catch (error) {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getAudienceToken: failed to generate token: ${JSON.stringify(error)}`)
      callback.onTokenGenerated({
        success: false,
        error: `Failed to generate token: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * 使用指定的AppId和Certificate生成Token
   * 适配Python TokenGenerator的generate_token_with_other_appid方法
   * @param channelId 频道名称
   * @param uid 用户ID
   * @param appId App ID
   * @param appCertificate App Certificate
   * @param callback 回调接口
   */
  public static async getTokenWithAppId(
    channelId: string,
    uid: number,
    appId: string,
    appCertificate: string,
    callback: TokenCallback
  ): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getTokenWithAppId: channelId=${channelId}, uid=${uid}, appId=${appId}`)

    try {
      const tokenGenerator = new TokenGenerator(TokenType.TOKEN_V6);
      const callbackAdapter = new TokenCallbackAdapter(callback);
      await tokenGenerator.generateTokenWithOtherAppId(
        channelId,
        uid,
        appId,
        appCertificate,
        100000000,
        callbackAdapter
      );

    } catch (error) {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getTokenWithAppId: failed to generate token: ${JSON.stringify(error)}`)
      callback.onTokenGenerated({
        success: false,
        error: `Failed to generate token: ${JSON.stringify(error)}`
      });
    }
  }
}
