//
//  Algorithm.h
//  AgoraLyricsScore - HarmonyOS Version
//

#ifndef Algorithm_h
#define Algorithm_h

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Convert pitch value to tone value
 * @param pitch Pitch value
 * @return Converted tone value
 */
double pitchToToneC(double pitch);

/**
 * Calculate score
 * @param voicePitch User pitch
 * @param stdPitch Standard pitch
 * @param scoreLevel Score level (0-100)
 * @param scoreCompensationOffset Compensation offset (0-100)
 * @return Calculated score (0-100)
 */
float calculatedScoreC(double voicePitch, double stdPitch, int scoreLevel, int scoreCompensationOffset);

/**
 * Handle pitch compensation - Octave pitch compensation algorithm v0.2
 * @param stdPitch Standard pitch
 * @param voicePitch User pitch
 * @param stdMaxPitch Maximum standard pitch
 * @return Processed pitch value
 */
double handlePitchC(double stdPitch, double voicePitch, double stdMaxPitch);

/**
 * Reset algorithm state
 */
void resetC(void);

#ifdef __cplusplus
}
#endif

#endif /* Algorithm_h */
