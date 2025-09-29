/**
 * MCC (Music Content Center) callback interface
 * Defines event callbacks for music playback and lyrics
 */
export interface IMccCallback {
  /**
   * Music lyrics request callback
   * @param songCode - Internal song code
   * @param lyricUrl - Lyrics file path
   * @param pitchUrl - Pitch file path
   * @param songOffsetBegin - Song start offset time (ms)
   * @param songOffsetEnd - Song end offset time (ms)
   * @param lyricOffset - Lyrics offset time (ms)
   */
  onMusicLyricRequest?(
    songCode: bigint,
    lyricUrl: string,
    pitchUrl: string,
    songOffsetBegin: number,
    songOffsetEnd: number,
    lyricOffset: number
  ): void;

  /**
   * Music preload result callback
   * @param songCode - Internal song code
   * @param percent - Preload progress percentage
   */
  onMusicPreloadResult?(songCode: bigint, percent: number): void;

  /**
   * Music playback position change callback
   * @param position - Current playback position (ms)
   */
  onMusicPositionChange?(position: number): void;

  /**
   * Music pitch scoring callback
   * @param internalSongCode - Internal song code
   * @param voicePitch - Voice pitch
   * @param pitchScore - Pitch score
   * @param progressInMs - Playback progress (ms)
   */
  onMusicPitchScore?(
    internalSongCode: bigint,
    voicePitch: number,
    pitchScore: number,
    progressInMs: number
  ): void;

  /**
   * Music line scoring callback
   * @param internalSongCode - Internal song code
   * @param linePitchScore - Line pitch score
   * @param cumulativeTotalLinePitchScores - Cumulative total line pitch scores
   * @param performedLineIndex - Performed line index
   * @param performedTotalLines - Total performed lines
   */
  onMusicLineScore?(
    internalSongCode: bigint,
    linePitchScore: number,
    cumulativeTotalLinePitchScores: number,
    performedLineIndex: number,
    performedTotalLines: number
  ): void;

  /**
   * Music start playing callback
   */
  onMusicPlaying?(): void;

  /**
   * Music pause callback
   */
  onMusicPause?(): void;

  /**
   * Music stop playing callback
   */
  onMusicStop?(): void;

  /**
   * Music playback error callback
   * @param error - Error code
   */
  onMusicError?(error: number): void;
}
