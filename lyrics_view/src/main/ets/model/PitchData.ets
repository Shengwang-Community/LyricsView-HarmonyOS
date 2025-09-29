/**
 * Pitch data model
 * Corresponds to PitchData in Android project
 * Interface representing pitch data for karaoke scoring
 */
export interface PitchData {
  /** Start time in milliseconds */
  startTime: number;

  /** Duration in milliseconds */
  duration: number;

  /** Pitch value */
  pitch: number;
}

/**
 * Factory function to create PitchData object
 * @param startTime Start time, defaults to 0
 * @param duration Duration, defaults to 0
 * @param pitch Pitch value, defaults to 0
 * @returns PitchData object
 */
export function createPitchData(
  startTime: number = 0,
  duration: number = 0,
  pitch: number = 0
): PitchData {
  return { startTime, duration, pitch };
}
