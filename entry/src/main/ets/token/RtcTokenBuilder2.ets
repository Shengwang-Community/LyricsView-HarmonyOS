import { AccessToken, ServiceRtc } from './AccessToken2';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';
import { ExampleConstants } from '../utils/ExampleConstants';

const TAG = ExampleConstants.APP_TAG + '-RtcTokenBuilder2';

/**
 * User role definitions for RTC tokens
 */
export enum Role {
  /**
   * RECOMMENDED: Use this role for a voice/video call or live broadcast
   * if your scenario does not require co-host authentication
   */
  PUBLISHER = 1,

  /**
   * Only use this role if your scenario requires authentication for co-host.
   * Note: Contact Agora support to enable this feature
   */
  SUBSCRIBER = 2
}

/**
 * RTC Token Builder
 * Generates Agora RTC authentication tokens
 */
export class RtcTokenBuilder {
  /**
   * Build RTC token with UID
   * @param appId - App ID from Agora Console
   * @param appCertificate - App Certificate from Agora Console
   * @param channelName - Unique channel name (max 64 bytes)
   * @param uid - User ID (32-bit unsigned integer, 1 to 2^32-1)
   * @param role - Role.PUBLISHER or Role.SUBSCRIBER
   * @param tokenExpire - Token expiration time in seconds
   * @param privilegeExpire - Privilege expiration time in seconds (default: 0)
   * @returns RTC token string
   */
  static async buildTokenWithUid(
    appId: string,
    appCertificate: string,
    channelName: string,
    uid: number,
    role: Role,
    tokenExpire: number,
    privilegeExpire: number = 0
  ): Promise<string> {
    return RtcTokenBuilder.buildTokenWithUserAccount(
      appId,
      appCertificate,
      channelName,
      uid,
      role,
      tokenExpire,
      privilegeExpire
    );
  }

  /**
   * Build RTC token with user account
   * @param appId - App ID from Agora Console
   * @param appCertificate - App Certificate from Agora Console
   * @param channelName - Unique channel name (max 64 bytes)
   * @param account - User account (string or number, max 255 bytes)
   * @param role - Role.PUBLISHER or Role.SUBSCRIBER
   * @param tokenExpire - Token expiration time in seconds
   * @param privilegeExpire - Privilege expiration time in seconds (default: 0)
   * @returns RTC token string
   */
  static async buildTokenWithUserAccount(
    appId: string,
    appCertificate: string,
    channelName: string,
    account: string | number,
    role: Role,
    tokenExpire: number,
    privilegeExpire: number = 0
  ): Promise<string> {
    try {
      ExampleLogUtils.logDebug(TAG,
        `buildTokenWithUserAccount: channel=${channelName}, account=${account}, role=${role}`);

      const token = new AccessToken(appId, appCertificate, 0, tokenExpire);
      const serviceRtc = new ServiceRtc(channelName, account);

      serviceRtc.addPrivilege(ServiceRtc.PRIVILEGE_JOIN_CHANNEL, privilegeExpire);

      if (role === Role.PUBLISHER) {
        serviceRtc.addPrivilege(ServiceRtc.PRIVILEGE_PUBLISH_AUDIO_STREAM, privilegeExpire);
        serviceRtc.addPrivilege(ServiceRtc.PRIVILEGE_PUBLISH_VIDEO_STREAM, privilegeExpire);
        serviceRtc.addPrivilege(ServiceRtc.PRIVILEGE_PUBLISH_DATA_STREAM, privilegeExpire);
      }

      token.addService(serviceRtc);

      return await token.build();
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      ExampleLogUtils.logError(TAG, `buildTokenWithUserAccount error: ${errorMsg}`);
      throw new Error(`Failed to build RTC token: ${errorMsg}`);
    }
  }

  /**
   * Build RTC token with UID and detailed privileges
   * @param appId - App ID from Agora Console
   * @param appCertificate - App Certificate from Agora Console
   * @param channelName - Unique channel name (max 64 bytes)
   * @param uid - User ID (32-bit unsigned integer)
   * @param tokenExpire - Token expiration time in seconds
   * @param joinChannelPrivilegeExpire - Join channel privilege expiration
   * @param pubAudioPrivilegeExpire - Publish audio privilege expiration
   * @param pubVideoPrivilegeExpire - Publish video privilege expiration
   * @param pubDataStreamPrivilegeExpire - Publish data stream privilege expiration
   * @returns RTC token string
   */
  static async buildTokenWithUidAndPrivilege(
    appId: string,
    appCertificate: string,
    channelName: string,
    uid: number,
    tokenExpire: number,
    joinChannelPrivilegeExpire: number,
    pubAudioPrivilegeExpire: number,
    pubVideoPrivilegeExpire: number,
    pubDataStreamPrivilegeExpire: number
  ): Promise<string> {
    return RtcTokenBuilder.buildTokenWithUserAccountAndPrivilege(
      appId,
      appCertificate,
      channelName,
      uid,
      tokenExpire,
      joinChannelPrivilegeExpire,
      pubAudioPrivilegeExpire,
      pubVideoPrivilegeExpire,
      pubDataStreamPrivilegeExpire
    );
  }

  /**
   * Build RTC token with user account and detailed privileges
   * @param appId - App ID from Agora Console
   * @param appCertificate - App Certificate from Agora Console
   * @param channelName - Unique channel name (max 64 bytes)
   * @param account - User account (string or number)
   * @param tokenExpire - Token expiration time in seconds
   * @param joinChannelPrivilegeExpire - Join channel privilege expiration
   * @param pubAudioPrivilegeExpire - Publish audio privilege expiration
   * @param pubVideoPrivilegeExpire - Publish video privilege expiration
   * @param pubDataStreamPrivilegeExpire - Publish data stream privilege expiration
   * @returns RTC token string
   */
  static async buildTokenWithUserAccountAndPrivilege(
    appId: string,
    appCertificate: string,
    channelName: string,
    account: string | number,
    tokenExpire: number,
    joinChannelPrivilegeExpire: number,
    pubAudioPrivilegeExpire: number,
    pubVideoPrivilegeExpire: number,
    pubDataStreamPrivilegeExpire: number
  ): Promise<string> {
    try {
      ExampleLogUtils.logDebug(TAG,
        `buildTokenWithUserAccountAndPrivilege: channel=${channelName}, account=${account}`);

      const token = new AccessToken(appId, appCertificate, 0, tokenExpire);
      const serviceRtc = new ServiceRtc(channelName, account);

      serviceRtc.addPrivilege(ServiceRtc.PRIVILEGE_JOIN_CHANNEL, joinChannelPrivilegeExpire);
      serviceRtc.addPrivilege(ServiceRtc.PRIVILEGE_PUBLISH_AUDIO_STREAM, pubAudioPrivilegeExpire);
      serviceRtc.addPrivilege(ServiceRtc.PRIVILEGE_PUBLISH_VIDEO_STREAM, pubVideoPrivilegeExpire);
      serviceRtc.addPrivilege(ServiceRtc.PRIVILEGE_PUBLISH_DATA_STREAM, pubDataStreamPrivilegeExpire);

      token.addService(serviceRtc);

      return await token.build();
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      ExampleLogUtils.logError(TAG, `buildTokenWithUserAccountAndPrivilege error: ${errorMsg}`);
      throw new Error(`Failed to build RTC token with privilege: ${errorMsg}`);
    }
  }
}
