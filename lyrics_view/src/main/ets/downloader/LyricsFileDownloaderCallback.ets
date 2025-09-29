import { DownloadErrorDetail } from '../constants/DownloadError';

/**
 * Lyrics file downloader callback interface - HarmonyOS version
 * Provides methods for tracking download progress and completion status
 */
export interface LyricsFileDownloaderCallback {
  /**
   * Called when download progress is updated
   * @param requestId The ID of the download request
   * @param progress Current download progress (0.0 to 1.0)
   */
  onLyricsFileDownloadProgress(requestId: number, progress: number): void;

  /**
   * Called when download is completed or encounters an error
   * @param requestId The ID of the download request
   * @param fileData Downloaded file data (byte array), null when download fails
   * @param error Error occurred during download process, null when download succeeds
   */
  onLyricsFileDownloadCompleted(requestId: number, fileData: Uint8Array | null,
    error: DownloadErrorDetail | null): void;
}
