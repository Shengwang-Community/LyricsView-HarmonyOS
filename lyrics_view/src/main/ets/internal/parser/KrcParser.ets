import { LyricType } from '../../constants/LyricType';
import { LyricModel } from '../../model/LyricModel';
import { Lang, LyricsLineModel, Tone } from '../../model/LyricsLineModel';
import { PitchData } from '../../model/PitchData';
import { LogUtils } from '../../utils/LogUtils';
import { Utils } from '../../utils/Utils';

/**
 * KRC pitch data JSON structure interface
 */
interface KrcPitchDataJson {
  pitchDatas?: string | PitchData[];
}

/**
 * KRC format lyrics parser - HarmonyOS version
 * Corresponds to the doParseKrc method in the Java project
 * Supports word-by-word highlighting KRC format parsing
 */
export class KrcParser {
  /**
   * Parse KRC format lyrics and pitch data (public interface)
   * @param krcData KRC lyrics data byte array
   * @param pitchData Pitch data byte array (optional)
   * @param includeCopyrightSentence Whether to include copyright information
   * @param lyricOffset Lyrics time offset (milliseconds)
   * @returns Parsed lyrics model
   */
  static parseKrcLyricData(
    krcData: Uint8Array,
    pitchData?: Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    try {
      // Parse KRC lyrics data
      const lyricsModel = KrcParser.doParseKrc(krcData, lyricOffset);
      if (!lyricsModel) {
        LogUtils.e('Failed to parse KRC data');
        return null;
      }

      // Parse pitch data
      let pitchDataList: PitchData[] | null = null;
      if (pitchData) {
        pitchDataList = KrcParser.doParseKrcPitchData(pitchData);
      }

      // Set pitch-related properties
      lyricsModel.pitchDataList = pitchDataList || null;
      lyricsModel.hasPitch = pitchDataList != null && pitchDataList.length > 0;

      if (lyricsModel.hasPitch && pitchDataList && pitchDataList.length > 0) {
        lyricsModel.preludeEndPosition = pitchDataList[0].startTime;
      }

      // Remove copyright information sentences
      if (!includeCopyrightSentence && lyricsModel.lines && lyricsModel.lines.length > 0) {
        let copyrightCount = 0;
        const filteredLines = lyricsModel.lines.filter(line => {
          if (line.getEndTime() < lyricsModel.preludeEndPosition) {
            copyrightCount++;
            return false;
          }
          return true;
        });
        lyricsModel.lines = filteredLines;
        lyricsModel.copyrightSentenceLineCount = copyrightCount;
      }

      return lyricsModel;
    } catch (error) {
      LogUtils.e(`parseKrcLyricData error: ${error}`);
      return null;
    }
  }

  /**
   * Parse KRC format lyrics (public interface)
   * @param krcContent KRC lyrics content string
   * @param lyricOffset Lyrics time offset (milliseconds)
   * @returns Parsed lyrics model
   */
  static parseKRC(krcContent: string, lyricOffset: number = 0): LyricModel {
    const krcData = Utils.stringToUint8Array(krcContent);
    const result = KrcParser.doParseKrc(krcData, lyricOffset);
    return result || new LyricModel(LyricType.KRC);
  }

  /**
   * Core KRC parsing method (corresponds to Java's doParseKrc)
   * @param krcFileData KRC file data byte array
   * @param lyricOffset Lyrics time offset (milliseconds)
   * @returns Parsed lyrics model
   */
  private static doParseKrc(krcFileData: Uint8Array, lyricOffset: number): LyricModel | null {
    try {
      const content = Utils.uint8ArrayToString(krcFileData);

      const lines = content.split(/\n|\r\n/);
      const metadata = new Map<string, string>();
      const lineModels: LyricsLineModel[] = [];

      let isFirstLine = true;
      for (let line of lines) {
        try {
          if (isFirstLine) {
            line = Utils.removeStringBom(line);
            isFirstLine = false;
          }

          if (line.startsWith('[')) {
            if (line.includes('<') && line.includes('>')) {
              // Parse lyrics line
              let offsetValue = 0;
              if (metadata.has('offset')) {
                try {
                  offsetValue = parseInt(metadata.get('offset') || '0');
                } catch (error) {
                  LogUtils.e('parse offset error');
                }
              }

              const lineModel = KrcParser.parseKrcLine(line, lyricOffset);
              if (lineModel) {
                lineModels.push(lineModel);
              } else {
                LogUtils.e('parseLine error');
              }
            } else {
              // Handle metadata part: `[ti:星晴]`
              const index = line.indexOf(':');
              if (index !== -1) {
                // Key, from second character to before ":"
                const key = line.substring(1, index);
                // Value, from after ":" to before "]"
                const value = line.substring(index + 1, line.length - 1);
                metadata.set(key, value);
              } else {
                LogUtils.i(`unknown metadata line: ${line}`);
              }
            }
          } else {
            LogUtils.i(`ignore line: ${line}`);
          }
        } catch (error) {
          LogUtils.e(`doParseKrc error: ${error} line: ${line}`);
        }
      }

      const lyrics = new LyricModel(LyricType.KRC);
      lyrics.name = metadata.has('ti') ? metadata.get('ti') || 'unknownTitle' : 'unknownTitle';
      lyrics.singer = metadata.has('ar') ? metadata.get('ar') || 'unknownSinger' : 'unknownSinger';
      lyrics.lines = lineModels;
      lyrics.preludeEndPosition = 0;

      if (lineModels.length === 0) {
        lyrics.duration = 0;
      } else {
        const lastLine = lineModels[lineModels.length - 1];
        lyrics.duration = lastLine.getStartTime() + lastLine.duration;
      }

      return lyrics;
    } catch (error) {
      LogUtils.e(`doParseKrc error: ${error}`);
      return null;
    }
  }

  /**
   * Parse single KRC format line (corresponds to Java's parseKrcLine)
   * @param line Line to parse
   * @param offset Time offset (milliseconds)
   * @returns Parsed lyrics line model, returns null if parsing fails
   */
  private static parseKrcLine(line: string, offset: number): LyricsLineModel | null {
    try {
      const rangeStart = line.indexOf('[');
      const rangeEnd = line.indexOf(']');
      if (rangeStart === -1 || rangeEnd === -1) {
        return null;
      }

      const timeStr = line.substring(rangeStart + 1, rangeEnd);
      const timeComponents = timeStr.split(',');

      // Handle line time: `0,1600`
      if (timeComponents.length !== 2) {
        return null;
      }

      const startTimeOrigin = parseInt(timeComponents[0].trim());
      const lineStartTime = startTimeOrigin >= offset ? startTimeOrigin - offset : startTimeOrigin;

      const lineDuration = parseInt(timeComponents[1].trim());
      const lineContent = line.substring(rangeEnd + 1).trim();

      // Parse line content
      const tones: Tone[] = [];
      const toneComponents = lineContent.split('<');

      for (const toneComponent of toneComponents) {
        if (toneComponent.length === 0) {
          continue;
        }

        // Parse word content: '0,177,0>星'
        const toneParts = toneComponent.split('>');
        if (toneParts.length === 2) {
          const word = toneParts[1];

          const timeParts = toneParts[0].split(',');
          if (timeParts.length === 3) {
            const startTime = lineStartTime + parseInt(timeParts[0]);
            const duration = parseInt(timeParts[1]);
            const pitch = parseFloat(timeParts[2]);

            const tone = new Tone();
            tone.begin = startTime;
            tone.end = startTime + duration;
            tone.word = word;
            tone.pitch = Math.floor(pitch);
            tone.lang = Lang.Chinese;
            tones.push(tone);
          }
        }
      }

      const lineModel = new LyricsLineModel(tones);
      lineModel.duration = lineDuration;
      return lineModel;
    } catch (error) {
      LogUtils.e(`parseKrcLine error: ${error}`);
    }
    return null;
  }

  /**
   * Parse KRC format pitch data
   * @param fileData Byte array containing KRC pitch data
   * @returns Array of PitchData objects, returns null if parsing fails
   */
  private static doParseKrcPitchData(fileData: Uint8Array): PitchData[] | null {
    if (!fileData || fileData.length === 0) {
      return null;
    }

    try {
      let jsonData = Utils.uint8ArrayToString(fileData);

      const jsonObject: KrcPitchDataJson = JSON.parse(jsonData) as KrcPitchDataJson;
      if (jsonObject.pitchDatas) {
        const pitchDatas = jsonObject.pitchDatas;
        if (typeof pitchDatas === 'string') {
          return JSON.parse(pitchDatas) as PitchData[];
        } else if (Array.isArray(pitchDatas)) {
          return pitchDatas as PitchData[];
        }
      }
    } catch (error) {
      LogUtils.e(`doParseKrcPitchData error: ${error}`);
    }

    return null;
  }
}
