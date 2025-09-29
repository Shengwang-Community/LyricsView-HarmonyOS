import { hilog } from '@kit.PerformanceAnalysisKit';
import fs from '@ohos.file.fs';

import { KaraokeView, LyricModel, LyricsCutter } from '@shengwang/lyrics-view';

/**
 * Lyrics statistics information interface
 */
export interface LyricsStats {
  lineCount: number;
  duration: number;
  preludeEnd: number;
}

/**
 * Lyrics service
 * Responsible for loading and processing lyrics data, supports loading from rawfile and MCC
 */
export class LyricsService {
  protected readonly TAG: string = 'LyricsView-LyricsService';
  private karaokeView: KaraokeView | null = null;
  private lyricModel: LyricModel | null = null;

  constructor() {
  }

  /**
   * Set KaraokeView instance
   */
  setKaraokeView(karaokeView: KaraokeView): void {
    this.karaokeView = karaokeView;
  }


  /**
   * Load lyrics data from MCC (new method)
   * @param lyricUrl - Lyrics file path
   * @param pitchUrl - Pitch file path
   * @param songOffsetBegin - Song start offset time (ms)
   * @param songOffsetEnd - Song end offset time (ms)
   * @param lyricOffset - Lyrics offset time (ms)
   */
  async loadLyricsFromMcc(
    lyricUrl: string,
    pitchUrl: string,
    songOffsetBegin: number,
    songOffsetEnd: number,
    lyricOffset: number
  ): Promise<LyricModel | null> {
    try {
      this.logDebug(`Loading loadLyricsFromMcc lyricUrl: ${lyricUrl} pitchUrl: ${pitchUrl} begin=${songOffsetBegin}, end=${songOffsetEnd}, lyricOffset=${lyricOffset}`);

      // Check if file exists
      if (!await this.checkFileExists(lyricUrl)) {
        throw new Error(`Lyric file not found: ${lyricUrl}`);
      }

      // Use KaraokeView to parse lyrics
      if (!this.karaokeView) {
        throw new Error('KaraokeView not initialized');
      }

      // Parse lyrics with offset applied
      const lyricModel: LyricModel | null = this.karaokeView.parseLyrics(lyricUrl, pitchUrl, true, lyricOffset);

      if (!lyricModel) {
        throw new Error('Failed to parse lyrics from MCC');
      }

      this.logDebug(`Successfully parsed MCC lyrics with ${lyricModel.lines?.length ||
        0} duration: ${lyricModel.duration}ms lines preludeEndPosition:${lyricModel.preludeEndPosition}`);

      // If there's song offset, need to cut lyrics
      if (songOffsetBegin > 0 || songOffsetEnd > 0) {
        const startTime = songOffsetBegin;
        const endTime: number = songOffsetEnd > 0 ? songOffsetEnd : (lyricModel.duration || 0);

        const cutResult: LyricModel | null = LyricsCutter.cut(lyricModel, startTime, endTime);
        if (cutResult !== null) {
          this.logDebug(`Successfully cut MCC lyrics, duration: ${cutResult.duration}ms lines preludeEndPosition:${cutResult.preludeEndPosition}`);
          this.lyricModel = cutResult;
          return this.lyricModel;
        }
      }

      this.lyricModel = lyricModel;
      return this.lyricModel;

    } catch (error) {
      this.logDebug(`Failed to load lyrics from MCC: ${error}`);
      return null;
    }
  }

  /**
   * Check if file exists
   * @param filePath - File path
   */
  private async checkFileExists(filePath: string): Promise<boolean> {
    try {
      const stat = await fs.stat(filePath);
      return stat.isFile();
    } catch (error) {
      this.logDebug(`File check failed: ${filePath}, error: ${error}`);
      return false;
    }
  }

  /**
   * Validate lyrics data
   */
  validateLyrics(lyricModel: LyricModel): boolean {
    if (!lyricModel) {
      return false;
    }

    if (!lyricModel.lines || lyricModel.lines.length === 0) {
      this.logDebug('Lyrics validation failed: no lines found');
      return false;
    }

    this.logDebug(`Lyrics validation passed: ${lyricModel.lines.length} lines`);
    return true;
  }

  /**
   * Get lyrics statistics information
   */
  getLyricsStats(lyricModel: LyricModel): LyricsStats {
    const stats: LyricsStats = {
      lineCount: lyricModel.lines?.length || 0,
      duration: lyricModel.duration || 0,
      preludeEnd: lyricModel.preludeEndPosition || 0
    };
    return stats;
  }

  getPreludeEndPosition(): number {
    if (this.lyricModel) {
      return this.lyricModel.preludeEndPosition;
    }
    return 0;
  }

  /**
   * Debug logging
   */
  private logDebug(message: string): void {
    hilog.debug(0x0000, this.TAG, `%{public}s`, message);
  }
}
