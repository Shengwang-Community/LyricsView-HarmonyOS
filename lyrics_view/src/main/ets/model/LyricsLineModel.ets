/**
 * Model class representing a single line of lyrics.
 * Contains information about individual tones (words/syllables) with their timing and pitch data.
 * Corresponds to LyricsLineModel in Android project
 */

/**
 * Enumeration for language types supported in lyrics
 */
export enum Lang {
  Chinese = 'Chinese',
  English = 'English'
}

/**
 * Class representing a single tone (word/syllable) in a lyrics line
 */
export class Tone {
  /**
   * Start time of the tone in milliseconds
   */
  public begin: number = 0;
  /**
   * End time of the tone in milliseconds
   */
  public end: number = 0;
  /**
   * Text content of the tone
   */
  public word: string = '';
  /**
   * Language of the tone
   */
  public lang: Lang = Lang.Chinese;
  /**
   * Pitch value for the tone
   */
  public pitch: number = 0;
  /**
   * Whether this tone represents a full line of lyrics
   */
  public isFullLine: boolean = false;

  /**
   * Gets the duration of the tone in milliseconds
   *
   * @return Duration in milliseconds
   */
  getDuration(): number {
    return this.end - this.begin;
  }

  equals(obj: Tone | null): boolean {
    if (this === obj) {
      return true;
    }
    if (obj === null || obj.constructor !== this.constructor) {
      return false;
    }
    // Compare all properties for equality
    return this.begin === obj.begin &&
      this.end === obj.end &&
      this.word === obj.word &&
      this.lang === obj.lang &&
      this.pitch === obj.pitch;
  }

  hashCode(): number {
    let hash = 0;
    hash += this.begin;
    hash += this.end;
    hash += this.word.length;
    hash += this.lang === Lang.Chinese ? 1 : 2;
    hash += this.pitch;
    return hash;
  }

  toString(): string {
    return "Tone{" +
      "begin=" + this.begin +
      ", end=" + this.end +
      ", word='" + this.word + '\'' +
      ", lang=" + this.lang +
      ", pitch=" + this.pitch +
      ", isFullLine=" + this.isFullLine +
      '}';
  }
}

/**
 * Class representing a monologue section in lyrics
 * Note: Inheritance is not recommended for this use case
 */
export class Monolog extends Tone {
  // Inheritance is not recommended for this use case
}

/**
 * Model class representing a single line of lyrics.
 * Contains information about individual tones (words/syllables) with their timing and pitch data.
 */
export class LyricsLineModel {
  /**
   * List of tones in this lyrics line
   */
  public tones: Tone[] = [];
  /**
   * Duration of the entire line in milliseconds
   */
  public duration: number = 0;

  /**
   * Default constructor
   * Creates an empty lyrics line with no tones
   */
  constructor();

  /**
   * Constructor with a single tone
   *
   * @param tone The tone to add to this line
   */
  constructor(tone: Tone);

  /**
   * Constructor with a monologue tone
   *
   * @param tone The monologue tone to add to this line
   */
  constructor(tone: Monolog);

  /**
   * Constructor with a list of tones
   *
   * @param tones The list of tones to add to this line
   */
  constructor(tones: Tone[]);

  constructor(param?: Tone | Monolog | Tone[]) {
    this.tones = [];

    if (param === undefined) {
      // Default constructor - empty tones array
    } else if (Array.isArray(param)) {
      // Constructor with list of tones
      this.tones = param;
    } else {
      // Constructor with single tone or monolog
      this.tones.push(param);
    }
  }

  /**
   * Gets the start time of the lyrics line
   *
   * @return Start time in milliseconds, or 0 if no tones exist
   */
  getStartTime(): number {
    if (!this.tones || this.tones.length <= 0) {
      return 0;
    }

    const first = this.tones[0];
    return first.begin;
  }

  /**
   * Gets the end time of the lyrics line
   *
   * @return End time in milliseconds, or 0 if no tones exist
   */
  getEndTime(): number {
    if (!this.tones || this.tones.length === 0) {
      return 0;
    } else {
      return this.tones[this.tones.length - 1].end;
    }
  }

  toString(): string {
    return "LyricsLineModel{" +
      "tones=" + this.tones +
      '}';
  }
}
