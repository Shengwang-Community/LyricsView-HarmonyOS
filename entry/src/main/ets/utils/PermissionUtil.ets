import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import bundleManager from '@ohos.bundle.bundleManager';
import { ExampleConstants } from './ExampleConstants';
import { ExampleLogUtils } from './ExmapleLogUtils';

/**
 * Permission request result interface
 */
export interface PermissionResult {
  success: boolean;
  grantedPermissions: string[];
  deniedPermissions: string[];
  message: string;
}

/**
 * Permission utility class
 * Provides unified permission request and check functionality
 */
export class PermissionUtil {
  private static readonly TAG = ExampleConstants.APP_TAG + '-PermissionUtil';
  private static readonly DOMAIN = 0x0000;

  /**
   * Check if a single permission is granted
   * @param permission Permission name
   * @returns Promise<abilityAccessCtrl.GrantStatus>
   */
  static async checkAccessToken(permission: Permissions): Promise<abilityAccessCtrl.GrantStatus> {
    let atManager = abilityAccessCtrl.createAtManager();
    let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;

    // Get application's accessTokenID
    let tokenId: number = 0;
    try {
      let bundleInfo: bundleManager.BundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      let appInfo: bundleManager.ApplicationInfo = bundleInfo.appInfo;
      tokenId = appInfo.accessTokenId;
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      ExampleLogUtils.logDebug(PermissionUtil.TAG,
        `Failed to get bundle info for self. Code is ${err.code}, message is ${err.message}`);
      return grantStatus;
    }

    // Check if application is granted the permission
    try {
      grantStatus = await atManager.checkAccessToken(tokenId, permission);
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      ExampleLogUtils.logDebug(PermissionUtil.TAG,
        `Failed to check access token. Code is ${err.code}, message is ${err.message}`);
    }

    return grantStatus;
  }

  /**
   * Request multiple permissions
   * @param context UIAbility context
   * @param permissions Permission array
   * @returns Promise<PermissionResult>
   */
  static async requestPermissions(context: common.UIAbilityContext,
    permissions: Array<Permissions>): Promise<PermissionResult> {
    const result: PermissionResult = {
      success: false,
      grantedPermissions: [],
      deniedPermissions: [],
      message: ''
    };

    if (!permissions || permissions.length === 0) {
      result.message = 'Permission list is empty';
      return result;
    }

    let atManager = abilityAccessCtrl.createAtManager();
    const needRequestPermissions: Array<Permissions> = [];

    // First check which permissions are not yet granted
    for (let permission of permissions) {
      try {
        const grantStatus = await PermissionUtil.checkAccessToken(permission);
        if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          result.grantedPermissions.push(permission);
          ExampleLogUtils.logDebug(PermissionUtil.TAG, `Permission already granted: ${permission}`);
        } else {
          needRequestPermissions.push(permission);
        }
      } catch (error) {
        let err: BusinessError = error as BusinessError;
        ExampleLogUtils.logDebug(PermissionUtil.TAG, `Failed to check permission ${permission}: ${err.message}`);
        result.deniedPermissions.push(permission);
      }
    }

    // If all permissions are already granted
    if (needRequestPermissions.length === 0) {
      result.success = true;
      result.message = 'All permissions are already granted';
      return result;
    }

    // Request ungranted permissions
    try {
      ExampleLogUtils.logDebug(PermissionUtil.TAG, `Requesting permissions: ${needRequestPermissions.join(', ')}`);

      const data = await atManager.requestPermissionsFromUser(context, needRequestPermissions);
      const grantStatus: Array<number> = data.authResults;

      if (!grantStatus || grantStatus.length !== needRequestPermissions.length) {
        result.message = 'Permission request result is abnormal';
        result.deniedPermissions.push(...needRequestPermissions);
        return result;
      }

      // Process request results
      for (let i = 0; i < grantStatus.length; i++) {
        const permission = needRequestPermissions[i];
        if (grantStatus[i] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          result.grantedPermissions.push(permission);
          ExampleLogUtils.logDebug(PermissionUtil.TAG, `Permission granted: ${permission}`);
        } else {
          result.deniedPermissions.push(permission);
          ExampleLogUtils.logDebug(PermissionUtil.TAG, `Permission denied: ${permission}`);
        }
      }

      // Determine overall result
      result.success = result.deniedPermissions.length === 0;
      result.message = result.success ?
        'All permissions granted successfully' :
        `Some permissions were denied: ${result.deniedPermissions.join(', ')}`;

    } catch (error) {
      let err: BusinessError = error as BusinessError;
      result.message = `Permission request failed: ${err.message}`;
      result.deniedPermissions.push(...needRequestPermissions);
      ExampleLogUtils.logDebug(PermissionUtil.TAG,
        `Failed to request permissions: Code is ${err.code}, message is ${err.message}`);
    }

    return result;
  }

  /**
   * Request essential core permissions for the application
   * @param context UIAbility context
   * @returns Promise<PermissionResult>
   */
  static async requestEssentialPermissions(context: common.UIAbilityContext): Promise<PermissionResult> {
    const essentialPermissions: Array<Permissions> = [
      'ohos.permission.INTERNET',
      'ohos.permission.MICROPHONE'
    ];

    ExampleLogUtils.logDebug(PermissionUtil.TAG, 'Requesting essential permissions for karaoke app');
    return await PermissionUtil.requestPermissions(context, essentialPermissions);
  }

  /**
   * Request all karaoke-related permissions
   * @param context UIAbility context
   * @returns Promise<PermissionResult>
   */
  static async requestAllKaraokePermissions(context: common.UIAbilityContext): Promise<PermissionResult> {
    const karaokePermissions: Array<Permissions> = [
      'ohos.permission.INTERNET',
      'ohos.permission.MICROPHONE',
      'ohos.permission.READ_MEDIA',
      'ohos.permission.WRITE_MEDIA',
      'ohos.permission.CAMERA'
    ];

    ExampleLogUtils.logDebug(PermissionUtil.TAG, 'Requesting all karaoke permissions');
    return await PermissionUtil.requestPermissions(context, karaokePermissions);
  }

  /**
   * Check if permissions are sufficient to start karaoke functionality
   * @param context UIAbility context
   * @returns Promise<boolean>
   */
  static async hasEssentialPermissions(context: common.UIAbilityContext): Promise<boolean> {
    const essentialPermissions: Array<Permissions> = [
      'ohos.permission.INTERNET',
      'ohos.permission.MICROPHONE'
    ];

    for (let permission of essentialPermissions) {
      const grantStatus = await PermissionUtil.checkAccessToken(permission);
      if (grantStatus !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        ExampleLogUtils.logDebug(PermissionUtil.TAG, `Essential permission not granted: ${permission}`);
        return false;
      }
    }

    ExampleLogUtils.logDebug(PermissionUtil.TAG, 'All essential permissions are granted');
    return true;
  }

  /**
   * Log permission request result
   * @param result Permission request result
   */
  static logPermissionResult(result: PermissionResult): void {
    ExampleLogUtils.logDebug(PermissionUtil.TAG, `Permission request result: ${result.message}`);

    if (result.grantedPermissions.length > 0) {
      ExampleLogUtils.logDebug(PermissionUtil.TAG, `Granted permissions: ${result.grantedPermissions.join(', ')}`);
    }

    if (result.deniedPermissions.length > 0) {
      ExampleLogUtils.logDebug(PermissionUtil.TAG, `Denied permissions: ${result.deniedPermissions.join(', ')}`);
    }
  }
}
