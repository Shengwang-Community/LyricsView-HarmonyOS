/**
 * Lyric type enumeration - HarmonyOS version
 * Corresponds to LyricType in Android project
 * Enumeration for different types of lyrics formats supported
 */
export enum LyricType {
  /**
   * LRC format - standard lyrics format with time stamps
   */
  LRC = 'LRC',

  /**
   * XML format - structured lyrics format
   */
  XML = 'XML',

  /**
   * KRC format - karaoke lyrics format with character-level timing
   */
  KRC = 'KRC'
}
