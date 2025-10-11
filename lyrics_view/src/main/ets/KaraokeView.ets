import { IKaraokeEvent } from './IKaraokeEvent';
import { IScoringAlgorithm } from './IScoringAlgorithm';
import { LyricsParser } from './internal/parser/LyricsParser';
import { LyricModel } from './model/LyricModel';
import { EventBus, KaraokeEvents, LyricsEvents, ScoringEvents } from './utils/EventBus';
import { LogUtils } from './utils/LogUtils';
import { VERSION } from './config/ProjectConfig';

/**
 * Karaoke main controller
 * Manages lyrics display, scoring and synchronization between different components
 */
export class KaraokeView {
  /**
   * Karaoke event listener
   */
  private mKaraokeEvent?: IKaraokeEvent;
  /**
   * Event bus instance
   */
  private eventBus: EventBus = EventBus.getInstance();
  /**
   * Whether the instance has been destroyed
   */
  private isDestroyed: boolean = false;
  // Event listener references for later removal
  private dragStartListener = () => {
    LogUtils.d('KaraokeView: Drag start received');
  };
  private dragEndListener = (finalProgress: number) => {
    LogUtils.d(`KaraokeView: Drag end received: ${finalProgress}ms`);
    if (this.mKaraokeEvent) {
      this.mKaraokeEvent.onDragTo(finalProgress);
    }
  };

  /**
   * Default constructor
   */
  constructor() {
    this.initialize();
  }

  /**
   * Initialize karaoke components, including lyrics and scoring machine
   */
  private initialize(): void {
    if (this.isDestroyed) {
      LogUtils.w('KaraokeView initialize called on destroyed instance');
      return;
    }

    // Output SDK version info
    LogUtils.i('========================================');
    LogUtils.i(`Version: ${KaraokeView.getSdkVersion()}`);
    LogUtils.i('========================================');

    LogUtils.d('KaraokeView initialize');
    LogUtils.enableLog(true, true);

    // Setup drag event listeners
    this.setupDragEventListeners();
  }

  /**
   * Get SDK version
   * @returns SDK version string
   */
  static getSdkVersion(): string {
    return VERSION;
  }

  /**
   * Setup drag event listeners
   */
  private setupDragEventListeners(): void {
    // Listen for drag start events
    this.eventBus.on(LyricsEvents.DRAG_START, this.dragStartListener);

    // Listen for drag end events
    this.eventBus.on(LyricsEvents.DRAG_END, this.dragEndListener);
  }

  /**
   * Parse lyrics data from file path or byte array
   *
   * @param lyricSource Lyrics file path (string) or byte data (Uint8Array)
   * @param pitchSource Pitch file path (string) or byte data (Uint8Array), optional
   * @param includeCopyrightSentence Whether to include copyright information
   * @param lyricOffset Timing offset for lyrics
   * @return Parsed lyrics model
   */
  parseLyrics(
    lyricSource: string | Uint8Array,
    pitchSource?: string | Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    LogUtils.d(`KaraokeView parseLyrics lyricSource type:${typeof lyricSource}, pitchSource type:${typeof pitchSource}, includeCopyrightSentence:${includeCopyrightSentence}, lyricOffset:${lyricOffset}`);

    try {
      // Dispatch processing logic based on input type
      if (typeof lyricSource === 'string') {
        // Handle file path
        const pitchPath = typeof pitchSource === 'string' ? pitchSource : undefined;
        return LyricsParser.parseFile(lyricSource, pitchPath, includeCopyrightSentence, lyricOffset);
      } else if (lyricSource instanceof Uint8Array) {
        // Handle byte array
        const pitchData = pitchSource instanceof Uint8Array ? pitchSource : undefined;
        return LyricsParser.parseLyricData(lyricSource, pitchData, includeCopyrightSentence, lyricOffset);
      } else {
        LogUtils.e('Invalid lyric source type. Expected string or Uint8Array.');
        return null;
      }
    } catch (error) {
      LogUtils.e(`parseLyrics error: ${error}`);
      return null;
    }
  }

  /**
   * Reset all components (via event bus)
   */
  reset(): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d('KaraokeView reset');

    // Notify components to reset via event bus
    this.eventBus.emit(LyricsEvents.RESET);
    this.eventBus.emit(ScoringEvents.RESET);
  }

  /**
   * Set lyrics data and initialize scoring system
   *
   * @param model Lyrics model containing timing and text data
   * @param usingInternalScoring Whether to use internal scoring algorithm
   */
  setLyricData(model: LyricModel, usingInternalScoring: boolean = false): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d(`KaraokeView setLyricDatasetLyricData model lines:${model.lines.length} usingInternalScoring:${usingInternalScoring}`);
    // Notify components via event bus
    this.eventBus.emit(LyricsEvents.SET_LYRIC_DATA, model);
    this.eventBus.emit(ScoringEvents.SET_LYRIC_DATA, model, usingInternalScoring);
  }

  /**
   * Set real-time pitch data from microphone input
   * Note: Can be obtained from AgoraRTC DRM callback method 'onPitch' (50ms interval)
   *
   * @param speakerPitch Current pitch value from singer (Hz, typically 80-2000)
   * @param pitchScore Current pitch score (0.0 to 100.0, float precision)
   */
  setPitch(speakerPitch: number, pitchScore: number): void {
    if (this.checkDestroyed()) {
      return;
    }

    if (speakerPitch < 0 || speakerPitch > 5000) {
      LogUtils.w(`Invalid speaker pitch: ${speakerPitch}, expected 0-5000 Hz`);
    }
    if (pitchScore < 0 || pitchScore > 100) {
      LogUtils.w(`Invalid pitch score: ${pitchScore}, expected 0.0-100.0`);
    }

    //LogUtils.d(`KaraokeView:setPitch speakerPitch:${speakerPitch.toFixed(2)}, pitchScore:${pitchScore.toFixed(1)}, progressInMs:${Math.floor(progressInMs)}ms`) ;

    // Send pitch data to ScoringView via event bus
    this.eventBus.emit(ScoringEvents.SET_PITCH, speakerPitch, pitchScore);
  }

  /**
   * Set current song progress (should be called every 20ms)
   * Note: Can be obtained from the player's current progress
   *
   * @param progress Current song progress in milliseconds
   */
  setProgress(progress: number): void {
    if (this.checkDestroyed()) {
      return;
    }

    if (progress < 0) {
      return;
    }

    //LogUtils.d(`KaraokeView:setProgress progress:${progress}`) ;
    // Notify components via event bus
    this.eventBus.emit(LyricsEvents.SET_PROGRESS, progress);
    this.eventBus.emit(ScoringEvents.SET_PROGRESS, progress);
  }

  /**
   * Set event listener for karaoke callbacks
   *
   * @param event Karaoke event listener
   */
  setKaraokeEvent(event: IKaraokeEvent): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d(`setKaraokeEvent event:${event}`);
    this.mKaraokeEvent = event;
  }

  /**
   * Set custom scoring algorithm, internal scoring feature is not supported yet
   *
   * @param algorithm Custom scoring algorithm implementation
   */
  private setScoringAlgorithm(algorithm: IScoringAlgorithm): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d(`setScoringAlgorithm algorithm:${algorithm}`);

    // Send scoring algorithm to ScoringView via event bus
    this.eventBus.emit(ScoringEvents.SET_SCORING_ALGORITHM, algorithm);
  }

  /**
   * Set scoring difficulty level, not supported yet
   *
   * @param level Scoring difficulty level
   */
  private setScoringLevel(level: number): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d(`setScoringLevel level:${level}`);

    // Send scoring difficulty to ScoringView via event bus
    this.eventBus.emit(ScoringEvents.SET_SCORING_LEVEL, level);
  }

  /**
   * Actively destroy KaraokeView
   * Clean up all resources including event listeners, timers, etc.
   * After calling this method, the KaraokeView instance cannot be used anymore
   */
  destroy(): void {
    if (this.isDestroyed) {
      LogUtils.w('KaraokeView destroy called on already destroyed instance');
      return;
    }

    LogUtils.d('KaraokeView destroy called - cleaning up resources');
    this.doDestroy();
  }

  /**
   * Internal destroy logic
   * Performs actual resource cleanup work
   */
  private doDestroy(): void {
    try {
      // Mark as destroyed
      this.isDestroyed = true;

      // Remove all event listeners
      this.removeAllEventListeners();

      // Notify all components to destroy via event bus
      this.eventBus.emit(LyricsEvents.DESTROY);
      this.eventBus.emit(ScoringEvents.DESTROY);
      this.eventBus.emit(KaraokeEvents.DESTROY);

      // Clear event listener references
      this.mKaraokeEvent = undefined;

      // Destroy logging system
      LogUtils.destroy();

      LogUtils.d('KaraokeView: Destroy completed successfully');
    } catch (error) {
      LogUtils.e(`KaraokeView: Error during destroy: ${error}`);
    }
  }

  /**
   * Remove all event listeners
   */
  private removeAllEventListeners(): void {
    try {
      // Remove drag event listeners
      this.eventBus.off(LyricsEvents.DRAG_START, this.dragStartListener);
      this.eventBus.off(LyricsEvents.DRAG_END, this.dragEndListener);

      LogUtils.d('KaraokeView: All event listeners removed');
    } catch (error) {
      LogUtils.e(`KaraokeView: Error removing event listeners: ${error}`);
    }
  }

  /**
   * Check if the instance has been destroyed
   * @returns true if destroyed, false otherwise
   */
  getIsDestroyed(): boolean {
    return this.isDestroyed;
  }

  /**
   * Add destroy state check for all public methods
   */
  private checkDestroyed(): boolean {
    if (this.isDestroyed) {
      LogUtils.w('KaraokeView: Operation called on destroyed instance');
      return true;
    }
    return false;
  }
}
