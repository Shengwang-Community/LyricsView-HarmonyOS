import { HttpUrlRequest } from '../net/HttpUrlRequest';

/**
 * Lyric download request model class
 * Contains information related to download requests, including URL, file path, and HTTP request object
 */
export class DownloadLyricModel {
  private mRequestId: number = 0;
  private mUrl: string = '';
  private mFilePath: string = '';
  private mHttpUrlRequest: HttpUrlRequest | null = null;

  /**
   * Gets the request identifier
   * @returns The request ID
   */
  getRequestId(): number {
    return this.mRequestId;
  }

  /**
   * Sets the request identifier
   * @param requestId The request ID
   */
  setRequestId(requestId: number): void {
    this.mRequestId = requestId;
  }

  /**
   * Gets the URL of the lyric file
   * @returns The URL string
   */
  getUrl(): string {
    return this.mUrl;
  }

  /**
   * Sets the URL of the lyric file
   * @param url The URL string
   */
  setUrl(url: string): void {
    this.mUrl = url;
  }

  /**
   * Gets the local file path for saving lyrics
   * @returns The file path string
   */
  getFilePath(): string {
    return this.mFilePath;
  }

  /**
   * Sets the local file path for saving lyrics
   * @param filePath The file path string
   */
  setFilePath(filePath: string): void {
    this.mFilePath = filePath;
  }

  /**
   * Gets the HTTP request object
   * @returns The HTTP request object
   */
  getHttpUrlRequest(): HttpUrlRequest | null {
    return this.mHttpUrlRequest;
  }

  /**
   * Sets the HTTP request object
   * @param httpUrlRequest The HTTP request object
   */
  setHttpUrlRequest(httpUrlRequest: HttpUrlRequest): void {
    this.mHttpUrlRequest = httpUrlRequest;
  }

  /**
   * Returns the string representation of the download model
   * @returns A string containing all model properties
   */
  toString(): string {
    return `DownloadLyricModel{requestId=${this.mRequestId}, url='${this.mUrl}', filePath='${this.mFilePath}', httpUrlRequest=${this.mHttpUrlRequest}}`;
  }

  /**
   * Checks if the model is valid
   * @returns Whether the model contains necessary information
   */
  isValid(): boolean {
    return this.mRequestId > 0 &&
      this.mUrl.length > 0 &&
      this.mFilePath.length > 0 &&
      this.mHttpUrlRequest !== null;
  }

  /**
   * Cleans up resources
   */
  cleanup(): void {
    if (this.mHttpUrlRequest) {
      this.mHttpUrlRequest.cancel();
      this.mHttpUrlRequest = null;
    }
    this.mUrl = '';
    this.mFilePath = '';
    this.mRequestId = 0;
  }
}
