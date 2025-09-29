/**
 * Logger interface
 * Based on Agora-LoggingService Logger interface
 */
export interface ILogger {
  /**
   * Dispatch log message to target handler
   * This method should not block
   *
   * @param level Log level
   * @param tag Log tag
   * @param message Log message
   */
  onLog(level: number, tag: string, message: string): void;
}
