import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { contextManager } from '../utils/ContextManager';
import { PermissionUtil } from '../utils/PermissionUtil';
import { ExampleConstants } from '../utils/ExampleConstants';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';


export default class EntryAbility extends UIAbility {
  private static readonly TAG = ExampleConstants.APP_TAG + '-EntryAbility';
  private permissionGranted: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // Initialize global Context manager
    contextManager.setContext(this.context);

    // Request essential permissions
    this.requestEssentialPermissions();

    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    ExampleLogUtils.logDebug(EntryAbility.TAG, 'Ability onCreate');
  }

  /**
   * Request essential permissions for the application
   */
  private async requestEssentialPermissions(): Promise<void> {
    try {
      ExampleLogUtils.logDebug(EntryAbility.TAG, 'Requesting essential permissions for karaoke app');

      const result = await PermissionUtil.requestEssentialPermissions(this.context);
      PermissionUtil.logPermissionResult(result);

      if (result.success) {
        this.permissionGranted = true;
        ExampleLogUtils.logDebug(EntryAbility.TAG, 'All essential permissions granted, app can proceed');
      } else {
        this.permissionGranted = false;
        ExampleLogUtils.logDebug(EntryAbility.TAG, `Permission request failed: ${result.message}`);

        // Option to show permission explanation dialog or guide user to settings page
        this.handlePermissionDenied(result.deniedPermissions);
      }
    } catch (error) {
      this.permissionGranted = false;
      ExampleLogUtils.logDebug(EntryAbility.TAG, `Failed to request permissions: ${error}`);
    }
  }

  /**
   * Handle permission denied scenarios
   */
  private handlePermissionDenied(deniedPermissions: string[]): void {
    ExampleLogUtils.logDebug(EntryAbility.TAG,
      `The following permissions were denied: ${deniedPermissions.join(', ')}`);

    // Here you can implement the following logic:
    // 1. Show permission explanation dialog
    // 2. Guide user to system settings page
    // 3. Provide limited functionality mode

    // For karaoke app, microphone permission is essential
    if (deniedPermissions.includes('ohos.permission.MICROPHONE')) {
      ExampleLogUtils.logDebug(EntryAbility.TAG, 'Microphone permission is essential for karaoke functionality');
    }
  }

  /**
   * Check permission status and decide whether to initialize MccKaraoke
   */
  private async checkPermissionsAndInitialize(): Promise<boolean> {
    try {
      const hasPermissions = await PermissionUtil.hasEssentialPermissions(this.context);
      if (hasPermissions) {
        ExampleLogUtils.logDebug(EntryAbility.TAG, 'Essential permissions verified, ready to initialize MccKaraoke');
        return true;
      } else {
        ExampleLogUtils.logDebug(EntryAbility.TAG, 'Essential permissions not available, cannot initialize MccKaraoke');
        return false;
      }
    } catch (error) {
      ExampleLogUtils.logDebug(EntryAbility.TAG, `Failed to check permissions: ${error}`);
      return false;
    }
  }

  onDestroy(): void {
    // Clean up Context manager
    contextManager.clear();
    ExampleLogUtils.logDebug(EntryAbility.TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    ExampleLogUtils.logDebug(EntryAbility.TAG, 'Ability onWindowStageCreate');

    // Check permission status before loading page
    this.checkPermissionsAndInitialize().then((canProceed) => {
      if (canProceed) {
        // Permissions granted, load normal karaoke page
        this.loadMainContent(windowStage);
      } else {
        // Permissions not granted, load permission request page or show error page
        this.loadPermissionRequiredContent(windowStage);
      }
    }).catch((error: Error) => {
      ExampleLogUtils.logDebug(EntryAbility.TAG, `Failed to check permissions in onWindowStageCreate: ${error}`);
      // When error occurs, try to load main page
      this.loadMainContent(windowStage);
    });
  }

  /**
   * Load main content page (permissions granted)
   */
  private loadMainContent(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/MccIndex', (err) => {
      if (err.code) {
        ExampleLogUtils.logDebug(EntryAbility.TAG, 'Failed to load the main content. Cause:' +
        JSON.stringify(err));
        return;
      }
      ExampleLogUtils.logDebug(EntryAbility.TAG, 'Succeeded in loading the main content.');
    });
  }

  /**
   * Load permission request page (permissions not granted)
   */
  private loadPermissionRequiredContent(windowStage: window.WindowStage): void {
    // Can create a dedicated permission request page
    // For now, still load main page, but permission status will be checked within the page
    windowStage.loadContent('pages/MccIndex', (err) => {
      if (err.code) {
        ExampleLogUtils.logDebug(EntryAbility.TAG, 'Failed to load the permission required content. Cause:' +
        JSON.stringify(err));
        return;
      }
      ExampleLogUtils.logDebug(EntryAbility.TAG, 'Loaded content with permission check required.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    ExampleLogUtils.logDebug(EntryAbility.TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    ExampleLogUtils.logDebug(EntryAbility.TAG, 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    ExampleLogUtils.logDebug(EntryAbility.TAG, 'Ability onBackground');
  }
}
