/**
 * Log level definitions
 * Corresponds to Android Log class level definitions
 */
export enum LogLevel {
  VERBOSE = 2,
  DEBUG = 3,
  INFO = 4,
  WARN = 5,
  ERROR = 6
}

/**
 * Log level utility class
 */
export class LogLevelUtils {
  /**
   * Get log level name
   * @param logLevel Log level
   * @returns Level name string
   */
  static getLevelName(logLevel: number): string {
    switch (logLevel) {
      case LogLevel.VERBOSE:
        return "V";
      case LogLevel.DEBUG:
        return "D";
      case LogLevel.INFO:
        return "I";
      case LogLevel.WARN:
        return "W";
      case LogLevel.ERROR:
        return "E";
      default:
        if (logLevel < LogLevel.VERBOSE) {
          return `V-${LogLevel.VERBOSE - logLevel}`;
        } else {
          return `E+${logLevel - LogLevel.ERROR}`;
        }
    }
  }
}
