import common from '@ohos.app.ability.common';
import resmgr from '@ohos.resourceManager';

/**
 * Context Manager
 * Provides global Context access, avoiding the use of deprecated getContext() method
 */
export class ContextManager {
  private static instance: ContextManager;
  private context: common.UIAbilityContext | null = null;

  /**
   * Get singleton instance
   */
  static getInstance(): ContextManager {
    if (!ContextManager.instance) {
      ContextManager.instance = new ContextManager();
    }
    return ContextManager.instance;
  }

  /**
   * Set Context (usually called in Ability's onCreate)
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * Get Context
   */
  getContext(): common.UIAbilityContext {
    if (!this.context) {
      throw new Error('Context not initialized. Please call setContext() first.');
    }
    return this.context;
  }

  /**
   * Get cache directory path
   */
  getCacheDir(): string {
    return this.getContext().cacheDir;
  }

  /**
   * Get files directory path
   */
  getFilesDir(): string {
    return this.getContext().filesDir;
  }

  /**
   * Get temporary directory path
   */
  getTempDir(): string {
    return this.getContext().tempDir;
  }

  /**
   * Get database directory path
   */
  getDatabaseDir(): string {
    return this.getContext().databaseDir;
  }

  /**
   * Get resource manager
   */
  getResourceManager(): resmgr.ResourceManager {
    return this.getContext().resourceManager;
  }

  /**
   * Check if Context is initialized
   */
  isInitialized(): boolean {
    return this.context !== null;
  }

  /**
   * Clear Context (usually called when application exits)
   */
  clear(): void {
    this.context = null;
  }
}

/**
 * Global Context Manager instance
 */
export const contextManager = ContextManager.getInstance();
