import { ExampleLogUtils } from '../utils/ExmapleLogUtils';

/**
 * Base ViewModel class
 * Provides common ViewModel functionality
 */
@ObservedV2
export abstract class BaseViewModel {
  /** Whether the ViewModel has been destroyed */
  @Trace protected isDestroyed: boolean = false;
  /** ViewModel tag for logging */
  protected abstract readonly TAG: string;

  /**
   * Initialize the ViewModel
   * Subclasses can override this method for custom initialization
   */
  async initialize(): Promise<void> {
    ExampleLogUtils.logInfo(this.TAG, 'Initializing ViewModel');
  }

  /**
   * Destroy the ViewModel
   * Subclasses should override this method for resource cleanup
   */
  destroy(): void {
    if (this.isDestroyed) {
      return;
    }

    this.isDestroyed = true;
    ExampleLogUtils.logInfo(this.TAG, 'Destroying ViewModel');
  }

  /**
   * Check if the ViewModel has been destroyed
   */
  protected checkDestroyed(): boolean {
    if (this.isDestroyed) {
      ExampleLogUtils.logWarn(this.TAG, 'ViewModel operation called after destruction');
      return true;
    }
    return false;
  }

  /**
   * Safely execute asynchronous operations
   * Ensures callbacks are not executed after ViewModel destruction
   */
  protected async safeExecute<T>(
    operation: () => Promise<T>,
    onSuccess?: (result: T) => void,
    onError?: (error: Error) => void
  ): Promise<void> {
    if (this.checkDestroyed()) {
      return;
    }

    try {
      const result = await operation();

      if (!this.checkDestroyed() && onSuccess) {
        onSuccess(result);
      }
    } catch (error) {
      if (!this.checkDestroyed() && onError) {
        onError(error as Error);
      } else {
        ExampleLogUtils.logError(this.TAG, `Operation failed: ${error}`);
      }
    }
  }
}
