import http from '@ohos.net.http';
import { Constants } from '../constants/Constants';
import { LogUtils } from '../utils/LogUtils';

/**
 * HTTP request callback interface
 */
export interface RequestCallback {
  /**
   * Response data update callback
   * @param bytes Data byte array
   * @param len Current data length
   * @param currentLen Total received length
   * @param total Total file length
   */
  updateResponseData(bytes: Uint8Array, len: number, currentLen: number, total: number): void;

  /**
   * Request failure callback
   * @param errorCode Error code
   * @param msg Error message
   */
  requestFail(errorCode: number, msg: string): void;

  /**
   * Request completion callback
   */
  requestFinish(): void;
}

/**
 * Network error object interface
 */
interface NetworkError {
  code?: number;
  message?: string;
}

/**
 * HTTP URL request class - HarmonyOS version
 * Handles HTTP GET requests with download progress callbacks and cancellation support
 */
export class HttpUrlRequest {
  private mCallback: RequestCallback | null = null;
  private mCancelled: boolean = false;
  private mHttpRequest: http.HttpRequest | null = null;
  private mRequestId: string = '';

  constructor() {
    this.mRequestId = `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Set request callback
   * @param callback Callback interface
   */
  setCallback(callback: RequestCallback): void {
    this.mCallback = callback;
  }

  /**
   * Set cancellation status
   * @param cancelled Whether to cancel
   */
  setCancelled(cancelled: boolean): void {
    this.mCancelled = cancelled;
    if (cancelled && this.mHttpRequest) {
      this.mHttpRequest.destroy();
      this.mHttpRequest = null;
    }
  }

  /**
   * Get cancellation status
   * @returns Whether cancelled
   */
  isCancelled(): boolean {
    return this.mCancelled;
  }

  /**
   * Cancel request
   */
  cancel(): void {
    this.setCancelled(true);
  }

  /**
   * Initiate GET request
   * @param url Request URL
   * @param headers Request headers (optional)
   */
  async requestGetUrl(url: string, headers?: Record<string, string>): Promise<void> {
    if (this.mCancelled) {
      LogUtils.w(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request cancelled before start`);
      return;
    }

    if (!url || url.trim().length === 0) {
      this.notifyRequestFail(Constants.ERROR_GENERAL, 'HttpUrlRequest:URL is empty');
      return;
    }

    LogUtils.d(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Starting GET request to ${url}`);

    try {
      // Create HTTP request
      this.mHttpRequest = http.createHttp();

      // Set request options - use basic configuration to avoid compatibility issues
      // Merge custom headers (avoid using spread operator and for...in)
      const finalHeaders: Record<string, string> = {
        'User-Agent': 'HarmonyOS-LyricsView',
        'Accept': '*/*'
      };

      if (headers) {
        // Use Object.keys to iterate and copy properties
        const headerKeys = Object.keys(headers);
        for (let i = 0; i < headerKeys.length; i++) {
          const key = headerKeys[i];
          finalHeaders[key] = headers[key];
        }
      }

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        connectTimeout: Constants.HTTP_TIMEOUT * 1000, // 15 seconds connection timeout
        readTimeout: Constants.HTTP_TIMEOUT * 1000, // 30 seconds read timeout
        header: finalHeaders,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      };

      // Listen for response headers event
      this.mHttpRequest.on('headersReceive', (header) => {
        if (this.mCancelled) {
          return;
        }
        LogUtils.d(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Headers received: ${JSON.stringify(header)}`);
      });

      // Listen for data receive event
      this.mHttpRequest.on('dataReceive', (data: ArrayBuffer) => {
        if (this.mCancelled) {
          return;
        }

        const uint8Array = new Uint8Array(data);
        const currentLen = uint8Array.length;

        LogUtils.d(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Data received: ${currentLen} bytes`);

        if (this.mCallback) {
          // Note: HarmonyOS dataReceive event doesn't provide total length info, pass -1 to indicate unknown
          this.mCallback.updateResponseData(uint8Array, currentLen, currentLen, -1);
        }
      });

      // Listen for data receive progress event (HarmonyOS may not support this event, commented out)
      // this.mHttpRequest.on('dataProgress', (data: DataProgress) => {
      //   if (this.mCancelled) return;
      //   LogUtils.d(`HttpUrlRequest[${this.mRequestId}]: Progress: ${data.receiveSize}/${data.totalSize}`);
      // });

      // Initiate request
      const response = await this.mHttpRequest.request(url, requestOptions);

      if (this.mCancelled) {
        LogUtils.w(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request cancelled after completion`);
        return;
      }

      // Check response status
      if (response.responseCode === 200) {
        LogUtils.d(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request completed successfully`);

        // If response data is ArrayBuffer, process complete data
        if (response.result instanceof ArrayBuffer) {
          const uint8Array = new Uint8Array(response.result);
          if (this.mCallback) {
            this.mCallback.updateResponseData(uint8Array, uint8Array.length, uint8Array.length, uint8Array.length);
          }
        }

        this.notifyRequestFinish();
      } else {
        const errorMsg = `HTTP ${response.responseCode}: ${response.header}`;
        LogUtils.e(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request failed: ${errorMsg}`);
        this.notifyRequestFail(response.responseCode, errorMsg);
      }

    } catch (error) {
      if (this.mCancelled) {
        LogUtils.w(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request cancelled during execution`);
        return;
      }

      // Improve error message handling
      let errorMsg = 'Network error: Unknown error';
      let errorCode = Constants.ERROR_GENERAL;

      if (error && typeof error === 'object') {
        const errorObj = error as NetworkError;

        // Try to get error message
        if (errorObj.message) {
          errorMsg = `Network error: ${errorObj.message}`;
        } else if (errorObj.code) {
          errorMsg = `Network error: Code ${errorObj.code}`;
        } else {
          errorMsg = `Network error: ${JSON.stringify(error)}`;
        }

        // Set specific error type based on error code
        if (errorObj.code === 2300003) {
          errorCode = Constants.ERROR_HTTP_NOT_CONNECT;
          errorMsg = 'Network error: Connection failed';
        } else if (errorObj.code === 2300006) {
          errorCode = Constants.ERROR_HTTP_UNKNOWN_HOST;
          errorMsg = 'Network error: Unknown host';
        } else if (errorObj.code === 2300007) {
          errorCode = Constants.ERROR_HTTP_TIMEOUT;
          errorMsg = 'Network error: Request timeout';
        } else if (errorObj.code) {
          errorCode = Constants.ERROR_GENERAL;
          errorMsg = `Network error: HTTP error ${errorObj.code}`;
        }
      } else if (typeof error === 'string') {
        errorMsg = `Network error: ${error}`;
      }

      LogUtils.e(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request error: ${errorMsg}`);
      this.notifyRequestFail(errorCode, errorMsg);
    } finally {
      // Clean up resources
      if (this.mHttpRequest) {
        this.mHttpRequest.destroy();
        this.mHttpRequest = null;
      }
    }
  }

  /**
   * Notify request failure
   * @param errorCode Error code
   * @param msg Error message
   */
  private notifyRequestFail(errorCode: number, msg: string): void {
    if (this.mCallback && !this.mCancelled) {
      this.mCallback.requestFail(errorCode, msg);
    }
  }

  /**
   * Notify request completion
   */
  private notifyRequestFinish(): void {
    if (this.mCallback && !this.mCancelled) {
      this.mCallback.requestFinish();
    }
  }

  /**
   * Get request ID
   * @returns Request ID
   */
  getRequestId(): string {
    return this.mRequestId;
  }

  /**
   * Return string representation of request object
   * @returns String representation
   */
  toString(): string {
    return `HttpUrlRequest:HttpUrlRequest{id='${this.mRequestId}', cancelled=${this.mCancelled}}`;
  }
}
