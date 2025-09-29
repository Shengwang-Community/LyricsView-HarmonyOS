/**
 * Global event bus for inter-component communication
 * Avoids direct component reference dependencies
 */
export class EventBus {
  private static instance: EventBus | null = null;
  private listeners: Map<string, Array<Function>> = new Map();

  private constructor() {
  }

  static getInstance(): EventBus {
    if (!EventBus.instance) {
      EventBus.instance = new EventBus();
    }
    return EventBus.instance;
  }

  /**
   * Subscribe to an event
   * @param event Event name
   * @param callback Callback function
   */
  on(event: string, callback: Function): void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event)?.push(callback);
  }

  /**
   * Unsubscribe from an event
   * @param event Event name
   * @param callback Callback function
   */
  off(event: string, callback: Function): void {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  /**
   * Emit an event
   * @param event Event name
   * @param data Event data
   */
  emit(event: string, ...data: Object[]): void {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      callbacks.forEach(callback => {
        try {
          (callback as (...args: Object[]) => void)(...data);
        } catch (error) {
          console.error(`EventBus error in ${event}:`, error);
        }
      });
    }
  }

  /**
   * Clear all listeners
   */
  clear(): void {
    this.listeners.clear();
  }
}

/**
 * Lyrics-related event constants
 */
export class LyricsEvents {
  /** Set lyrics data */
  static readonly SET_LYRIC_DATA = 'lyrics:setData';
  /** Set playback progress */
  static readonly SET_PROGRESS = 'lyrics:setProgress';
  /** Reset lyrics state */
  static readonly RESET = 'lyrics:reset';
  /** Request UI refresh */
  static readonly REQUEST_REFRESH = 'lyrics:requestRefresh';
  /** Lyrics drag start */
  static readonly DRAG_START = 'lyrics:dragStart';
  /** Lyrics drag end */
  static readonly DRAG_END = 'lyrics:dragEnd';
  /** Lyrics drag event (backward compatibility) */
  static readonly SEEK_PROGRESS = 'lyrics:seekProgress';
  /** Destroy lyrics component */
  static readonly DESTROY = 'lyrics:destroy';
}

/**
 * Scoring-related event constants
 */
export class ScoringEvents {
  /** Set lyrics data */
  static readonly SET_LYRIC_DATA = 'scoring:setData';
  /** Set pitch data */
  static readonly SET_PITCH = 'scoring:setPitch';
  /** Set playback progress */
  static readonly SET_PROGRESS = 'scoring:setProgress';
  /** Reset scoring state */
  static readonly RESET = 'scoring:reset';
  /** Request UI refresh */
  static readonly REQUEST_REFRESH = 'scoring:requestRefresh';
  /** Set scoring algorithm */
  static readonly SET_SCORING_ALGORITHM = 'scoring:setScoringAlgorithm';
  /** Set scoring level */
  static readonly SET_SCORING_LEVEL = 'scoring:setScoringLevel';
  /** Destroy scoring component */
  static readonly DESTROY = 'scoring:destroy';
}

/**
 * Karaoke system event constants
 */
export class KaraokeEvents {
  /** Destroy karaoke component */
  static readonly DESTROY = 'karaoke:destroy';
}
