import { Constants } from '../../constants/Constants';
import { LyricType } from '../../constants/LyricType';
import { KrcParser } from '../../internal/parser/KrcParser';
import { LrcParser } from '../../internal/parser/LrcParser';
import { XmlParser } from '../../internal/parser/XmlParser';
import { LyricModel } from '../../model/LyricModel';
import { LogUtils } from '../../utils/LogUtils';
import { Utils } from '../../utils/Utils';

/**
 * Lyrics parser dispatcher
 * Responsible for detecting lyrics format and dispatching to corresponding specialized parsers
 */
export class LyricsParser {
  /**
   * Regular expression: matches LRC format lines
   */
  private static readonly LRC_PATTERN_LINE = /^((\[\d{2}:\d{2}\.\d{2,3}])+)(.+)$/;
  /**
   * Regular expression: matches KRC format lines
   */
  private static readonly KRC_PATTERN_LINE = /^\[(\w+):([^\]]*)]$/;

  /**
   * Detect lyrics file type based on content
   * @param lyricData Lyrics data byte array
   * @returns Detected lyrics type
   */
  private static probeLyricsFileTypeFromBytes(lyricData: Uint8Array): LyricType {
    let type = LyricType.LRC; // Default type

    try {
      const fileContent = Utils.uint8ArrayToString(lyricData);
      const lines = fileContent.split(/\n|\r\n/);

      if (lines.length > 0) {
        let firstLine = lines[0].trim();
        if (firstLine) {
          // Remove BOM marker
          firstLine = Utils.removeStringBom(firstLine);
          LogUtils.i(`firstLine : ${firstLine}`)

          if (firstLine.includes(`${Constants.FILE_EXTENSION_XML}`) || firstLine.includes('<song>')) {
            type = LyricType.XML;
          } else if (LyricsParser.LRC_PATTERN_LINE.test(firstLine)) {
            type = LyricType.LRC;
          } else if (LyricsParser.KRC_PATTERN_LINE.test(firstLine)) {
            type = LyricType.KRC;
          } else {
            LogUtils.i('probeLyricsFileType unknown lyric type, defaulting to LRC');
          }
        }
      }
    } catch (error) {
      LogUtils.e(`probeLyricsFileType error: ${error}`);
    }

    return type;
  }

  /**
   * Determine lyrics file type based on file extension or content
   *
   * @param lyricPath The lyrics file path to analyze
   * @return Detected lyrics type
   */
  private static probeLyricsFileTypeFromPath(lyricPath: string): LyricType {
    let type = LyricType.LRC;

    if (!lyricPath || lyricPath.trim().length === 0) {
      return type;
    }

    const fileName = lyricPath.substring(lyricPath.lastIndexOf('/') + 1);
    LogUtils.i(`probeLyricsFileType fileName: ${fileName}`);

    if (fileName.endsWith(`.${Constants.FILE_EXTENSION_XML}`)) {
      type = LyricType.XML;
    } else if (fileName.endsWith(`.${Constants.FILE_EXTENSION_LRC}`)) {
      type = LyricType.LRC;
    } else if (fileName.endsWith(`.${Constants.FILE_EXTENSION_KRC}`)) {
      type = LyricType.KRC;
    } else {
      // If unable to determine from extension, try reading file content for detection
      try {
        const fileBytes = Utils.getFileBytes(lyricPath);
        if (fileBytes) {
          type = LyricsParser.probeLyricsFileTypeFromBytes(fileBytes);
        }
      } catch (error) {
        LogUtils.e(`Failed to read file for type detection: ${error}`);
      }
    }

    return type;
  }

  /**
   * Parse lyrics data (main entry method)
   * @param lyricData Lyrics data byte array
   * @param pitchData Pitch data byte array (optional)
   * @param includeCopyrightSentence Whether to include copyright information
   * @param lyricOffset Lyrics time offset (milliseconds)
   * @returns Parsed lyrics model
   */
  static parseLyricData(
    lyricData: Uint8Array,
    pitchData?: Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    const type = LyricsParser.probeLyricsFileTypeFromBytes(lyricData);
    LogUtils.d(`Detected lyric type: ${type}`);

    switch (type) {
      case LyricType.KRC:
        return KrcParser.parseKrcLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
      case LyricType.LRC:
        return LrcParser.parseLrcLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
      case LyricType.XML:
        return XmlParser.parseXmlLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
      default:
        LogUtils.e(`Unsupported lyrics file type: ${type}`);
        return null;
    }
  }

  /**
   * Parse lyrics data from file path
   * @param lyricFilePath Lyrics file path
   * @param pitchFilePath Pitch file path (optional)
   * @param includeCopyrightSentence Whether to include copyright information
   * @param lyricOffset Lyrics time offset (milliseconds)
   * @returns Parsed lyrics model
   */
  static parseFile(
    lyricFilePath: string,
    pitchFilePath?: string,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    try {
      // Detect lyrics type based on file path
      const type = LyricsParser.probeLyricsFileTypeFromPath(lyricFilePath);
      LogUtils.d(`Detected lyric type from path: ${type}`);

      // Read lyrics file data
      const lyricData = Utils.getFileBytes(lyricFilePath);
      if (!lyricData) {
        LogUtils.e(`Failed to read lyric file: ${lyricFilePath}`);
        return null;
      }

      // Read pitch file data (if provided)
      let pitchData: Uint8Array | undefined = undefined;
      if (pitchFilePath) {
        pitchData = Utils.getFileBytes(pitchFilePath) || undefined;
        if (!pitchData) {
          LogUtils.w(`Failed to read pitch file: ${pitchFilePath}`);
        }
      }

      switch (type) {
        case LyricType.KRC:
          return KrcParser.parseKrcLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
        case LyricType.LRC:
          return LrcParser.parseLrcLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
        case LyricType.XML:
          return XmlParser.parseXmlLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
        default:
          LogUtils.e(`Unsupported lyrics file type: ${type}`);
          return null;
      }
    } catch (error) {
      LogUtils.e(`parseFile error: ${error}`);
      return null;
    }
  }
}
