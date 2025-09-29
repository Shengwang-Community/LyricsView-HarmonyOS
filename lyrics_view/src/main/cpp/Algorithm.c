//
//  Algorithm.c
//  AgoraLyricsScore - HarmonyOS Version
//

#include "Algorithm.h"
#include <math.h>

// Version identifier
#define PTS_version "20231021001_HarmonyOS"

// Utility macro definitions
#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

// Static variables - for algorithm state management
static double n = 0.0;
static double offset = 0.0;

/**
 * Convert pitch value to tone value
 * Fully corresponds to pitchToToneC function in Android version
 */
double pitchToToneC(double pitch) {
    double eps = 1e-6;
    return (fmax(0, log(pitch / 55 + eps) / log(2))) * 12;
}

/**
 * Calculate score - Core scoring algorithm
 * Fully corresponds to calculatedScoreC function in Android version
 */
float calculatedScoreC(double voicePitch, double stdPitch, int scoreLevel, int scoreCompensationOffset) {
    // Input validation
    if (voicePitch <= 0) {
        return 0;
    }
    if (stdPitch <= 0) {
        return 0;
    }

    // Parameter range limitation
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

    // Convert to tone values
    double stdTone = pitchToToneC(stdPitch);
    double voiceTone = pitchToToneC(voicePitch);

    // Core scoring algorithm
    float match = 1 - (float)scoreLevel / 100 * fabs(voiceTone - stdTone) + (float)scoreCompensationOffset / 100;
    float rate = 1 + ((float)scoreLevel / (float)50);

    match = match * 100 * rate;

    // Result range limitation
    match = max(0, match);
    match = min(100, match);
    return match;
}

/**
 * Handle pitch compensation - Octave pitch compensation algorithm v0.2
 * Fully corresponds to handlePitchC function in Android version
 */
double handlePitchC(double stdPitch, double voicePitch, double stdMaxPitch) {
    int cnt = 0;
    double stdTone = pitchToToneC(stdPitch);
    double voiceTone = pitchToToneC(voicePitch);

    // Input validation
    if (voicePitch <= 0) {
        return 0;
    }
    if (stdPitch <= 0) {
        return 0;
    }

    // If tone difference is within 6 semitones, return directly
    if (fabs(voiceTone - stdTone) <= 6) {
        return voicePitch;
    } else if (voicePitch < stdPitch) {
        // User pitch is too low, try frequency doubling compensation
        for (cnt = 0; cnt < 11; cnt++) {
            voicePitch = 2 * voicePitch;
            voiceTone = pitchToToneC(voicePitch);
            if (fabs(voiceTone - stdTone) <= 6) {
                return voicePitch;
            }
        }
    } else if (voicePitch > stdPitch) {
        // User pitch is too high, try frequency halving compensation
        for (cnt = 0; cnt < 11; cnt++) {
            voicePitch = voicePitch / 2;
            voiceTone = pitchToToneC(voicePitch);
            if (fabs(voiceTone - stdTone) <= 6) {
                return voicePitch;
            }
        }
    }
    return voicePitch;
}

/**
 * Reset algorithm state
 * Fully corresponds to resetC function in Android version
 */
void resetC(void) {
    offset = 0.0;
    n = 0.0;
}
