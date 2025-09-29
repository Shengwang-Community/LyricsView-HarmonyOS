import hilog from '@ohos.hilog';
import { Constants } from '../constants/Constants';
import { ConsoleLogger, FileLogger, LogManager } from '../internal/logs';

/**
 * Log utility class
 * Integrates new log management system with dual console and file output support
 */
export class LogUtils {
  /**
   * New log manager instance
   */
  private static logManager: LogManager = LogManager.getInstance();
  /**
   * Whether the logging system has been initialized
   */
  private static initialized: boolean = false;
  /**
   * Current console logger instance
   */
  private static currentConsoleLogger: ConsoleLogger | null = null;
  /**
   * Current file logger instance
   */
  private static currentFileLogger: FileLogger | null = null;
  /**
   * Current file log path
   */
  private static currentLogFilePath: string | null = null;

  /**
   * Output debug level log
   * @param msg Log message
   * @param args Format parameters
   */
  static d(msg: string, ...args: (string | number | boolean)[]): void {
    // Use new log manager
    LogUtils.logManager.debug(Constants.TAG, msg);

  }

  /**
   * Output info level log
   * @param msg Log message
   * @param args Format parameters
   */
  static i(msg: string, ...args: (string | number | boolean)[]): void {
    // Use new log manager
    LogUtils.logManager.info(Constants.TAG, msg);
  }

  /**
   * Output warning level log
   * @param msg Log message
   * @param args Format parameters
   */
  static w(msg: string, ...args: (string | number | boolean)[]): void {
    // Use new log manager
    LogUtils.logManager.warn(Constants.TAG, msg);
  }

  /**
   * Output error level log
   * @param msg Log message
   * @param args Format parameters
   */
  static e(msg: string, ...args: (string | number | boolean)[]): void {
    // Use new log manager
    LogUtils.logManager.error(Constants.TAG, msg);
  }

  /**
   * Get log file path
   * @param customPath Custom path (optional)
   * @returns Log file path
   */
  private static getLogFilePath(customPath?: string): string {
    // If custom path is specified, use it directly
    if (customPath) {
      return customPath;
    }

    // If no context, use default path
    // Prefer standard path of application private file directory
    const defaultLogPath: string = '/data/storage/el2/base/haps/entry/files';

    console.info('LogUtils', `Using default log path: ${defaultLogPath}`);
    console.warn('LogUtils',
      'No context provided, using default path. Consider passing context for better path resolution.');
    return defaultLogPath;
  }

  /**
   * Initialize logging system
   * @param enableConsoleLog Whether to enable console logging
   * @param enableFileLog Whether to enable file logging
   * @param logFilePath Log file path (optional)
   */
  private static initializeLogger(
    enableConsoleLog: boolean = true,
    enableFileLog: boolean = true,
    logFilePath?: string
  ): void {
    if (LogUtils.initialized) {
      LogUtils.i('Logger system already initialized');
      return;
    }

    try {
      // Clear existing loggers and state
      LogUtils.logManager.removeAllLogger();
      LogUtils.currentConsoleLogger = null;
      LogUtils.currentFileLogger = null;
      LogUtils.currentLogFilePath = null;

      // Add console logger
      if (enableConsoleLog) {
        LogUtils.currentConsoleLogger = new ConsoleLogger(Constants.DOMAIN);
        LogUtils.logManager.addLogger(LogUtils.currentConsoleLogger);
      }

      // Add file logger
      if (enableFileLog) {
        const finalLogPath = LogUtils.getLogFilePath(logFilePath);

        LogUtils.currentFileLogger = new FileLogger(
          finalLogPath, // Log file path
          Constants.LOG_FILE_NAME, // File name prefix
          1024 * 1024 * 2, // Max file size 2MB
          5, // Max file count
          []// Support all tags
        );

        // Add project-related tags
        LogUtils.currentFileLogger.addSupportTag('LyricsView');
        LogUtils.currentFileLogger.addSupportTag('KaraokeView');
        LogUtils.currentFileLogger.addSupportTag('ScoreView');
        LogUtils.currentFileLogger.addSupportTag('AIAlgorithm');

        LogUtils.logManager.addLogger(LogUtils.currentFileLogger);
        LogUtils.currentLogFilePath = finalLogPath;
        LogUtils.i(`File logger initialized with path: ${finalLogPath}`);
      }

      LogUtils.initialized = true;
      LogUtils.i(`Logger system initialized with ${LogUtils.logManager.getLoggers().length} loggers`);
    } catch (error) {
      hilog.error(Constants.DOMAIN, Constants.TAG, `Failed to initialize logger: ${error}`);
    }
  }

  /**
   * Enable logging functionality (supports dynamic configuration updates)
   * @param enableConsoleLog Whether to enable console logging
   * @param enableFileLog Whether to enable file logging
   * @param logFilePath Log file path (optional, uses default path when empty)
   */
  static enableLog(enableConsoleLog: boolean, enableFileLog: boolean, logFilePath?: string): void {
    try {
      // If first call, perform initialization
      if (!LogUtils.initialized) {
        LogUtils.initializeLogger(enableConsoleLog, enableFileLog, logFilePath);
        return;
      }

      // Dynamically update console logger
      LogUtils.updateConsoleLogger(enableConsoleLog);

      // Dynamically update file logger
      LogUtils.updateFileLogger(enableFileLog, logFilePath);

      LogUtils.i(`Logger configuration updated: console=${enableConsoleLog}, file=${enableFileLog}, path=${logFilePath ||
        'default'}`);
    } catch (error) {
      console.error('LogUtils', `Failed to enable log: ${error}`);
      hilog.error(Constants.DOMAIN, Constants.TAG, `Failed to enable log: ${error}`);
    }
  }

  /**
   * Update console logger
   * @param enable Whether to enable console logging
   */
  private static updateConsoleLogger(enable: boolean): void {
    if (enable) {
      // If need to enable and currently no console logger
      if (!LogUtils.currentConsoleLogger) {
        LogUtils.currentConsoleLogger = new ConsoleLogger(Constants.DOMAIN);
        LogUtils.logManager.addLogger(LogUtils.currentConsoleLogger);
        LogUtils.d('Console logger enabled');
      }
    } else {
      // If need to disable and currently has console logger
      if (LogUtils.currentConsoleLogger) {
        LogUtils.logManager.removeLogger(LogUtils.currentConsoleLogger);
        LogUtils.currentConsoleLogger = null;
        console.log('LogUtils: Console logger disabled');
      }
    }
  }

  /**
   * Update file logger
   * @param enable Whether to enable file logging
   * @param logFilePath Log file path
   */
  private static updateFileLogger(enable: boolean, logFilePath?: string): void {
    if (enable) {
      const finalLogPath = LogUtils.getLogFilePath(logFilePath);

      // If path changed or currently no file logger, need to recreate
      if (!LogUtils.currentFileLogger || LogUtils.currentLogFilePath !== finalLogPath) {
        // Remove old file logger
        if (LogUtils.currentFileLogger) {
          LogUtils.logManager.removeLogger(LogUtils.currentFileLogger);
        }

        // Create new file logger
        LogUtils.currentFileLogger = new FileLogger(
          finalLogPath,
          Constants.LOG_FILE_NAME,
          1024 * 1024 * 2, // 2MB
          5, // Max file count
          []// Support all tags
        );

        // Add project-related tags
        LogUtils.currentFileLogger.addSupportTag('LyricsView');
        LogUtils.currentFileLogger.addSupportTag('KaraokeView');
        LogUtils.currentFileLogger.addSupportTag('ScoreView');
        LogUtils.currentFileLogger.addSupportTag('AIAlgorithm');

        LogUtils.logManager.addLogger(LogUtils.currentFileLogger);
        LogUtils.currentLogFilePath = finalLogPath;
        LogUtils.i(`File logger updated with path: ${finalLogPath}`);
      }
    } else {
      // If need to disable and currently has file logger
      if (LogUtils.currentFileLogger) {
        LogUtils.logManager.removeLogger(LogUtils.currentFileLogger);
        LogUtils.currentFileLogger = null;
        LogUtils.currentLogFilePath = null;
        console.log('LogUtils: File logger disabled');
      }
    }
  }

  /**
   * Destroy logging system (compatible with Android version interface)
   */
  static destroy(): void {
    try {
      // Log destruction (before destroying)
      if (LogUtils.initialized) {
        LogUtils.i('Destroying LogUtils system');
      }

      // Clear logger state
      LogUtils.currentConsoleLogger = null;
      LogUtils.currentFileLogger = null;
      LogUtils.currentLogFilePath = null;

      // Destroy log manager
      LogUtils.logManager.destroy();

      // Reset initialization state
      LogUtils.initialized = false;

      console.log('LogUtils: System destroyed successfully');
    } catch (error) {
      console.error('LogUtils', `Error during destroy: ${error}`);
    }
  }

  /**
   * Reset logging system (complete reinitialization)
   * @param enableConsoleLog Whether to enable console logging
   * @param enableFileLog Whether to enable file logging
   * @param logFilePath Log file path
   */
  static reset(enableConsoleLog: boolean = true, enableFileLog: boolean = true, logFilePath?: string): void {
    LogUtils.destroy();
    LogUtils.enableLog(enableConsoleLog, enableFileLog, logFilePath);
  }
}
