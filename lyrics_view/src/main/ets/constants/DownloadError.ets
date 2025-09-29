/**
 * Download error enumeration - HarmonyOS version
 * Defines various error scenarios that may occur during download operations
 */
export enum DownloadError {
  /**
   * General download error
   */
  GENERAL = 0,

  /**
   * Repeat download error (file is being downloaded)
   */
  REPEAT_DOWNLOADING = 1,

  /**
   * HTTP download error
   */
  HTTP_DOWNLOAD_ERROR = 2,

  /**
   * HTTP download logic error
   */
  HTTP_DOWNLOAD_ERROR_LOGIC = 3,

  /**
   * File unzip failure
   */
  UNZIP_FAIL = 4
}

/**
 * Download error detail class
 * Contains error type, error code and error message
 */
export class DownloadErrorDetail {
  private mType: DownloadError;
  private mErrorCode: number = 0;
  private mMessage: string = '';

  constructor(type: DownloadError) {
    this.mType = type;
  }

  /**
   * Get error type
   * @returns Error type
   */
  getType(): DownloadError {
    return this.mType;
  }

  /**
   * Get error code
   * @returns Error code
   */
  getErrorCode(): number {
    return this.mErrorCode;
  }

  /**
   * Set error code
   * @param errorCode Error code
   */
  setErrorCode(errorCode: number): void {
    this.mErrorCode = errorCode;
  }

  /**
   * Get error message
   * @returns Error message
   */
  getMessage(): string {
    return this.mMessage;
  }

  /**
   * Set error message
   * @param message Error message
   */
  setMessage(message: string): void {
    this.mMessage = message;
  }

  /**
   * Convert to string representation
   * @returns String containing error name, type, error code and message
   */
  toString(): string {
    return `DownloadError{type=${this.mType}, errorCode=${this.mErrorCode}, message='${this.mMessage}'}`;
  }

  /**
   * Create general error
   * @param message Error message
   * @returns Error detail object
   */
  static createGeneralError(message: string = ''): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.GENERAL);
    error.setMessage(message);
    return error;
  }

  /**
   * Create repeat downloading error
   * @param message Error message
   * @returns Error detail object
   */
  static createRepeatDownloadingError(message: string = 'File is being downloaded'): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.REPEAT_DOWNLOADING);
    error.setMessage(message);
    return error;
  }

  /**
   * Create HTTP download error
   * @param errorCode Error code
   * @param message Error message
   * @returns Error detail object
   */
  static createHttpDownloadError(errorCode: number, message: string = ''): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.HTTP_DOWNLOAD_ERROR);
    error.setErrorCode(errorCode);
    error.setMessage(message);
    return error;
  }

  /**
   * Create HTTP logic error
   * @param errorCode Error code
   * @param message Error message
   * @returns Error detail object
   */
  static createHttpLogicError(errorCode: number, message: string = ''): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.HTTP_DOWNLOAD_ERROR_LOGIC);
    error.setErrorCode(errorCode);
    error.setMessage(message);
    return error;
  }

  /**
   * Create unzip failure error
   * @param message Error message
   * @returns Error detail object
   */
  static createUnzipFailError(message: string = 'File unzip failed'): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.UNZIP_FAIL);
    error.setMessage(message);
    return error;
  }
}
