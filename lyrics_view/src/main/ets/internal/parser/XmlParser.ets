import { LyricType } from '../../constants/LyricType';
import { LyricModel } from '../../model/LyricModel';
import { Lang, LyricsLineModel, Monolog, Tone } from '../../model/LyricsLineModel';
import { PitchData } from '../../model/PitchData';
import { LogUtils } from '../../utils/LogUtils';
import { Utils } from '../../utils/Utils';


/**
 * Song data structure containing basic information and MIDI data
 */
interface Song {
  general?: SongGeneral;
  midi?: SongMidi;
}

/**
 * Song general information
 */
interface SongGeneral {
  name?: string;
  singer?: string;
  type?: number;
  modeType?: string;
}

/**
 * MIDI lyrics data
 */
interface SongMidi {
  paragraphs: Paragraph[];
}

/**
 * Paragraph containing multiple lyrics lines
 */
interface Paragraph {
  lines: LyricsLineModel[];
}

/**
 * XML pitch data model
 */
export interface XmlPitchData {
  version: number;
  interval: number;
  reserved: number;
  pitches: number[];
}

/**
 * XML pitch data JSON structure interface
 */
interface XmlPitchDataJson {
  pitchDatas?: string | PitchData[];
}

/**
 * XML format lyrics parser - HarmonyOS version
 * Corresponds to LyricsParserXml in Java project
 * Specifically handles XML format lyrics parsing
 */
export class XmlParser {
  /**
   * Parse XML format lyrics and pitch data (public interface)
   * @param lyricData XML lyrics data byte array
   * @param pitchData Pitch data byte array (optional)
   * @param includeCopyrightSentence Whether to include copyright information
   * @param lyricOffset Lyrics time offset (milliseconds)
   * @returns Parsed lyrics model
   */
  static parseXmlLyricData(
    lyricData: Uint8Array,
    pitchData?: Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    LogUtils.d(`parseXmlLyricData lyricData: ${lyricData.length}, pitchData: ${pitchData?.length}, includeCopyrightSentence: ${includeCopyrightSentence}, lyricOffset: lyricOffset=${lyricOffset}`);
    try {
      // Parse pitch data
      let pitchesModel: XmlPitchData | null = null;
      if (pitchData) {
        pitchesModel = XmlParser.parseXmlPitchData(pitchData);
      }

      // Use dedicated XML parser
      const model = XmlParser.parseXMLFromBytes(lyricData);
      if (!model) {
        LogUtils.e('Failed to parse XML content');
        return null;
      }

      // XML format usually already contains pitch information, but if additional pitch data is provided, it can be enhanced
      if (pitchesModel && pitchesModel.pitches.length > 0) {
        model.hasPitch = true;

        // Add additional pitch data processing for XML lyrics
        for (let i = 0; i < model.lines.length; i++) {
          const line = model.lines[i];
          if (line.tones && line.tones.length > 0) {
            for (const tone of line.tones) {
              if (tone.pitch === 0) {
                // If there's no pitch information in XML, get it from pitch data
                tone.pitch = Math.floor(XmlParser.fetchPitchWithRange(
                  pitchesModel,
                  model.preludeEndPosition,
                  tone.begin,
                  tone.end
                ));
              }
            }
          }
        }
      }

      return model;
    } catch (error) {
      LogUtils.e(`parseXmlLyricData error: ${error}`);
      return null;
    }
  }

  /**
   * Parse XML format lyrics data
   * @param xmlContent XML content string
   * @returns LyricModel object containing parsed lyrics, or null if parsing fails
   */
  static parseXML(xmlContent: string): LyricModel | null {
    if (!xmlContent || xmlContent.trim().length === 0) {
      LogUtils.e('XML content is empty');
      return null;
    }

    try {
      // Remove BOM marker
      const cleanContent = Utils.removeStringBom(xmlContent.trim());
      LogUtils.d(`parseXML xmlContent: ${cleanContent}`);

      // Use simple XML parsing (HarmonyOS may not have complete XML parser)
      const song = XmlParser.parseXmlContent(cleanContent);

      if (!song.midi || !song.midi.paragraphs) {
        LogUtils.e('No midi or paragraph found in XML');
        return null;
      }

      const lyrics = new LyricModel(LyricType.XML);
      const lines: LyricsLineModel[] = [];

      for (const paragraph of song.midi.paragraphs) {
        lines.push(...paragraph.lines);
      }

      if (lines.length > 0) {
        lyrics.duration = lines[lines.length - 1].getEndTime();
        // Always the first line of lyrics
        lyrics.preludeEndPosition = lines[0].getStartTime();
        lyrics.hasPitch = lines[0].tones.length > 0 && lines[0].tones[0].pitch !== 0;
      }

      lyrics.name = song.general?.name || 'Unknown Title';
      lyrics.singer = song.general?.singer || 'Unknown Singer';
      lyrics.lines = lines;

      if (lyrics.duration <= 0 || lyrics.preludeEndPosition < 0) {
        LogUtils.e(`Invalid XML lyrics: duration=${lyrics.duration}, prelude=${lyrics.preludeEndPosition}`);
        return null;
      }

      return lyrics;
    } catch (error) {
      LogUtils.e(`parseXML error: ${error}`);
    }

    return null;
  }

  /**
   * Parse XML format lyrics data from byte array
   * @param xmlFileData Byte array containing XML file data
   * @returns LyricModel object containing parsed lyrics, or null if parsing fails
   */
  static parseXMLFromBytes(xmlFileData: Uint8Array): LyricModel | null {
    if (!xmlFileData || xmlFileData.length === 0) {
      LogUtils.e('XML file data is empty');
      return null;
    }

    try {
      // Use HarmonyOS compatible way to convert Uint8Array to string
      const xmlContent = Utils.uint8ArrayToString(xmlFileData);
      return XmlParser.parseXML(xmlContent);
    } catch (error) {
      LogUtils.e(`parseXMLFromBytes error: ${error}`);
      return null;
    }
  }

  /**
   * Parse XML content (simplified version)
   * @param xmlContent XML content string
   * @returns Song object
   */
  private static parseXmlContent(xmlContent: string): Song {
    const song: Song = {};

    try {
      // Parse general information
      const generalMatch = xmlContent.match(/<general>([\s\S]*?)<\/general>/);
      if (generalMatch) {
        song.general = XmlParser.parseGeneral(generalMatch[1]);
      }

      // Parse midi_lrc information
      const midiMatch = xmlContent.match(/<midi_lrc>([\s\S]*?)<\/midi_lrc>/);
      if (midiMatch) {
        song.midi = XmlParser.parseMidiLrc(midiMatch[1]);
      }

      // If midi_lrc is not found, try to parse paragraphs (compatible with different formats)
      if (!song.midi) {
        const paragraphsMatch = xmlContent.match(/<paragraphs>([\s\S]*?)<\/paragraphs>/);
        if (paragraphsMatch) {
          song.midi = { paragraphs: [] };
          const paragraphMatches = paragraphsMatch[1].matchAll(/<paragraph>([\s\S]*?)<\/paragraph>/g);
          for (const paragraphMatch of paragraphMatches) {
            const paragraph = XmlParser.parseParagraphDirect(paragraphMatch[1]);
            song.midi.paragraphs.push(paragraph);
          }
        }
      }
    } catch (error) {
      LogUtils.e(`parseXmlContent error: ${error}`);
    }

    return song;
  }

  /**
   * Parse song general information
   * @param generalContent Content within general tag
   * @returns SongGeneral object
   */
  private static parseGeneral(generalContent: string): SongGeneral {
    const general: SongGeneral = {};

    try {
      const nameMatch = generalContent.match(/<name>(.*?)<\/name>/);
      if (nameMatch) {
        general.name = nameMatch[1].trim();
      }

      const singerMatch = generalContent.match(/<singer>(.*?)<\/singer>/);
      if (singerMatch) {
        general.singer = singerMatch[1].trim();
      }

      const typeMatch = generalContent.match(/<type>(.*?)<\/type>/);
      if (typeMatch) {
        try {
          general.type = parseInt(typeMatch[1].trim());
        } catch (error) {
          LogUtils.w(`Failed to parse type: ${typeMatch[1]}`);
        }
      }

      const modeTypeMatch = generalContent.match(/<mode_type>(.*?)<\/mode_type>/);
      if (modeTypeMatch) {
        general.modeType = modeTypeMatch[1];
      }
    } catch (error) {
      LogUtils.e(`parseGeneral error: ${error}`);
    }

    return general;
  }

  /**
   * Parse MIDI lyrics data
   * @param midiContent Content within midi_lrc tag
   * @returns SongMidi object
   */
  private static parseMidiLrc(midiContent: string): SongMidi {
    const midi: SongMidi = { paragraphs: [] };

    try {
      // Match all paragraph tags
      const paragraphMatches = midiContent.matchAll(/<paragraph>([\s\S]*?)<\/paragraph>/g);

      for (const paragraphMatch of paragraphMatches) {
        const paragraph = XmlParser.parseParagraph(paragraphMatch[1]);
        midi.paragraphs.push(paragraph);
      }
    } catch (error) {
      LogUtils.e(`parseMidiLrc error: ${error}`);
    }

    return midi;
  }

  /**
   * Parse paragraph data
   * @param paragraphContent Content within paragraph tag
   * @returns Paragraph object
   */
  private static parseParagraph(paragraphContent: string): Paragraph {
    const paragraph: Paragraph = { lines: [] };

    try {
      // Match all sentence tags
      const sentenceMatches = paragraphContent.matchAll(/<sentence[^>]*>([\s\S]*?)<\/sentence>/g);

      for (const sentenceMatch of sentenceMatches) {
        const sentenceTag = sentenceMatch[0];
        const sentenceContent = sentenceMatch[1];

        const lines = XmlParser.parseLines(sentenceTag, sentenceContent);
        for (const line of lines) {
          line.duration = line.getEndTime() - line.getStartTime();
        }
        paragraph.lines.push(...lines);
      }
    } catch (error) {
      LogUtils.e(`parseParagraph error: ${error}`);
    }

    return paragraph;
  }

  /**
   * Parse paragraph data directly (for handling formats containing monolog)
   * @param paragraphContent Content within paragraph tag
   * @returns Paragraph object
   */
  private static parseParagraphDirect(paragraphContent: string): Paragraph {
    const paragraph: Paragraph = { lines: [] };

    try {
      // Match all monolog tags
      const monologMatches = paragraphContent.matchAll(/<monolog[^>]*>([\s\S]*?)<\/monolog>/g);

      for (const monologMatch of monologMatches) {
        const monologContent = monologMatch[1];
        const lines = XmlParser.parseMonologLines(monologContent);
        for (const line of lines) {
          line.duration = line.getEndTime() - line.getStartTime();
        }
        paragraph.lines.push(...lines);
      }

      // If no monolog, try to parse line tags directly
      if (paragraph.lines.length === 0) {
        const lineMatches = paragraphContent.matchAll(/<line[^>]*>([\s\S]*?)<\/line>/g);
        for (const lineMatch of lineMatches) {
          const lineContent = lineMatch[1];
          const line = XmlParser.parseDirectLine(lineContent);
          if (line) {
            line.duration = line.getEndTime() - line.getStartTime();
            paragraph.lines.push(line);
          }
        }
      }
    } catch (error) {
      LogUtils.e(`parseParagraphDirect error: ${error}`);
    }

    return paragraph;
  }

  /**
   * Parse lyrics line data
   * @param sentenceTag Sentence tag (including attributes)
   * @param sentenceContent Content within sentence tag
   * @returns Array of LyricsLineModel objects
   */
  private static parseLines(sentenceTag: string, sentenceContent: string): LyricsLineModel[] {
    const line = new LyricsLineModel();

    try {
      // Parse mode attribute of sentence
      const modeMatch = sentenceTag.match(/mode="([^"]*)"/);
      let isManMode = true;
      if (modeMatch) {
        isManMode = modeMatch[1] === 'man';
      }

      // Match all tone tags
      const toneMatches = sentenceContent.matchAll(/<tone[^>]*>[\s\S]*?<\/tone>/g);

      for (const toneMatch of toneMatches) {
        const toneTag = toneMatch[0];
        const toneContent = XmlParser.extractToneContent(toneTag);
        const tone = XmlParser.parseTone(toneTag, toneContent);
        if (tone) {
          line.tones.push(tone);
        }
      }

      // Match all monolog tags
      const monologMatches = sentenceContent.matchAll(/<monolog[^>]*>[\s\S]*?<\/monolog>/g);

      for (const monologMatch of monologMatches) {
        const monologTag = monologMatch[0];
        const monologContent = XmlParser.extractMonologContent(monologTag);
        const monolog = XmlParser.parseMonolog(monologTag, monologContent);
        if (monolog) {
          line.tones.push(monolog);
        }
      }
    } catch (error) {
      LogUtils.e(`parseLines error: ${error}`);
    }

    return [line];
  }

  /**
   * Parse line data within monolog
   * @param monologContent Content within monolog tag
   * @returns Array of LyricsLineModel objects
   */
  private static parseMonologLines(monologContent: string): LyricsLineModel[] {
    const lines: LyricsLineModel[] = [];

    try {
      // Match all line tags
      const lineMatches = monologContent.matchAll(/<line[^>]*>([\s\S]*?)<\/line>/g);

      for (const lineMatch of lineMatches) {
        const lineContent = lineMatch[1];
        const line = XmlParser.parseDirectLine(lineContent);
        if (line) {
          lines.push(line);
        }
      }
    } catch (error) {
      LogUtils.e(`parseMonologLines error: ${error}`);
    }

    return lines;
  }

  /**
   * Parse line tag content directly
   * @param lineContent Content within line tag
   * @returns LyricsLineModel object
   */
  private static parseDirectLine(lineContent: string): LyricsLineModel | null {
    try {
      const line = new LyricsLineModel();

      // Match all tone tags
      const toneMatches =
        lineContent.matchAll(/<tone[^>]*\s+begin="([^"]*)"[^>]*\s+end="([^"]*)"[^>]*\s+pitch="([^"]*)"[^>]*\s+word="([^"]*)"[^>]*\/>/g);

      for (const toneMatch of toneMatches) {
        const tone = new Tone();
        tone.begin = Math.floor(parseFloat(toneMatch[1]) * 1000);
        tone.end = Math.floor(parseFloat(toneMatch[2]) * 1000);
        tone.pitch = Math.floor(parseFloat(toneMatch[3]));
        tone.word = toneMatch[4];
        tone.lang = Lang.Chinese; // Default to Chinese
        line.tones.push(tone);
      }

      return line.tones.length > 0 ? line : null;
    } catch (error) {
      LogUtils.e(`parseDirectLine error: ${error}`);
      return null;
    }
  }

  /**
   * Extract content from tone tag
   * @param toneTag Complete tone tag
   * @returns Content within tone tag
   */
  private static extractToneContent(toneTag: string): string {
    const match = toneTag.match(/<tone[^>]*>([\s\S]*?)<\/tone>/);
    return match ? match[1] : '';
  }

  /**
   * Extract content from monolog tag
   * @param monologTag Complete monolog tag
   * @returns Content within monolog tag
   */
  private static extractMonologContent(monologTag: string): string {
    const match = monologTag.match(/<monolog[^>]*>([\s\S]*?)<\/monolog>/);
    return match ? match[1] : '';
  }

  /**
   * Parse tone data
   * @param toneTag Complete tone tag
   * @param toneContent Content within tone tag
   * @returns Tone object
   */
  private static parseTone(toneTag: string, toneContent: string): Tone | null {
    try {
      const tone = new Tone();

      // Parse attributes
      const beginMatch = toneTag.match(/begin="([^"]*)"/);
      if (beginMatch) {
        const beginValue = parseFloat(beginMatch[1]);
        // If value is less than 1000, assume it's in seconds and convert to milliseconds
        tone.begin = beginValue < 1000 ? Math.floor(beginValue * 1000) : Math.floor(beginValue);
      }

      const endMatch = toneTag.match(/end="([^"]*)"/);
      if (endMatch) {
        const endValue = parseFloat(endMatch[1]);
        // If value is less than 1000, assume it's in seconds and convert to milliseconds
        tone.end = endValue < 1000 ? Math.floor(endValue * 1000) : Math.floor(endValue);
      }

      const pitchMatch = toneTag.match(/pitch="([^"]*)"/);
      if (pitchMatch) {
        try {
          const pitchValue = parseFloat(pitchMatch[1]);
          tone.pitch = Math.floor(pitchValue);
        } catch (error) {
          LogUtils.w(`Failed to parse pitch: ${pitchMatch[1]}`);
          tone.pitch = 0;
        }
      }

      const langMatch = toneTag.match(/lang="([^"]*)"/);
      if (!langMatch || langMatch[1] === '1') {
        tone.lang = Lang.Chinese;
      } else {
        tone.lang = Lang.English;
      }

      // Parse pronounce attribute (pronunciation)
      const pronounceMatch = toneTag.match(/pronounce="([^"]*)"/);

      // Parse word content
      const wordMatch = toneContent.match(/<word>(.*?)<\/word>/);
      if (wordMatch) {
        tone.word = wordMatch[1];

        // If lang field is missing, check language through word content
        if (!langMatch) {
          const isEnglish = XmlParser.checkLang(tone.word);
          if (isEnglish) {
            tone.lang = Lang.English;
          }
        }
      } else {
        // If no word tag, use entire content as word
        tone.word = toneContent.trim();
      }

      return tone;
    } catch (error) {
      LogUtils.e(`parseTone error: ${error}`);
      return null;
    }
  }

  /**
   * Parse monolog data
   * @param monologTag Complete monolog tag
   * @param monologContent Content within monolog tag
   * @returns Monolog object
   */
  private static parseMonolog(monologTag: string, monologContent: string): Monolog | null {
    try {
      const monolog = new Monolog();

      // Parse attributes
      const beginMatch = monologTag.match(/begin="([^"]*)"/);
      if (beginMatch) {
        const beginValue = parseFloat(beginMatch[1]);
        // If value is less than 1000, assume it's in seconds and convert to milliseconds
        monolog.begin = beginValue < 1000 ? Math.floor(beginValue * 1000) : Math.floor(beginValue);
      }

      const endMatch = monologTag.match(/end="([^"]*)"/);
      if (endMatch) {
        const endValue = parseFloat(endMatch[1]);
        // If value is less than 1000, assume it's in seconds and convert to milliseconds
        monolog.end = endValue < 1000 ? Math.floor(endValue * 1000) : Math.floor(endValue);
      }

      const pitchMatch = monologTag.match(/pitch="([^"]*)"/);
      if (pitchMatch) {
        try {
          const pitchValue = parseFloat(pitchMatch[1]);
          monolog.pitch = Math.floor(pitchValue);
        } catch (error) {
          LogUtils.w(`Failed to parse monolog pitch: ${pitchMatch[1]}`);
          monolog.pitch = 0;
        }
      }

      const langMatch = monologTag.match(/lang="([^"]*)"/);
      if (!langMatch || langMatch[1] === '1') {
        monolog.lang = Lang.Chinese;
      } else {
        monolog.lang = Lang.English;
      }

      // Monolog content is directly text
      monolog.word = monologContent.trim();

      return monolog;
    } catch (error) {
      LogUtils.e(`parseMonolog error: ${error}`);
      return null;
    }
  }

  /**
   * Check if word is Chinese
   * @param word Word to check
   * @returns True if word is not Chinese, false otherwise
   */
  private static checkLang(word: string): boolean {
    for (let i = 0; i < word.length; i++) {
      const charCode = word.charCodeAt(i);
      if (!(19968 <= charCode && charCode < 40869)) {
        return true; // Not a Chinese character
      }
    }
    return false; // All Chinese characters
  }

  /**
   * Parse XML format pitch data
   * @param fileData Byte array containing XML pitch data
   * @returns XmlPitchData object containing parsed pitch data
   */
  static parseXmlPitchData(fileData: Uint8Array): XmlPitchData {
    const model: XmlPitchData = {
      version: 0,
      interval: 0,
      reserved: 0,
      pitches: []
    };

    if (!fileData || fileData.length === 0) {
      return model;
    }

    try {
      const buffer = fileData.buffer;
      const dataView = new DataView(buffer);
      let offset = 0;

      // Read int32 values until end of file
      model.version = XmlParser.readLittleEndianInt(dataView, offset);
      offset += 4;
      LogUtils.d(`Version for the pitch file: ${model.version}`);

      model.interval = XmlParser.readLittleEndianInt(dataView, offset);
      offset += 4;
      LogUtils.d(`Interval for the pitch file: ${model.interval}`);

      model.reserved = XmlParser.readLittleEndianInt(dataView, offset);
      offset += 4;
      LogUtils.d(`Reserved for the pitch file: ${model.reserved}`);

      while (offset + 8 <= buffer.byteLength) {
        // Each pitch value occupies at least 8 bits
        const pitch = XmlParser.readLittleEndianDouble(dataView, offset);
        offset += 8;

        // Format to 3 decimal places
        const formattedPitch = Math.round(pitch * 1000) / 1000;
        model.pitches.push(formattedPitch);
      }
    } catch (error) {
      LogUtils.e(`parseXmlPitchData error: ${error}`);
    }

    return model;
  }

  /**
   * Get average pitch value within specified time range
   * @param data XmlPitchData containing pitch values
   * @param startOfFirstTone Start time of first tone (milliseconds)
   * @param start Range start time (milliseconds)
   * @param end Range end time (milliseconds)
   * @returns Average pitch value within range, returns 0 if no valid pitch found
   */
  static fetchPitchWithRange(
    data: XmlPitchData | null,
    startOfFirstTone: number,
    start: number,
    end: number
  ): number {
    if (!data || !data.pitches || data.pitches.length === 0) {
      return 0;
    }

    const fromIdx = Math.floor((start - startOfFirstTone) / data.interval);
    const toIdx = Math.floor((end - startOfFirstTone) / data.interval);

    let total = 0;
    let numberOfValidPitches = 0;

    for (let idx = fromIdx; idx < toIdx && idx < data.pitches.length; idx++) {
      if (idx >= 0) {
        const pitch = data.pitches[idx];
        if (pitch > 0) { // Filter values <= 0
          total += pitch;
          numberOfValidPitches++;
        }
      }
    }

    if (numberOfValidPitches > 0) {
      return total / numberOfValidPitches;
    }
    return 0;
  }

  /**
   * Parse KRC format pitch data
   * @param fileData Byte array containing KRC pitch data
   * @returns Array of PitchData objects, or null if parsing fails
   */
  static parseKrcPitchData(fileData: Uint8Array): PitchData[] | null {
    if (!fileData || fileData.length === 0) {
      return null;
    }

    try {
      let jsonData = Utils.uint8ArrayToString(fileData);

      const jsonObject: XmlPitchDataJson = JSON.parse(jsonData) as XmlPitchDataJson;
      if (jsonObject.pitchDatas) {
        const pitchDatas = jsonObject.pitchDatas;
        if (typeof pitchDatas === 'string') {
          return JSON.parse(pitchDatas) as PitchData[];
        } else if (Array.isArray(pitchDatas)) {
          return pitchDatas as PitchData[];
        }
      }
    } catch (error) {
      LogUtils.e(`parseKrcPitchData error: ${error}`);
    }

    return null;
  }

  /**
   * Read little-endian 32-bit integer from DataView
   * @param dataView DataView object
   * @param offset Offset position
   * @returns Read integer value
   */
  private static readLittleEndianInt(dataView: DataView, offset: number): number {
    return dataView.getInt32(offset, true); // true indicates little-endian
  }

  /**
   * Read little-endian 64-bit double precision floating point from DataView
   * @param dataView DataView object
   * @param offset Offset position
   * @returns Read double precision floating point value
   */
  private static readLittleEndianDouble(dataView: DataView, offset: number): number {
    return dataView.getFloat64(offset, true); // true indicates little-endian
  }

  /**
   * Read little-endian 64-bit long integer from DataView
   * @param dataView DataView object
   * @param offset Offset position
   * @returns Read long integer value
   */
  private static readLittleEndianLong(dataView: DataView, offset: number): bigint {
    return dataView.getBigInt64(offset, true); // true indicates little-endian
  }

  /**
   * Get unsigned byte value
   * @param dataView DataView object
   * @param offset Offset position
   * @returns Unsigned byte value
   */
  private static getUnsignedByte(dataView: DataView, offset: number): number {
    return dataView.getUint8(offset);
  }

  /**
   * Convert signed byte to unsigned byte value
   * @param b Signed byte
   * @returns Unsigned byte value
   */
  private static asUnsignedByte(b: number): number {
    return b & 0xFF;
  }
}
