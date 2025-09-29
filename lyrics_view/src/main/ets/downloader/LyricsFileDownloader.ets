import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { Constants } from '../constants/Constants';
import { DownloadErrorDetail } from '../constants/DownloadError';
import { DownloadLyricModel } from '../model/DownloadLyricModel';
import { HttpUrlRequest, RequestCallback } from '../net/HttpUrlRequest';
import { LogUtils } from '../utils/LogUtils';
import { Utils } from '../utils/Utils';
import { ZipUtils } from '../utils/ZipUtils';
import { LyricsFileDownloaderCallback } from './LyricsFileDownloaderCallback';

/**
 * File information interface
 */
interface FileInfo {
  name: string;
  path: string;
  mtime: number;
}

/**
 * Download request callback implementation class
 */
class DownloadRequestCallback implements RequestCallback {
  private requestId: number;
  private url: string;
  private filePath: string;
  private downloaderMap: Map<string, DownloadLyricModel>;
  private callback: LyricsFileDownloaderCallback | null;
  private cancelDownloadFn: (id: number) => void;
  private handleDownloadedFileFn: (id: number, path: string) => void;
  private notifyCompletedFn: (id: number, data: Uint8Array | null, error: DownloadErrorDetail | null) => void;

  constructor(
    requestId: number,
    url: string,
    filePath: string,
    downloaderMap: Map<string, DownloadLyricModel>,
    callback: LyricsFileDownloaderCallback | null,
    cancelDownloadFn: (id: number) => void,
    handleDownloadedFileFn: (id: number, path: string) => void,
    notifyCompletedFn: (id: number, data: Uint8Array | null, error: DownloadErrorDetail | null) => void
  ) {
    this.requestId = requestId;
    this.url = url;
    this.filePath = filePath;
    this.downloaderMap = downloaderMap;
    this.callback = callback;
    this.cancelDownloadFn = cancelDownloadFn;
    this.handleDownloadedFileFn = handleDownloadedFileFn;
    this.notifyCompletedFn = notifyCompletedFn;
  }

  updateResponseData(bytes: Uint8Array, len: number, currentLen: number, total: number): void {
    if (!this.downloaderMap.has(this.url)) {
      return;
    }

    let progress = 0;
    if (total !== -1) {
      progress = Math.floor(currentLen * 100 / total) / 100.0;
    }

    LogUtils.d(`LyricsFileDownloader:download progress requestId: ${this.requestId}, currentLen: ${currentLen}, total: ${total}, progress: ${progress}`);

    if (bytes && len > 0) {
      try {
        const data = bytes.slice(0, len);
        const file = fs.openSync(this.filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
        fs.writeSync(file.fd, data.buffer);
        fs.closeSync(file);
      } catch (error) {
        LogUtils.e(`LyricsFileDownloader:download requestId: ${this.requestId}, write file fail: ${error}`);
      }
    }

    if (this.callback) {
      this.callback.onLyricsFileDownloadProgress(this.requestId, progress);
    }
  }

  requestFail(errorCode: number, msg: string): void {
    if (!this.downloaderMap.has(this.url)) {
      return;
    }

    LogUtils.e(`LyricsFileDownloader:download fail requestId: ${this.requestId}, url: ${this.url}, error: ${errorCode} ${msg}`);
    this.cancelDownloadFn(this.requestId);

    if (this.callback) {
      const downloadError = errorCode < 0 ?
      DownloadErrorDetail.createHttpDownloadError(errorCode, msg) :
      DownloadErrorDetail.createHttpLogicError(errorCode, msg);
      this.notifyCompletedFn(this.requestId, null, downloadError);
    }
  }

  requestFinish(): void {
    if (!this.downloaderMap.has(this.url)) {
      return;
    }

    LogUtils.d(`LyricsFileDownloader:download finish requestId: ${this.requestId}, url: ${this.url} finish`);
    this.handleDownloadedFileFn(this.requestId, this.filePath);
    this.downloaderMap.delete(this.url);
  }
}

/**
 * Lyrics file downloader - HarmonyOS version (simplified)
 * Manages lyrics file downloading and caching, uses ZipUtils for ZIP file extraction
 */
export class LyricsFileDownloader {
  /**
   * Singleton instance
   */
  private static instance: LyricsFileDownloader | null = null;
  /**
   * Application context
   */
  private readonly mContext: common.UIAbilityContext;
  /**
   * Download event callback
   */
  private mLyricsFileDownloaderCallback: LyricsFileDownloaderCallback | null = null;
  /**
   * Maximum number of files to keep in cache
   */
  private mMaxFileNum: number = 50;
  /**
   * Maximum file age in cache (seconds)
   */
  private mMaxFileAge: number = 8 * 60 * 60; // 8 hours

  /**
   * Current request ID counter
   */
  private mRequestId: number = -1;
  /**
   * Active download mapping table
   */
  private readonly mLyricsDownloaderMap: Map<string, DownloadLyricModel> = new Map();
  /**
   * Maximum concurrent downloads
   */
  private static readonly MAX_DOWNLOADER_NUM: number = 3;

  /**
   * Private constructor for singleton pattern
   * @param context Application context
   */
  private constructor(context: common.UIAbilityContext) {
    this.mContext = context;
  }

  /**
   * Gets the singleton instance of LyricsFileDownloader
   * @param context Application context
   * @returns LyricsFileDownloader instance
   */
  static getInstance(context: common.UIAbilityContext): LyricsFileDownloader {
    if (!LyricsFileDownloader.instance) {
      LyricsFileDownloader.instance = new LyricsFileDownloader(context);
    }
    return LyricsFileDownloader.instance;
  }

  /**
   * Sets the download event callback
   * @param callback Callback implementation
   */
  setLyricsFileDownloaderCallback(callback: LyricsFileDownloaderCallback): void {
    this.mLyricsFileDownloaderCallback = callback;
  }

  /**
   * Sets the maximum number of files to keep in cache
   * @param maxFileNum Maximum file count
   */
  setMaxFileNum(maxFileNum: number): void {
    LogUtils.d(`LyricsFileDownloader:setMaxFileNum maxFileNum: ${maxFileNum}`);
    if (maxFileNum <= 0) {
      LogUtils.e('LyricsFileDownloader:setMaxFileNum maxFileNum is invalid');
      return;
    }
    this.mMaxFileNum = maxFileNum;
  }

  /**
   * Sets the maximum file age in cache
   * @param maxFileAge Maximum file age (seconds)
   */
  setMaxFileAge(maxFileAge: number): void {
    LogUtils.d(`LyricsFileDownloader:setMaxFileAge maxFileAge: ${maxFileAge}`);
    if (maxFileAge <= 0) {
      LogUtils.e('LyricsFileDownloader:setMaxFileAge maxFileAge is invalid');
      return;
    }
    this.mMaxFileAge = maxFileAge;
  }

  /**
   * Starts downloading a lyrics file
   * @param url URL of the lyrics file to download
   * @returns Request ID of the download task
   */
  download(url: string): number {
    if (!this.mContext) {
      LogUtils.e('LyricsFileDownloader:download context is null');
      return Constants.ERROR_GENERAL;
    }
    if (!url || url.trim().length === 0) {
      LogUtils.e('LyricsFileDownloader:download url is null or empty');
      return Constants.ERROR_GENERAL;
    }

    LogUtils.d(`LyricsFileDownloader:download url: ${url}`);

    // Check if already downloading
    if (this.mLyricsDownloaderMap.has(url)) {
      LogUtils.i('LyricsFileDownloader:download url is already downloading');
      const model = this.mLyricsDownloaderMap.get(url);
      if (model) {
        this.notifyLyricsFileDownloadCompleted(model.getRequestId(), null,
          DownloadErrorDetail.createRepeatDownloadingError());
        return model.getRequestId();
      } else {
        this.mLyricsDownloaderMap.delete(url);
        LogUtils.e(`LyricsFileDownloader:download exception and remove downloading url: ${url}`);
      }
    }

    // Create download directory
    const folder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_DOWNLOAD_DIR}`;
    if (!fs.accessSync(folder)) {
      fs.mkdirSync(folder, true);
    }

    // Generate request ID
    if (this.mRequestId + 1 === Number.MAX_SAFE_INTEGER) {
      this.mRequestId = -1;
    }
    this.mRequestId++;

    // Check file age
    this.checkFileAge(folder);

    // Generate file name
    let urlFileName = url.substring(url.lastIndexOf('/') + 1);
    if (!urlFileName || urlFileName.trim().length === 0) {
      urlFileName = `${Date.now()}.${Constants.FILE_EXTENSION_ZIP}`;
    }
    const filePath = `${folder}/${urlFileName}`;

    // Check if file already exists
    if (fs.accessSync(filePath)) {
      LogUtils.d(`LyricsFileDownloader:download ${filePath} exists`);
      this.handleDownloadedFile(this.mRequestId, filePath);
      return this.mRequestId;
    }

    // Create download model
    const model = new DownloadLyricModel();
    model.setUrl(url);
    model.setFilePath(filePath);
    model.setRequestId(this.mRequestId);

    const request = new HttpUrlRequest();
    model.setHttpUrlRequest(request);
    this.mLyricsDownloaderMap.set(url, model);

    const downloadRequestId = this.mRequestId;

    // Start download
    this.startDownload(downloadRequestId, url, filePath, request);

    return this.mRequestId;
  }

  /**
   * Starts the download task
   */
  private startDownload(requestId: number, url: string, filePath: string, request: HttpUrlRequest): void {
    LogUtils.d(`LyricsFileDownloader:startDownload requestId: ${requestId}, url: ${url}, saveTo: ${filePath}`);

    const callback = new DownloadRequestCallback(
      requestId,
      url,
      filePath,
      this.mLyricsDownloaderMap,
      this.mLyricsFileDownloaderCallback,
      (id: number) => this.cancelDownload(id),
      (id: number, path: string) => this.handleDownloadedFile(id, path),
      (id: number, data: Uint8Array | null, error: DownloadErrorDetail | null) =>
      this.notifyLyricsFileDownloadCompleted(id, data, error)
    );

    request.setCallback(callback);

    request.requestGetUrl(url, undefined);
  }

  /**
   * Handles downloaded files, including extraction when necessary
   */
  private async handleDownloadedFile(requestId: number, filePath: string): Promise<void> {
    LogUtils.d(`LyricsFileDownloader:handleDownloadedFile requestId: ${requestId}, file: ${filePath}`);

    const folder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_DOWNLOAD_DIR}`;
    await this.checkFileAge(folder);

    if (!fs.accessSync(filePath)) {
      LogUtils.e('LyricsFileDownloader:handleDownloadedFile file does not exist');
      this.notifyLyricsFileDownloadCompleted(requestId, null,
        DownloadErrorDetail.createHttpDownloadError(Constants.ERROR_GENERAL, 'File does not exist'));
      return;
    }

    const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);

    if (fileName.toLowerCase().endsWith(Constants.FILE_EXTENSION_ZIP)) {
      LogUtils.d('LyricsFileDownloader:handleDownloadedFile file is zip file');
      await this.handleZipFile(requestId, filePath);
    } else if (this.isSupportLyricsFile(fileName)) {
      LogUtils.d(`LyricsFileDownloader:handleDownloadedFile file is ${this.getFileExtension(fileName)} file`);
      await this.handleLyricsFile(requestId, filePath, false);
    } else {
      LogUtils.e('LyricsFileDownloader:handleDownloadedFile unknown file format and return directly');
      const error = DownloadErrorDetail.createUnzipFailError('Unsupported file format');
      error.setErrorCode(Constants.ERROR_UNZIP_ERROR);
      this.notifyLyricsFileDownloadCompleted(requestId, null, error);
    }
  }

  /**
   * Handles ZIP file extraction (using ZipUtils)
   */
  private async handleZipFile(requestId: number, zipFilePath: string): Promise<void> {
    try {
      LogUtils.d('LyricsFileDownloader:handleZipFile processing ZIP file with ZipUtils');

      // Create temporary directory
      const tempFolder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_TEMP_DIR}`;
      if (!fs.accessSync(tempFolder)) {
        fs.mkdirSync(tempFolder, true);
      }

      // Extract file using ZipUtils
      const result = await ZipUtils.extractZipFile(zipFilePath, tempFolder);

      if (result.success && result.data && result.fileName) {
        LogUtils.d(`LyricsFileDownloader:handleZipFile extraction successful, original content: ${result.isOriginalContent}`);

        // Build extracted file path
        const extractedFilePath = `${tempFolder}/${result.fileName}`;

        // Handle extracted lyrics file
        await this.handleLyricsFile(requestId, extractedFilePath, true);
      } else {
        throw new Error(result.error || 'ZIP extraction failed');
      }

    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:handleZipFile error: ${error}`);
      this.notifyLyricsFileDownloadCompleted(requestId, null,
        DownloadErrorDetail.createUnzipFailError(`ZIP extraction failed: ${error}`));
    }
  }

  /**
   * Handles lyrics file and notifies completion
   */
  private async handleLyricsFile(requestId: number, lyricFilePath: string, deleteLyricsFile: boolean): Promise<void> {
    try {
      const fileData = await Utils.getFileBytes(lyricFilePath);
      this.notifyLyricsFileDownloadCompleted(requestId, fileData, null);

      if (deleteLyricsFile && fs.accessSync(lyricFilePath)) {
        LogUtils.d(`LyricsFileDownloader:handleLyricsFile delete file: ${lyricFilePath}`);
        fs.unlinkSync(lyricFilePath);
      }

      LogUtils.d('LyricsFileDownloader:handleLyricsFile success');
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:handleLyricsFile error: ${error}`);
      this.notifyLyricsFileDownloadCompleted(requestId, null,
        DownloadErrorDetail.createUnzipFailError(`Failed to process lyrics file: ${error}`));
    }
  }

  /**
   * Checks if the file is a supported lyrics format
   */
  private isSupportLyricsFile(fileName: string): boolean {
    const lowerName = fileName.toLowerCase();
    return lowerName.endsWith(`.${Constants.FILE_EXTENSION_XML}`) ||
    lowerName.endsWith(`.${Constants.FILE_EXTENSION_LRC}`) ||
    lowerName.endsWith(`.${Constants.FILE_EXTENSION_KRC}`);
  }

  /**
   * Gets the file extension
   */
  private getFileExtension(fileName: string): string {
    const lastDot = fileName.lastIndexOf('.');
    return lastDot > 0 ? fileName.substring(lastDot + 1).toLowerCase() : '';
  }

  /**
   * Checks and deletes expired files
   */
  private async checkFileAge(folder: string): Promise<void> {
    try {
      if (!fs.accessSync(folder)) {
        return;
      }

      const files = fs.listFileSync(folder);
      LogUtils.d(`LyricsFileDownloader:checkFileAge files: ${files.join(', ')}`);

      const now = Date.now();

      for (const fileName of files) {
        const filePath = `${folder}/${fileName}`;
        try {
          const stat = fs.statSync(filePath);
          if (stat.isFile() && (now - stat.mtime * 1000 > this.mMaxFileAge * 1000)) {
            LogUtils.d(`LyricsFileDownloader:checkFileAge delete expired file: ${filePath}`);
            fs.unlinkSync(filePath);
          }
        } catch (error) {
          LogUtils.e(`LyricsFileDownloader:checkFileAge error processing ${filePath}: ${error}`);
        }
      }
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:checkFileAge error: ${error}`);
    }
  }

  /**
   * Notifies callback of download completion
   */
  private notifyLyricsFileDownloadCompleted(requestId: number, lyricFileData: Uint8Array | null,
    error: DownloadErrorDetail | null): void {
    this.checkMaxFileNum();

    if (this.mLyricsFileDownloaderCallback) {
      if (lyricFileData) {
        LogUtils.d(`LyricsFileDownloader:notifyLyricsFileDownloadCompleted requestId: ${requestId}, data size: ${lyricFileData.length}, error: ${error}`);
        this.mLyricsFileDownloaderCallback.onLyricsFileDownloadCompleted(requestId, lyricFileData, null);
      } else {
        LogUtils.d(`LyricsFileDownloader:notifyLyricsFileDownloadCompleted requestId: ${requestId}, data is null, error: ${error}`);
        this.mLyricsFileDownloaderCallback.onLyricsFileDownloadCompleted(requestId, null, error);
      }
    } else {
      LogUtils.d('LyricsFileDownloader:notifyLyricsFileDownloadCompleted callback is null');
    }
  }

  /**
   * Checks and enforces maximum file count limit
   */
  private checkMaxFileNum(): void {
    try {
      const folder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_DOWNLOAD_DIR}`;
      if (!fs.accessSync(folder)) {
        LogUtils.i('LyricsFileDownloader:checkMaxFileNum folder does not exist');
        return;
      }

      const files = fs.listFileSync(folder);
      const fileInfos: Array<FileInfo> = [];

      for (const fileName of files) {
        const filePath = `${folder}/${fileName}`;
        try {
          const stat = fs.statSync(filePath);
          if (stat.isFile()) {
            fileInfos.push({
              name: fileName,
              path: filePath,
              mtime: stat.mtime
            });
          }
        } catch (error) {
          LogUtils.e(`LyricsFileDownloader:checkMaxFileNum error getting stat for ${filePath}: ${error}`);
        }
      }

      if (fileInfos.length <= this.mMaxFileNum) {
        LogUtils.d(`LyricsFileDownloader:checkMaxFileNum file count ${fileInfos.length} is within limit ${this.mMaxFileNum}`);
        return;
      }

      // Sort by modification time, delete oldest files
      fileInfos.sort((a, b) => a.mtime - b.mtime);

      const filesToDelete = fileInfos.length - this.mMaxFileNum;
      for (let i = 0; i < filesToDelete; i++) {
        if (this.maybeDeleteFile(fileInfos[i].path)) {
          LogUtils.d(`LyricsFileDownloader:checkMaxFileNum deleted old file: ${fileInfos[i].path}`);
        }
      }
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:checkMaxFileNum error: ${error}`);
    }
  }

  /**
   * Attempts to delete a file (if not currently being downloaded)
   */
  private maybeDeleteFile(filePath: string): boolean {
    if (!fs.accessSync(filePath)) {
      return true;
    }

    // Check if there's an active download task for this file
    for (const model of this.mLyricsDownloaderMap.values()) {
      if (model && model.getFilePath() === filePath) {
        return false; // File is being downloaded, cannot delete
      }
    }

    try {
      fs.unlinkSync(filePath);
      return true;
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:maybeDeleteFile error deleting ${filePath}: ${error}`);
      return false;
    }
  }

  /**
   * Cancels an ongoing download
   */
  cancelDownload(requestId: number): void {
    if (!this.mContext) {
      LogUtils.e('LyricsFileDownloader:cancelDownload context is null');
      return;
    }

    LogUtils.d(`LyricsFileDownloader:cancelDownload requestId: ${requestId}`);

    let urlToRemove = '';
    for (const entry of this.mLyricsDownloaderMap.entries()) {
      const url = entry[0];
      const model = entry[1];
      if (model && model.getRequestId() === requestId) {
        const httpRequest = model.getHttpUrlRequest();
        if (httpRequest) {
          httpRequest.setCancelled(true);
        }
        urlToRemove = url;

        // Delete temporary file
        const tempFilePath = model.getFilePath();
        if (fs.accessSync(tempFilePath)) {
          try {
            fs.unlinkSync(tempFilePath);
          } catch (error) {
            LogUtils.e(`LyricsFileDownloader:cancelDownload error deleting temp file: ${error}`);
          }
        }
        break;
      }
    }

    if (urlToRemove) {
      this.mLyricsDownloaderMap.delete(urlToRemove);
    }
  }

  /**
   * Cleans all download files from cache
   */
  cleanAll(): void {
    if (!this.mContext) {
      LogUtils.e('LyricsFileDownloader:cleanAll context is null');
      return;
    }

    const folder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_DOWNLOAD_DIR}`;
    let isCleanAllSuccess = true;

    try {
      if (fs.accessSync(folder)) {
        const files = fs.listFileSync(folder);
        for (const fileName of files) {
          const filePath = `${folder}/${fileName}`;
          try {
            const stat = fs.statSync(filePath);
            if (stat.isFile()) {
              fs.unlinkSync(filePath);
            }
          } catch (error) {
            LogUtils.e(`LyricsFileDownloader:cleanAll delete file ${filePath} error: ${error}`);
            isCleanAllSuccess = false;
          }
        }
      }
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:cleanAll error: ${error}`);
      isCleanAllSuccess = false;
    }

    LogUtils.d(`LyricsFileDownloader:cleanAll isCleanAllSuccess: ${isCleanAllSuccess}`);
  }
}
