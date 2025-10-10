import { ExampleLogUtils } from './ExmapleLogUtils';
import { ExampleConstants } from './ExampleConstants';
import { TokenHttpClient, TokenHttpResponse } from './TokenHttpClient';

/**
 * 频道类型枚举
 */
export enum ChannelProfileType {
  COMMUNICATION = 0, // 通信模式
  BROADCASTING = 1, // 直播模式
  LIVE_BROADCASTING_2 = 2 // 直播模式2
}

/**
 * 客户端角色类型枚举
 */
export enum ClientRoleType {
  AUDIENCE = 0, // 观众
  BROADCASTER = 1 // 主播
}

/**
 * Token类型枚举
 */
export enum TokenType {
  TOKEN_V6 = 'token_v6', // Token v6版本
  DY5 = 'dy5', // Dynamic Key 5
  TOKEN_V7 = 'token_v7' // Token v7版本
}

/**
 * Token生成请求参数
 */
export interface TokenGenerateParams {
  channelName: string; // 频道名称
  uid: number | string; // 用户ID
  channelType?: ChannelProfileType; // 频道类型,默认BROADCASTING
  expireTimestamp?: number; // 过期时间戳(秒),默认100000000
  role?: ClientRoleType; // 客户端角色,默认BROADCASTER
  appId?: string; // App ID
  appCertificate?: string; // App Certificate
  joinChannelPrivilegeExpire?: number; // 加入频道权限过期时间
  pubAudioPrivilegeExpire?: number; // 发布音频权限过期时间
  pubVideoPrivilegeExpire?: number; // 发布视频权限过期时间
  pubDataStreamPrivilegeExpire?: number; // 发布数据流权限过期时间
}

/**
 * Token生成响应类
 */
export class TokenGenerateResponse {
  success: boolean = false;
  token?: string;
  error?: string;

  constructor(success: boolean, token?: string, error?: string) {
    this.success = success;
    this.token = token;
    this.error = error;
  }
}

/**
 * Token生成回调接口
 */
export interface TokenGenerateCallback {
  onTokenGenerated(response: TokenGenerateResponse): void;
}

/**
 * Token请求参数类（用于避免untyped object literal错误）
 */
class TokenRequestParams {
  channelName: string = '';
  uid: number | string = 0;
  join_channel?: number = 0;
  key: string = '';
  sign: string = '';
  audio?: number = 0;
  video?: number = 0;
  data?: number = 0;
}

/**
 * Token生成器
 * 适配自Python TokenGenerator
 * 支持多种token生成方式: token_v6, dy5, token_v7
 */
export class TokenGenerator {
  private static readonly TAG: string = ExampleConstants.APP_TAG + '-TokenGenerator';
  // Token服务器配置
  private static readonly TOKEN_V6_URL = 'http://recording.agorapremium.agora.io:9001/agora/media/genAccessToken2';
  private static readonly DY5_URL = 'http://recording.agorapremium.agora.io:9001/agora/media/genDynamicKey5';
  private static readonly TOKEN_V7_URL = 'http://recording.agorapremium.agora.io:9001/agora/media/genDynamicKey7';
  private tokenType: TokenType;
  private requestUrl: string;

  /**
   * 构造函数
   * @param tokenType Token类型,默认TOKEN_V6
   */
  constructor(tokenType: TokenType = TokenType.TOKEN_V6) {
    this.tokenType = tokenType;

    switch (tokenType) {
      case TokenType.TOKEN_V6:
        this.requestUrl = TokenGenerator.TOKEN_V6_URL;
        break;
      case TokenType.DY5:
        this.requestUrl = TokenGenerator.DY5_URL;
        break;
      case TokenType.TOKEN_V7:
        this.requestUrl = TokenGenerator.TOKEN_V7_URL;
        break;
      default:
        throw new Error('Invalid token type');
    }

    ExampleLogUtils.logDebug(TokenGenerator.TAG,
      `TokenGenerator initialized with type: ${tokenType}, url: ${this.requestUrl}`);
  }

  /**
   * 生成Token
   * @param params Token生成参数
   * @param callback 回调接口
   */
  public async generateToken(params: TokenGenerateParams, callback: TokenGenerateCallback): Promise<void> {
    ExampleLogUtils.logDebug(TokenGenerator.TAG,
      `generateToken: channel=${params.channelName}, uid=${params.uid}, type=${this.tokenType}`);

    try {
      if (this.tokenType === TokenType.TOKEN_V7) {
        // V7版本需要使用特殊的生成方式(通常需要本地SDK支持)
        callback.onTokenGenerated(new TokenGenerateResponse(false, undefined,
          'TOKEN_V7 requires local SDK token builder'));
        return;
      }

      // 设置默认值
      const channelType = params.channelType ?? ChannelProfileType.BROADCASTING;
      const expireTimestamp = params.expireTimestamp ?? 100000000;
      const role = params.role ?? ClientRoleType.BROADCASTER;

      // 根据频道类型确定appId和sign
      let appId = params.appId;
      let sign = params.appCertificate;

      if (!appId || !sign) {
        callback.onTokenGenerated(new TokenGenerateResponse(false, undefined, 'appId and appCertificate are required'));
        return;
      }

      // 构建请求参数
      let generateRequest = new TokenRequestParams();

      if (this.tokenType === TokenType.DY5) {
        // DY5 token请求
        generateRequest.channelName = params.channelName;
        generateRequest.key = appId;
        generateRequest.sign = sign;
        generateRequest.uid = params.uid;
      } else {
        // TOKEN_V6请求
        generateRequest.channelName = params.channelName;
        generateRequest.uid = params.uid;
        generateRequest.join_channel = expireTimestamp;
        generateRequest.key = appId;
        generateRequest.sign = sign;
        generateRequest.data = expireTimestamp;

        if (role === ClientRoleType.BROADCASTER) {
          generateRequest.audio = expireTimestamp;
          generateRequest.video = expireTimestamp;
        } else {
          // 观众角色
          generateRequest.audio = 0;
          generateRequest.video = 0;
        }
      }

      ExampleLogUtils.logDebug(TokenGenerator.TAG, `Request params: ${JSON.stringify(generateRequest)}`);

      // 发送HTTP请求
      const response = await this.sendTokenRequest(generateRequest);

      if (response.success && response.data) {
        ExampleLogUtils.logDebug(TokenGenerator.TAG, `Token generated successfully: ${response.data}`);
        callback.onTokenGenerated(new TokenGenerateResponse(true, response.data));
      } else {
        ExampleLogUtils.logError(TokenGenerator.TAG, `Failed to generate token: ${response.error}`);
        callback.onTokenGenerated(new TokenGenerateResponse(false, undefined, response.error));
      }

    } catch (error) {
      ExampleLogUtils.logError(TokenGenerator.TAG, `generateToken error: ${JSON.stringify(error)}`);
      callback.onTokenGenerated(new TokenGenerateResponse(false, undefined, `Network error: ${JSON.stringify(error)}`));
    }
  }

  /**
   * 生成观众Token
   * @param channelName 频道名称
   * @param uid 用户ID
   * @param channelType 频道类型
   * @param expireTimestamp 过期时间戳
   * @param appId App ID
   * @param appCertificate App Certificate
   * @param callback 回调接口
   */
  public async generateAudienceToken(
    channelName: string,
    uid: number | string,
    channelType: ChannelProfileType,
    expireTimestamp: number,
    appId: string,
    appCertificate: string,
    callback: TokenGenerateCallback
  ): Promise<void> {
    const params: TokenGenerateParams = {
      channelName,
      uid,
      channelType,
      expireTimestamp,
      role: ClientRoleType.AUDIENCE,
      appId,
      appCertificate
    };

    await this.generateToken(params, callback);
  }

  /**
   * 使用其他AppId生成Token
   * @param channelName 频道名称
   * @param uid 用户ID
   * @param appId App ID
   * @param sign App Certificate
   * @param expireTimestamp 过期时间戳
   * @param callback 回调接口
   */
  public async generateTokenWithOtherAppId(
    channelName: string,
    uid: number | string,
    appId: string,
    sign: string,
    expireTimestamp: number,
    callback: TokenGenerateCallback
  ): Promise<void> {
    ExampleLogUtils.logDebug(TokenGenerator.TAG,
      `generateTokenWithOtherAppId: channel=${channelName}, uid=${uid}, appId=${appId}`);

    try {
      const generateRequest = new TokenRequestParams();
      generateRequest.channelName = channelName;
      generateRequest.uid = uid;
      generateRequest.join_channel = expireTimestamp;
      generateRequest.key = appId;
      generateRequest.sign = sign;
      generateRequest.audio = 10000000;
      generateRequest.video = 10000000;
      generateRequest.data = 10000000;

      ExampleLogUtils.logDebug(TokenGenerator.TAG, `Request params: ${JSON.stringify(generateRequest)}`);

      const response = await this.sendTokenRequest(generateRequest);

      if (response.success && response.data) {
        ExampleLogUtils.logDebug(TokenGenerator.TAG, `Token generated successfully`);
        callback.onTokenGenerated(new TokenGenerateResponse(true, response.data));
      } else {
        ExampleLogUtils.logError(TokenGenerator.TAG, `Failed to generate token: ${response.error}`);
        callback.onTokenGenerated(new TokenGenerateResponse(false, undefined, response.error));
      }

    } catch (error) {
      ExampleLogUtils.logError(TokenGenerator.TAG, `generateTokenWithOtherAppId error: ${JSON.stringify(error)}`);
      callback.onTokenGenerated(new TokenGenerateResponse(false, undefined, `Network error: ${JSON.stringify(error)}`));
    }
  }

  /**
   * 发送Token请求
   * @param params 请求参数
   */
  private async sendTokenRequest(params: TokenRequestParams): Promise<TokenHttpResponse> {
    try {
      // 构建URL查询参数
      const queryParams: string[] = [];

      // 直接处理TokenRequestParams的属性
      if (params.channelName) {
        queryParams.push(`channelname=${encodeURIComponent(params.channelName)}`);
      }
      if (params.uid !== undefined && params.uid !== null) {
        queryParams.push(`uid=${encodeURIComponent(params.uid.toString())}`);
      }
      if (params.key) {
        queryParams.push(`key=${encodeURIComponent(params.key)}`);
      }
      if (params.sign) {
        queryParams.push(`sign=${encodeURIComponent(params.sign)}`);
      }
      if (params.join_channel !== undefined && params.join_channel !== null) {
        queryParams.push(`join_channel=${encodeURIComponent(params.join_channel.toString())}`);
      }
      if (params.audio !== undefined && params.audio !== null) {
        queryParams.push(`audio=${encodeURIComponent(params.audio.toString())}`);
      }
      if (params.video !== undefined && params.video !== null) {
        queryParams.push(`video=${encodeURIComponent(params.video.toString())}`);
      }
      if (params.data !== undefined && params.data !== null) {
        queryParams.push(`data=${encodeURIComponent(params.data.toString())}`);
      }

      const queryString = queryParams.join('&');
      const fullUrl = `${this.requestUrl}?${queryString}`;

      ExampleLogUtils.logDebug(TokenGenerator.TAG, `Sending request to: ${fullUrl}`);

      // 发送GET请求
      const response = await TokenHttpClient.get(fullUrl);

      if (response.success) {
        ExampleLogUtils.logDebug(TokenGenerator.TAG, `Response: ${response.data}`);
      } else {
        ExampleLogUtils.logError(TokenGenerator.TAG, `Request failed: ${response.error}`);
      }

      return response;

    } catch (error) {
      ExampleLogUtils.logError(TokenGenerator.TAG, `sendTokenRequest error: ${JSON.stringify(error)}`);
      const errorResponse: TokenHttpResponse = {
        success: false,
        error: `Network error: ${JSON.stringify(error)}`
      };
      return errorResponse;
    }
  }
}
