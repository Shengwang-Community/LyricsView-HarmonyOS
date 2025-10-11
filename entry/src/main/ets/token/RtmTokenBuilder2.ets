import { AccessToken, ServiceRtm } from './AccessToken2';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';
import { ExampleConstants } from '../utils/ExampleConstants';

const TAG = ExampleConstants.APP_TAG + '-RtmTokenBuilder2';

/**
 * RTM Token Builder
 * Generates Agora RTM authentication tokens
 */
export class RtmTokenBuilder {
  /**
   * Build RTM token
   * @param appId - The App ID issued by Agora
   * @param appCertificate - App Certificate from Agora Dashboard
   * @param userId - User account (max 64 bytes)
   * @param expire - Token expiration time in seconds
   * @returns RTM token string
   */
  static async buildToken(
    appId: string,
    appCertificate: string,
    userId: string,
    expire: number
  ): Promise<string> {
    try {
      ExampleLogUtils.logDebug(TAG, `buildToken: appId=${appId}, userId=${userId}, expire=${expire}`);

      const token = new AccessToken(appId, appCertificate, 0, expire);
      const rtmService = new ServiceRtm(userId);
      rtmService.addPrivilege(ServiceRtm.PRIVILEGE_LOGIN, expire);
      token.addService(rtmService);

      return await token.build();
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      ExampleLogUtils.logError(TAG, `buildToken error: ${errorMsg}`);
      throw new Error(`Failed to build RTM token: ${errorMsg}`);
    }
  }
}
