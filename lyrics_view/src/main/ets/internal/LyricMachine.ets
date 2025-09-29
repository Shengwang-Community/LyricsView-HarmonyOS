import { LyricType } from '../constants/LyricType';
import { LyricModel } from '../model/LyricModel';
import { LogUtils } from '../utils/LogUtils';

/**
 * Interface for handling lyric-related events
 */
export interface OnLyricListener {
  /**
   * Called when UI needs to be reset
   */
  resetUi(): void;

  /**
   * Called when UI refresh is requested
   */
  requestRefreshUi(): void;
}

/**
 * State/Information manager for playing/rendering/on-going lyrics.
 * This class handles the non-UI related logic and is shared by all components.
 * It manages the lyrics model, progress tracking, and UI update notifications.
 */
export class LyricMachine {
  /**
   * The current lyrics model being processed
   */
  private mLyricsModel: LyricModel | null = null;
  /**
   * Listener for lyric-related events
   */
  private readonly mListener: OnLyricListener;
  /**
   * Current progress of lyrics playback in milliseconds
   */
  private mCurrentLyricProgress: number = 0;
  /**
   * Empty lyrics model used as a fallback
   */
  private static readonly EMPTY_LYRICS_MODEL: LyricModel = new LyricModel(LyricType.LRC);

  /**
   * Constructs a new LyricMachine instance
   *
   * @param listener The listener to handle lyric-related events
   */
  constructor(listener: OnLyricListener) {
    this.reset();
    this.mListener = listener;
  }

  /**
   * Sets the lyrics data and prepares for rendering
   *
   * @param model The lyrics model to be processed
   */
  prepare(model: LyricModel | null): void {
    this.reset();

    if (!model || !model.lines || model.lines.length === 0) {
      LogUtils.e("Invalid lyrics model, use built-in EMPTY_LYRICS_MODEL");
      this.mLyricsModel = LyricMachine.EMPTY_LYRICS_MODEL;
    } else {
      this.mLyricsModel = model;
    }

    // Notify UI to refresh
    this.mListener.requestRefreshUi();
    LogUtils.d(`LyricMachine: prepare completed, model set: ${!!this.mLyricsModel}, lines: ${this.mLyricsModel?.lines?.length ||
      0}`);
  }

  /**
   * Checks if the lyrics machine is ready for operation
   *
   * @return true if lyrics model is set, false otherwise
   */
  isReady(): boolean {
    return this.mLyricsModel !== null;
  }

  /**
   * Updates the lyrics progress
   *
   * @param progress Current playback time in milliseconds.
   *                 Note: progress must be greater than the lyrics end time to trigger the callback for the last line
   */
  setProgress(progress: number): void {
    if (progress <= 0) {
      this.resetStats();
      if (this.mListener) {
        this.mListener.resetUi();
      }
    }
    this.mCurrentLyricProgress = progress;

    if (!this.mLyricsModel) {
      if (this.mListener) {
        this.mListener.resetUi();
      }
      return;
    }

    if (this.mListener) {
      this.mListener.requestRefreshUi();
    }
  }

  /**
   * Handles progress updates when dragging occurs
   *
   * @param progress The new progress position in milliseconds
   */
  whenDraggingHappen(progress: number): void {
    this.minorReset();
    this.mCurrentLyricProgress = progress;
  }

  /**
   * Resets all states and properties
   */
  reset(): void {
    this.resetProperties();
    this.resetStats();
    this.resetUi()
  }

  /**
   * Resets properties when song changes
   */
  private resetProperties(): void {
    this.mLyricsModel = null;
  }

  /**
   * Resets statistics and progress
   */
  private resetStats(): void {
    this.minorReset();
  }

  /**
   * Resets the UI through listener callback
   */
  private resetUi() {
    if (this.mListener) {
      this.mListener.resetUi();
    }
  }

  /**
   * Performs a minor reset that will recover immediately
   */
  private minorReset(): void {
    this.mCurrentLyricProgress = 0;
  }

  /**
   * Gets the current lyrics model
   *
   * @return The current lyrics model
   */
  getLyricsModel(): LyricModel | null {
    return this.mLyricsModel;
  }

  /**
   * Gets the current lyrics progress
   *
   * @return Current progress in milliseconds
   */
  getCurrentLyricProgress(): number {
    return this.mCurrentLyricProgress;
  }
}
