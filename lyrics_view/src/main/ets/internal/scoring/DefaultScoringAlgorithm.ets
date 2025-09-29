import { IScoringAlgorithm } from '../../IScoringAlgorithm';
import { LyricsLineModel, Tone } from '../../model/LyricsLineModel';
import { AIAlgorithmNative } from '../../native/AIAlgorithmNative';
import { LogUtils } from '../../utils/LogUtils';

/**
 * Default implementation of the IScoringAlgorithm interface.
 * This class provides scoring functionality for karaoke performances by evaluating
 * the match between user's pitch and reference pitch data.
 */
export class DefaultScoringAlgorithm implements IScoringAlgorithm {
  /**
   * Maximum score for one line, 100 for maximum and 0 for minimum
   */
  private readonly maximumScoreForLine: number = 100;
  /**
   * Difficulty level for scoring (0-100, higher values are more lenient)
   * Can be changed by the application
   */
  private scoringLevel: number = 15;
  /**
   * Compensation offset for scoring (-100 to 100)
   * Used to adjust scores based on external factors
   */
  private scoringCompensationOffset: number = 0;

  /**
   * Constructs a new DefaultScoringAlgorithm with default settings
   */
  constructor() {
  }

  /**
   * Calculates a normalized score for the current pitch compared to the reference pitch
   * Calls HarmonyOS Native C++ algorithm implementation - identical to Android version
   *
   * @param currentPitch    The current pitch detected from the user's voice
   * @param currentRefPitch The reference pitch from the song
   * @return A normalized score value (0-100)
   */
  getPitchScore(currentPitch: number, currentRefPitch: number): number {
    try {
      // Directly call Native C++ implementation, identical to Android version
      return AIAlgorithmNative.calculatedScore(currentPitch, currentRefPitch, this.scoringLevel,
        this.scoringCompensationOffset);
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native call failed, using fallback: ${error}`);
      // If Native call fails, use TypeScript implementation as fallback
      return this.calculatedScoreFallback(currentPitch, currentRefPitch, this.scoringLevel,
        this.scoringCompensationOffset);
    }
  }

  /**
   * Converts pitch value to tone value - Native call
   *
   * @param pitch The pitch value
   * @return The converted tone value
   */
  pitchToTone(pitch: number): number {
    try {
      return AIAlgorithmNative.pitchToTone(pitch);
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native pitchToTone failed, using fallback: ${error}`);
      return this.pitchToToneFallback(pitch);
    }
  }

  /**
   * Converts pitch value to tone value - TypeScript fallback implementation
   *
   * @param pitch The pitch value
   * @return The converted tone value
   */
  private pitchToToneFallback(pitch: number): number {
    const eps = 1e-6;
    return Math.max(0, Math.log(pitch / 55 + eps) / Math.log(2)) * 12;
  }

  /**
   * Calculates score - TypeScript fallback implementation
   * Completely ported from C++ algorithm
   *
   * @param voicePitch User's pitch
   * @param stdPitch Standard pitch
   * @param scoreLevel Scoring level (0-100)
   * @param scoreCompensationOffset Compensation offset (0-100)
   * @return Calculated score (0-100)
   */
  private calculatedScoreFallback(voicePitch: number, stdPitch: number, scoreLevel: number,
    scoreCompensationOffset: number): number {
    // Input validation - corresponds to C++ version validation logic
    if (voicePitch <= 0) {
      return 0;
    }
    if (stdPitch <= 0) {
      return 0;
    }

    // Parameter range limitation - corresponds to C++ version parameter checking
    if (scoreLevel <= 0) {
      scoreLevel = 1;
    } else if (scoreLevel > 100) {
      scoreLevel = 100;
    }

    if (scoreCompensationOffset < 0) {
      scoreCompensationOffset = 0;
    } else if (scoreCompensationOffset > 100) {
      scoreCompensationOffset = 100;
    }

    // Convert to tone values - corresponds to C++ pitchToToneC call
    const stdTone = this.pitchToToneFallback(stdPitch);
    const voiceTone = this.pitchToToneFallback(voicePitch);

    // Core scoring algorithm - completely corresponds to C++ version calculation logic
    let match = 1 - (scoreLevel / 100) * Math.abs(voiceTone - stdTone) + (scoreCompensationOffset / 100);
    const rate = 1 + (scoreLevel / 50);

    match = match * 100 * rate;

    // Result range limitation - corresponds to C++ min/max macros
    match = Math.max(0, match);
    match = Math.min(100, match);

    return match;
  }

  /**
   * Handles pitch compensation - Native call
   * Octave pitch compensation algorithm v0.2
   *
   * @param stdPitch Standard pitch
   * @param voicePitch User's pitch
   * @param stdMaxPitch Maximum standard pitch
   * @return Processed pitch value
   */
  handlePitch(stdPitch: number, voicePitch: number, stdMaxPitch: number): number {
    try {
      return AIAlgorithmNative.handlePitch(stdPitch, voicePitch, stdMaxPitch);
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native handlePitch failed, using fallback: ${error}`);
      return this.handlePitchFallback(stdPitch, voicePitch, stdMaxPitch);
    }
  }

  /**
   * Handles pitch compensation - TypeScript fallback implementation
   * Octave pitch compensation algorithm v0.2
   *
   * @param stdPitch Standard pitch
   * @param voicePitch User's pitch
   * @param stdMaxPitch Maximum standard pitch
   * @return Processed pitch value
   */
  private handlePitchFallback(stdPitch: number, voicePitch: number, stdMaxPitch: number): number {
    let cnt = 0;
    const stdTone = this.pitchToToneFallback(stdPitch);
    let voiceTone = this.pitchToToneFallback(voicePitch);
    let adjustedVoicePitch = voicePitch;

    // Input validation
    if (voicePitch <= 0) {
      return 0;
    }
    if (stdPitch <= 0) {
      return 0;
    }

    // If tone difference is within 6 semitones, return directly
    if (Math.abs(voiceTone - stdTone) <= 6) {
      return adjustedVoicePitch;
    } else if (adjustedVoicePitch < stdPitch) {
      // User's pitch is too low, try frequency doubling compensation
      for (cnt = 0; cnt < 11; cnt++) {
        adjustedVoicePitch = 2 * adjustedVoicePitch;
        voiceTone = this.pitchToToneFallback(adjustedVoicePitch);
        if (Math.abs(voiceTone - stdTone) <= 6) {
          return adjustedVoicePitch;
        }
      }
    } else if (adjustedVoicePitch > stdPitch) {
      // User's pitch is too high, try frequency halving compensation
      for (cnt = 0; cnt < 11; cnt++) {
        adjustedVoicePitch = adjustedVoicePitch / 2;
        voiceTone = this.pitchToToneFallback(adjustedVoicePitch);
        if (Math.abs(voiceTone - stdTone) <= 6) {
          return adjustedVoicePitch;
        }
      }
    }

    return adjustedVoicePitch;
  }

  /**
   * Resets algorithm state - Native call
   */
  reset(): void {
    try {
      AIAlgorithmNative.reset();
      LogUtils.d('DefaultScoringAlgorithm: Native algorithm state reset');
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native reset failed: ${error}`);
    }
  }

  /**
   * Tests Native connection
   * Used to verify if C++ module is working properly
   */
  testNativeConnection(): boolean {
    try {
      const result = AIAlgorithmNative.testConnection();
      LogUtils.d(`DefaultScoringAlgorithm: Native test result: ${result}`);
      return result === 3; // add(1, 2) should return 3
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native test failed: ${error}`);
      return false;
    }
  }

  /**
   * Calculates the overall score for a completed lyrics line
   *
   * @param pitchesForLine          Map of timestamps to pitch scores for the line
   * @param indexOfLineJustFinished Index of the line that was just finished
   * @param lineJustFinished        The lyrics line model that was just finished
   * @return The calculated score for the line (0-100)
   */
  getLineScore(pitchesForLine: Map<number, number>, indexOfLineJustFinished: number,
    lineJustFinished: LyricsLineModel): number {
    const tones = lineJustFinished.tones;
    if (!tones || tones.length === 0) {
      return 0;
    }

    const toneScoresMap = new Map<Tone, number>();

    let toneIndex = 0;
    let totalScoreForTone = 0;
    let scoreCountForTone = 0;

    // Iterate through all tone data points
    for (const entry of pitchesForLine.entries()) {
      const timestamp = entry[0];
      const score = entry[1];
      // Find the corresponding tone segment
      while (toneIndex < tones.length) {
        const currentTone = tones[toneIndex];

        if (timestamp >= currentTone.begin && timestamp <= currentTone.end) {
          // Current timestamp belongs to this tone segment
          if (score >= 0) {
            totalScoreForTone += score;
            scoreCountForTone++;
          }
          break;
        } else if (timestamp > currentTone.end) {
          // Current tone segment ends, save score and move to next tone segment
          if (scoreCountForTone > 0) {
            toneScoresMap.set(currentTone, totalScoreForTone / scoreCountForTone);
          } else {
            toneScoresMap.set(currentTone, 0);
          }

          toneIndex++;
          totalScoreForTone = 0;
          scoreCountForTone = 0;
        } else {
          // Timestamp hasn't reached current tone segment yet
          break;
        }
      }
    }

    // Handle the last tone segment
    if (toneIndex < tones.length) {
      const currentTone = tones[toneIndex];
      if (scoreCountForTone > 0) {
        toneScoresMap.set(currentTone, totalScoreForTone / scoreCountForTone);
      } else {
        toneScoresMap.set(currentTone, 0);
      }
    }

    // Calculate average score for the entire line
    if (toneScoresMap.size > 0) {
      let totalScoreForThisLine = 0;
      for (const score of toneScoresMap.values()) {
        totalScoreForThisLine += score;
      }

      const lineScore = Math.round(totalScoreForThisLine / toneScoresMap.size);

      LogUtils.d(`DefaultScoringAlgorithm: Line ${indexOfLineJustFinished} score calculation - tones: ${tones.length}, scores: ${toneScoresMap.size}, final score: ${lineScore}`);

      return lineScore;
    }

    return 0;
  }

  /**
   * Gets the maximum possible score for a line
   *
   * @return The maximum score value (100)
   */
  getMaximumScoreForLine(): number {
    return this.maximumScoreForLine;
  }

  /**
   * Sets the scoring difficulty level
   *
   * @param level The difficulty level (0-100, higher values are more lenient)
   */
  setScoringLevel(level: number): void {
    this.scoringLevel = level;
  }

  /**
   * Sets the scoring compensation offset
   *
   * @param offset The compensation offset (-100 to 100)
   */
  setScoringCompensationOffset(offset: number): void {
    this.scoringCompensationOffset = offset;
  }

  /**
   * Gets the current scoring difficulty level
   *
   * @return The current difficulty level
   */
  getScoringLevel(): number {
    return this.scoringLevel;
  }

  /**
   * Gets the current scoring compensation offset
   *
   * @return The current compensation offset
   */
  getScoringCompensationOffset(): number {
    return this.scoringCompensationOffset;
  }
}
