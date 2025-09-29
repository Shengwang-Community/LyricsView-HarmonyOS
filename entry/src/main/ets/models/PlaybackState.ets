/**
 * Playback state model
 * Uses @ObservedV2 for reactive state management
 */
@ObservedV2
export class PlaybackState {
  /** Current playback time (ms) */
  @Trace currentTime: number = 0;
  /** Playback progress display text */
  @Trace playingProgress: string = '0ms';
  /** Whether currently playing */
  @Trace isPlaying: boolean = false;
  /** Whether in original track mode */
  @Trace isOriginalTrack: boolean = true;
  /** Last pitch value */
  @Trace lastPitch: number = 50;

  /**
   * Reset playback state
   */
  reset(): void {
    this.currentTime = 0;
    this.playingProgress = '0ms';
    this.isPlaying = false;
    this.lastPitch = 50;
  }

  /**
   * Update playback progress
   */
  updateProgress(time: number): void {
    this.currentTime = time;
    this.playingProgress = `${time}ms`;
  }

  /**
   * Set playing state
   */
  setPlayingState(isPlaying: boolean): void {
    this.isPlaying = isPlaying;
  }

  /**
   * Toggle original/accompaniment track mode
   */
  toggleOriginalTrack(): void {
    this.isOriginalTrack = !this.isOriginalTrack;
  }

  /**
   * Update pitch value
   */
  updatePitch(pitch: number): void {
    this.lastPitch = Math.max(0, Math.min(100, pitch));
  }
}
