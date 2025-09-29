import { ConsoleLogger } from './ConsoleLogger';
import { LogLevel } from './LogLevel';
import { ILogger } from './ILogger';

/**
 * Log Manager
 * Based on Agora-LoggingService LogManager implementation
 * Uses singleton pattern for asynchronous log processing
 */
export class LogManager {
  private static instance: LogManager | null = null;
  private readonly loggers: Map<ILogger, number> = new Map();

  private constructor() {
    // Private constructor to ensure singleton pattern
  }

  /**
   * Get singleton instance
   */
  static getInstance(): LogManager {
    if (LogManager.instance !== null) {
      return LogManager.instance;
    }

    // Double-checked locking
    if (LogManager.instance === null) {
      LogManager.instance = new LogManager();
    }

    return LogManager.instance;
  }

  /**
   * Output warning level log
   */
  warn(tag: string, message: string): void {
    this.log(LogLevel.WARN, tag, message);
  }

  /**
   * Output info level log
   */
  info(tag: string, message: string): void {
    this.log(LogLevel.INFO, tag, message);
  }

  /**
   * Output debug level log
   */
  debug(tag: string, message: string): void {
    this.log(LogLevel.DEBUG, tag, message);
  }

  /**
   * Output error level log
   */
  error(tag: string, message: string): void {
    this.log(LogLevel.ERROR, tag, message);
  }

  /**
   * Output verbose level log
   */
  verbose(tag: string, message: string): void {
    this.log(LogLevel.VERBOSE, tag, message);
  }

  /**
   * Output log with specified level
   */
  private log(level: number, tag: string, message: string): void {
    // Use setTimeout to implement asynchronous log processing, avoiding blocking the main thread
    setTimeout(() => {
      this.executeLogSync(level, tag, message);
    }, 0);
  }

  /**
   * Execute log output synchronously
   */
  private executeLogSync(level: number, tag: string, message: string): void {
    for (const logger of this.loggers.keys()) {
      try {
        logger.onLog(level, tag, message);
      } catch (error) {
        console.error('LogManager', `Logger execution failed: ${error}`);
      }
    }
  }

  /**
   * Add logger
   */
  addLogger(logger: ILogger): void {
    if (!logger) {
      throw new Error('Logger must not be null');
    }

    if (this.loggers.has(logger)) {
      return;
    }

    // If it's a ConsoleLogger, check if one already exists
    if (logger instanceof ConsoleLogger) {
      for (const existingLogger of this.loggers.keys()) {
        if (existingLogger instanceof ConsoleLogger) {
          return; // ConsoleLogger already exists, don't add another one
        }
      }
    }

    const hash = this.getLoggerHash(logger);
    this.loggers.set(logger, hash);
  }

  /**
   * Get all loggers
   */
  getLoggers(): ILogger[] {
    return Array.from(this.loggers.keys());
  }

  /**
   * Remove logger
   */
  removeLogger(logger: ILogger): void {
    this.loggers.delete(logger);
  }

  /**
   * Remove all loggers
   */
  removeAllLogger(): void {
    this.loggers.clear();
  }

  /**
   * Get logger hash value
   */
  private getLoggerHash(logger: ILogger): number {
    // Simple hash implementation based on object string representation
    const str = logger.constructor.name + JSON.stringify(logger);
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash);
  }

  /**
   * Destroy log manager
   */
  destroy(): void {
    this.removeAllLogger();
    // Log manager destruction completed
  }
}
