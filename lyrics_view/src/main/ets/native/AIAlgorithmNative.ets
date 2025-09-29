/**
 * HarmonyOS Native AI Algorithm Interface
 * Corresponds to AIAlgorithmScoreNative in Android version
 * Calls C++ algorithm implementation through NAPI
 */

// Import functions from Native module
import { add, calculatedScore, handlePitch, pitchToTone, reset } from 'liblyrics_view.so';

// Direct import and use of Native functions, type declarations defined in Index.d.ts

/**
 * Native AI Algorithm Interface Class
 * Provides algorithm calls completely consistent with Android version
 */
export class AIAlgorithmNative {
  /**
   * Convert pitch value to tone value
   * Corresponds to Android's pitchToTone method
   *
   * @param pitch Pitch value
   * @return Converted tone value
   */
  static pitchToTone(pitch: number): number {
    try {
      return pitchToTone(pitch);
    } catch (error) {
      console.error('AIAlgorithmNative.pitchToTone error:', error);
      return 0;
    }
  }

  /**
   * Calculate score
   * Corresponds to Android's calculatedScore method
   *
   * @param voicePitch User pitch
   * @param stdPitch Standard pitch
   * @param scoreLevel Score level (0-100)
   * @param scoreCompensationOffset Compensation offset (0-100)
   * @return Calculated score (0-100)
   */
  static calculatedScore(voicePitch: number, stdPitch: number, scoreLevel: number,
    scoreCompensationOffset: number): number {
    try {
      return calculatedScore(voicePitch, stdPitch, scoreLevel, scoreCompensationOffset);
    } catch (error) {
      console.error('AIAlgorithmNative.calculatedScore error:', error);
      return 0;
    }
  }

  /**
   * Handle pitch compensation
   * Corresponds to Android's handlePitch method
   *
   * @param stdPitch Standard pitch
   * @param voicePitch User pitch
   * @param stdMaxPitch Maximum standard pitch
   * @return Processed pitch value
   */
  static handlePitch(stdPitch: number, voicePitch: number, stdMaxPitch: number): number {
    try {
      return handlePitch(stdPitch, voicePitch, stdMaxPitch);
    } catch (error) {
      console.error('AIAlgorithmNative.handlePitch error:', error);
      return voicePitch; // Return original value on error
    }
  }

  /**
   * Reset algorithm state
   * Corresponds to Android's reset method
   */
  static reset(): void {
    try {
      reset();
    } catch (error) {
      console.error('AIAlgorithmNative.reset error:', error);
    }
  }

  /**
   * Test Native module connection
   * Used to verify if NAPI is working properly
   */
  static testConnection(): number {
    try {
      return add(1, 2); // Should return 3
    } catch (error) {
      console.error('AIAlgorithmNative.testConnection error:', error);
      return -1;
    }
  }
}
