/**
 * Native module type declarations
 * Used for TypeScript compiler to recognize Native functions
 */

declare module 'liblyrics_view.so' {
  /**
   * Convert pitch value to tone value
   */
  export function pitchToTone(pitch: number): number;

  /**
   * Calculate score
   */
  export function calculatedScore(
    voicePitch: number,
    stdPitch: number,
    scoreLevel: number,
    scoreCompensationOffset: number
  ): number;

  /**
   * Handle pitch compensation
   */
  export function handlePitch(
    stdPitch: number,
    voicePitch: number,
    stdMaxPitch: number
  ): number;

  /**
   * Reset algorithm state
   */
  export function reset(): void;

  /**
   * Test function
   */
  export function add(a: number, b: number): number;
}
