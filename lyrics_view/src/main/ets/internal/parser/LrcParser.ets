import { LyricType } from '../../constants/LyricType';
import { LyricModel } from '../../model/LyricModel';
import { Lang, LyricsLineModel, Tone } from '../../model/LyricsLineModel';
import { LogUtils } from '../../utils/LogUtils';
import { Utils } from '../../utils/Utils';

/**
 * LRC format lyrics parser - HarmonyOS version
 * Corresponds to the doParseLrc method in the Java project
 * Specifically handles LRC format lyrics parsing
 */
export class LrcParser {
  /**
   * Regular expression: matches time tags
   */
  private static readonly LRC_PATTERN_TIME = /\[(\d{2}):(\d{2})\.(\d{2,3})]/g;
  /**
   * Regular expression: matches lyric content lines
   */
  private static readonly LRC_PATTERN_LINE = /^((\[\d{2}:\d{2}\.\d{2,3}])+)(.+)$/;
  /**
   * Regular expression: matches lyric content with time tags
   */
  private static readonly LRC_LYRIC_CONTENT_PATTERN = /<(\d{2}):(\d{2})\.(\d{3})>(.*?)(?=<|$)/g;

  /**
   * Parse LRC format lyrics and pitch data (public interface)
   * @param lyricData LRC lyrics data byte array
   * @param pitchData Pitch data byte array (optional)
   * @param includeCopyrightSentence Whether to include copyright information
   * @param lyricOffset Lyrics time offset (milliseconds)
   * @returns Parsed lyrics model
   */
  static parseLrcLyricData(
    lyricData: Uint8Array,
    pitchData?: Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    try {
      // Use core parsing method
      const model = LrcParser.doParseLrc(lyricData);
      if (!model) {
        LogUtils.e('Failed to parse LRC data');
        return null;
      }

      model.hasPitch = false;

      // Replace tones and set tone values
      // Each tone lasts 100ms
      for (let i = 0; i < model.lines.length; i++) {
        const line = model.lines[i];
        const tones = line.tones;

        if (tones && tones.length > 0) {
          // Calculate the number of tones to add and execute
          for (let j = 0; j < tones.length; j++) {
            const tone = tones[j];
            if (j < tones.length - 1) {
              tone.end = tones[j + 1].begin;
            } else {
              if (i < model.lines.length - 1) {
                tone.end = model.lines[i + 1].tones[0].begin;
              } else {
                // Last tone
                tone.end = tone.begin + 99; // 100ms - 1
              }
            }
          }
        }
      }

      return model;
    } catch (error) {
      LogUtils.e(`parseLrcLyricData error: ${error}`);
      return null;
    }
  }

  /**
   * Core LRC parsing method (corresponds to Java's doParseLrc)
   * @param fileData LRC file data byte array
   * @returns Parsed lyrics model
   */
  static doParseLrc(fileData: Uint8Array): LyricModel | null {
    if (!fileData || fileData.length === 0) {
      return null;
    }

    const lines: LyricsLineModel[] = [];
    try {
      const fileContent = Utils.uint8ArrayToString(fileData);
      const lineArray = fileContent.split(/\n|\r\n/);

      let isFirstLine = true;
      for (let line of lineArray) {
        if (isFirstLine) {
          line = Utils.removeStringBom(line);
          isFirstLine = false;
        }

        const list = LrcParser.parseLrcLine(line);
        if (list && list.length > 0) {
          lines.push(...list);
        }
      }
    } catch (error) {
      LogUtils.e(`doParseLrc error: ${error}`);
    }

    return LrcParser.parseLrcLines(lines);
  }

  /**
   * Process parsed LRC line list and assemble into complete lyrics model (corresponds to Java's parseLrcLines)
   * @param lines Parsed lyrics line list
   * @returns Complete lyrics model
   */
  private static parseLrcLines(lines: LyricsLineModel[]): LyricModel | null {
    const lyrics = new LyricModel(LyricType.LRC);
    if (!lines || lines.length === 0) {
      return lyrics;
    }

    lyrics.lines = lines;

    // Set end time for each line
    for (let i = 0; i < lines.length - 1; i++) {
      const cur = lines[i];
      const next = lines[i + 1];

      if (!cur.tones || cur.tones.length <= 0) {
        continue;
      }

      const first = cur.tones[0];
      first.end = next.getStartTime();
    }

    if (lines.length > 0) {
      const lastLine = lines[lines.length - 1];
      const faked = lastLine.getStartTime() + 8765;
      if (lastLine.tones && lastLine.tones.length > 0) {
        lastLine.tones[0].end = faked;
      }
      // We don't know the final end timestamp of the song
      lyrics.duration = faked;
    }

    // Always the first line of lyrics
    if (lines.length > 0) {
      lyrics.preludeEndPosition = lines[0].getStartTime();
    }

    if (lyrics.duration <= 0 || lyrics.preludeEndPosition < 0) {
      LogUtils.e(`no sentence or unexpected timestamp of sentence: ${lyrics.preludeEndPosition} ${lyrics.duration}`);
      // Invalid lyrics
      return null;
    }

    return lyrics;
  }

  /**
   * Parse LRC format lyrics (public interface, maintains compatibility)
   * @param lrcContent LRC lyrics content string
   * @returns Parsed lyrics model
   */
  static parseLRC(lrcContent: string): LyricModel {
    const lrcData = Utils.stringToUint8Array(lrcContent);
    const result = LrcParser.doParseLrc(lrcData);
    return result || new LyricModel(LyricType.LRC);
  }

  /**
   * Parse single LRC lyrics line (corresponds to Java's parseLrcLine)
   * @param line Line to parse
   * @returns Array of parsed lyrics lines, returns null if parsing fails
   */
  private static parseLrcLine(line: string): LyricsLineModel[] | null {
    if (!line || line.trim().length === 0) {
      return null;
    }

    const lines: LyricsLineModel[] = [];

    try {
      const trimmedLine = line.trim();
      // [00:17.65]让我掉下眼泪的
      const lineMatcher = LrcParser.LRC_PATTERN_LINE.exec(trimmedLine);
      if (!lineMatcher) {
        return null;
      }

      const times = lineMatcher[1];
      if (!times) {
        return null;
      }

      const text = lineMatcher[3];

      if (!text || text.trim().length === 0) {
        return lines; // Return empty array
      }

      // Reset regex lastIndex to avoid test() method affecting matchAll()
      LrcParser.LRC_LYRIC_CONTENT_PATTERN.lastIndex = 0;
      if (LrcParser.LRC_LYRIC_CONTENT_PATTERN.test(text)) {
        const lineModel = new LyricsLineModel();
        // Reset regex lastIndex to ensure matchAll() starts from the beginning
        LrcParser.LRC_LYRIC_CONTENT_PATTERN.lastIndex = 0;
        const matches = text.matchAll(LrcParser.LRC_LYRIC_CONTENT_PATTERN);

        for (const match of matches) {
          const content = Utils.removeQuotes(match[4] || '');

          const min = parseInt(match[1] || '0');
          const sec = parseInt(match[2] || '0');
          const mil = parseInt(match[3] || '0');

          const beginTime = min * 60 * 1000 + sec * 1000 + mil;

          const tone = new Tone();
          tone.begin = beginTime;
          tone.word = content;
          tone.lang = Lang.Chinese;
          lineModel.tones.push(tone);
        }
        lines.push(lineModel);
        return lines;
      } else {
        // [00:17.65]
        LrcParser.LRC_PATTERN_TIME.lastIndex = 0; // Reset regex
        const timeMatches = times.matchAll(LrcParser.LRC_PATTERN_TIME);

        for (const timeMatch of timeMatches) {
          const min = parseInt(timeMatch[1] || '0');
          const sec = parseInt(timeMatch[2] || '0');
          const milInString = timeMatch[3];
          let mil = 0;
          if (milInString) {
            mil = parseInt(milInString);
          }
          // If milliseconds is two digits, multiply by 10
          if (milInString && milInString.length === 2) {
            mil = mil * 10;
          }
          const beginTime = min * 60 * 1000 + sec * 1000 + mil;

          const tone = new Tone();
          tone.begin = beginTime;
          tone.word = text;
          tone.lang = Lang.Chinese;
          tone.isFullLine = true;
          lines.push(new LyricsLineModel([tone]));
        }
      }
    } catch (error) {
      LogUtils.e(`parseLrcLine error: ${error}`);
    }

    return lines;
  }
}
