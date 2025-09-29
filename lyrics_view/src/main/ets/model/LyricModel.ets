import { LyricType } from '../constants/LyricType';
import { LyricsLineModel } from './LyricsLineModel';
import { PitchData } from './PitchData';

/**
 * Lyrics data model
 * Model class representing lyrics data for a song.
 * Contains song information, lyrics lines, and pitch data for karaoke functionality.
 */
export class LyricModel {
  /**
   * Type of lyrics (e.g., LRC, XML, KRC)
   */
  public type: LyricType;
  /**
   * Name of the song
   */
  public name: string = '';
  /**
   * Name of the singer/artist
   */
  public singer: string = '';
  /**
   * List of lyrics lines containing timing and text information
   */
  public lines: LyricsLineModel[] = [];
  /**
   * End time of the song's prelude in milliseconds
   */
  public preludeEndPosition: number = 0;
  /**
   * Total duration of the lyrics in milliseconds
   */
  public duration: number = 0;
  /**
   * Whether the lyrics contain pitch information
   */
  public hasPitch: boolean = false;
  /**
   * Number of lines containing copyright information
   */
  public copyrightSentenceLineCount: number = 0;
  /**
   * List of pitch data points for karaoke scoring
   */
  public pitchDataList: PitchData[] | null = null;

  /**
   * Constructor for LyricModel
   *
   * @param type Type of lyrics to be used
   */
  constructor(type: LyricType) {
    this.type = type;
    this.copyrightSentenceLineCount = 0;
  }

  /**
   * Create a deep copy of the LyricModel
   *
   * @return New instance of LyricModel with copied data
   */
  copy(): LyricModel {
    const lyricModel = new LyricModel(this.type);
    lyricModel.name = this.name;
    lyricModel.singer = this.singer;
    if (this.lines) {
      lyricModel.lines = [...this.lines];
    }
    lyricModel.preludeEndPosition = this.preludeEndPosition;
    lyricModel.duration = this.duration;
    lyricModel.hasPitch = this.hasPitch;
    if (this.pitchDataList) {
      lyricModel.pitchDataList = [...this.pitchDataList];
    }
    return lyricModel;
  }

  /**
   * Convert the LyricModel to a string representation
   *
   * @return String containing all model properties
   */
  toString(): string {
    return "LyricModel{" +
      "name='" + this.name + '\'' +
      ", singer='" + this.singer + '\'' +
      ", type=" + this.type +
      ", lines=" + this.lines +
      ", preludeEndPosition=" + this.preludeEndPosition +
      ", duration=" + this.duration +
      ", hasPitch=" + this.hasPitch +
      ", pitchDataList=" + this.pitchDataList +
      '}';
  }
}
