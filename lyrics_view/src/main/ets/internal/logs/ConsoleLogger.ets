import hilog from '@ohos.hilog';
import { ILogger } from './ILogger';
import { LogLevel } from './LogLevel';

/**
 * Console logger implementation - HarmonyOS version
 * Based on Agora-LoggingService ConsoleLogger implementation
 * Uses HarmonyOS hilog for console output
 */
export class ConsoleLogger implements ILogger {
  /**
   * Log domain identifier
   */
  private readonly domain: number;

  constructor(domain: number = 0x1001) {
    this.domain = domain;
  }

  onLog(level: number, tag: string, message: string): void {
    switch (level) {
      case LogLevel.DEBUG:
        hilog.debug(this.domain, tag, message);
        break;
      case LogLevel.ERROR:
        hilog.error(this.domain, tag, message);
        break;
      case LogLevel.INFO:
        hilog.info(this.domain, tag, message);
        break;
      case LogLevel.WARN:
        hilog.warn(this.domain, tag, message);
        break;
      case LogLevel.VERBOSE:
        hilog.debug(this.domain, tag, message); // HarmonyOS doesn't have verbose, use debug instead
        break;
      default:
        hilog.info(this.domain, tag, message);
        break;
    }
  }
}
