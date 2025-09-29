import { LyricsLineModel } from './model/LyricsLineModel';

/**
 * Karaoke event listener interface
 */
export interface IKaraokeEvent {
  /**
   * Called automatically when lyrics is dragged
   * <p>
   * Do not block this callback
   *
   * @param progress progress in milliseconds
   */
  onDragTo(progress: number): void;

  /**
   * Called automatically when the line is finished
   * <p>
   * Do not block this callback
   *
   * @param line            LyricsLineModel
   * @param score           Current line score (0-100)
   * @param cumulativeScore Total cumulative score
   * @param index           Current line index (0-based)
   * @param lineCount       Total number of lines
   */
  onLineFinished(line: LyricsLineModel, score: number,
    cumulativeScore: number, index: number, lineCount: number): void;
}
