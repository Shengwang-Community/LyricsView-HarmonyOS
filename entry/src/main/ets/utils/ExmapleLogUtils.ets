import { hilog } from '@kit.PerformanceAnalysisKit';
import { ExampleConstants } from './ExampleConstants'

export class ExampleLogUtils {
  static logDebug(tag: string, message: string): void {
    hilog.debug(ExampleConstants.LOG_DOMAIN, tag, `%{public}s`, message);
  }

  static logInfo(tag: string, message: string): void {
    hilog.info(ExampleConstants.LOG_DOMAIN, tag, `%{public}s`, message);
  }

  static logWarn(tag: string, message: string): void {
    hilog.warn(ExampleConstants.LOG_DOMAIN, tag, `%{public}s`, message);
  }

  static logError(tag: string, message: string): void {
    hilog.error(ExampleConstants.LOG_DOMAIN, tag, `%{public}s`, message);
  }
}
