/**
 * Model class representing a line of lyrics with pitch data.
 * Contains information about pitch segments with their timing and highlighting information.
 */
export class PitchLineModel {
  /**
   * List of pitch segments in this lyrics line
   */
  pitches: Pitch[] = [];

  /**
   * Default constructor
   * Creates an empty pitch line with no pitch segments
   */
  constructor();

  /**
   * Constructor with a single pitch segment
   *
   * @param pitch The pitch segment to add to this line
   */
  constructor(pitch: Pitch);

  /**
   * Constructor with a list of pitch segments
   *
   * @param pitches The list of pitch segments to add to this line
   */
  constructor(pitches: Pitch[]);

  constructor(pitchOrPitches?: Pitch | Pitch[]) {
    this.pitches = [];

    if (pitchOrPitches) {
      if (Array.isArray(pitchOrPitches)) {
        this.pitches = pitchOrPitches;
      } else {
        this.pitches.push(pitchOrPitches);
      }
    }
  }

  /**
   * Gets the start time of this lyrics line
   *
   * @return Start time in milliseconds, or 0 if no pitches
   */
  getStartTime(): number {
    if (!this.pitches || this.pitches.length <= 0) {
      return 0;
    }

    const first = this.pitches[0];
    return first.begin;
  }

  /**
   * Gets the end time of this lyrics line
   *
   * @return End time in milliseconds, or 0 if no pitches
   */
  getEndTime(): number {
    if (!this.pitches || this.pitches.length === 0) {
      return 0;
    } else {
      return this.pitches[this.pitches.length - 1].end;
    }
  }

  /**
   * String representation of this pitch line model
   *
   * @return String representation
   */
  toString(): string {
    return `PitchLineModel{pitches=${JSON.stringify(this.pitches)}}`;
  }
}

/**
 * Time pair interface for highlight mapping
 */
export interface TimePair {
  first: number;
  second: number;
}

/**
 * Class representing a single pitch segment in a lyrics line
 */
export class Pitch {
  /**
   * Start time of the pitch segment in milliseconds
   */
  begin: number = 0;
  /**
   * End time of the pitch segment in milliseconds
   */
  end: number = 0;
  /**
   * Pitch value for this segment
   */
  pitch: number = 0;
  /**
   * Map of highlighted parts within this pitch segment
   * Key: Timestamp, Value: TimePair of (start time, end time) for the highlight
   */
  highlightPartMap: Map<number, TimePair | null> = new Map();

  /**
   * Clears all highlight information from this pitch segment
   */
  resetHighlight(): void {
    this.highlightPartMap.clear();
  }

  /**
   * Gets the duration of the pitch segment in milliseconds
   *
   * @return Duration in milliseconds
   */
  getDuration(): number {
    return this.end - this.begin;
  }

  /**
   * Checks equality with another Pitch object
   *
   * @param obj The object to compare with
   * @return true if equal, false otherwise
   */
  equals(obj: Pitch | null): boolean {
    if (this === obj) {
      return true;
    }
    if (!obj) {
      return false;
    }

    // Compare all properties for equality
    return this.begin === obj.begin &&
      this.end === obj.end &&
      this.pitch === obj.pitch;
  }

  /**
   * Generates hash code for this pitch object
   *
   * @return Hash code
   */
  hashCode(): number {
    let hash = 0;
    hash = hash * 31 + this.begin;
    hash = hash * 31 + this.end;
    hash = hash * 31 + this.pitch;
    return hash;
  }

  /**
   * String representation of this pitch
   *
   * @return String representation
   */
  toString(): string {
    return `Pitch{begin=${this.begin}, end=${this.end}, pitch=${this.pitch}, highlightPartMap=${JSON.stringify(Array.from(this.highlightPartMap.entries()))}}`;
  }
}

/**
 * Pitch stick data interface
 */
export interface PitchStickData {
  /** X coordinate */
  x: number;

  /** Y coordinate */
  y: number;

  /** Width */
  width: number;

  /** Height */
  height: number;

  /** Pitch value */
  pitch: number;

  /** Whether this pitch stick is highlighted */
  isHighlighted: boolean;

  /** Whether this is the currently singing pitch */
  isCurrentPitch: boolean;

  /** List of highlighted segments */
  highlightSegments: HighlightSegment[];
}

/**
 * Highlight segment data structure - corresponds to each entry in Android's highlightPartMap
 */
export interface HighlightSegment {
  /** Start X coordinate of the highlight segment */
  startX: number;

  /** End X coordinate of the highlight segment */
  endX: number;

  /** Start time of the highlight segment */
  startTime: number;

  /** End time of the highlight segment */
  endTime: number;
}
