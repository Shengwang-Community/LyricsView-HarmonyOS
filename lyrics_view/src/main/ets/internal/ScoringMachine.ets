import { IScoringAlgorithm } from '../IScoringAlgorithm';
import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel } from '../model/LyricsLineModel';
import { Pitch, PitchLineModel } from '../model/PitchLineModel';
import { LogUtils } from '../utils/LogUtils';
import { DefaultScoringAlgorithm } from './scoring/DefaultScoringAlgorithm';


/**
 * Scoring machine listener interface
 */
export interface OnScoringListener {
  /**
   * Callback when a lyrics line is finished
   * @param line The finished lyrics line
   * @param score Score for this line
   * @param cumulativeScore Cumulative score
   * @param index Line index
   * @param lineCount Total line count
   */
  onLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number, index: number, lineCount: number): void;

  /**
   * Reset UI
   */
  resetUi(): void;

  /**
   * Request UI refresh
   */
  requestRefreshUi(): void;

  /**
   * Callback for pitch and score updates
   * @param speakerPitch Processed user pitch
   * @param scoreAfterNormalization Normalized score (0-100)
   * @param progress Current progress (milliseconds)
   */
  onPitchAndScoreUpdate(speakerPitch: number, scoreAfterNormalization: number, progress: number): void;
}


/**
 * Scoring Machine - HarmonyOS version
 * Corresponds to ScoringMachine in Android project
 * Responsible for managing karaoke scoring calculation and state
 */
export class ScoringMachine {
  private lyricsModel: LyricModel | null = null;
  private listener?: OnScoringListener;
  private currentLyricProgress: number = 0;
  private maximumRefPitch: number = 0;
  private minimumRefPitch: number = 100;
  private pitchLines: PitchLineModel[] = [];
  private scoringAlgorithm: IScoringAlgorithm;
  private usingInternalScoring: boolean = false;
  private deltaOfUpdate: number = 20; // Default update interval 20ms
  private pitchesForLine: Map<number, number> = new Map();
  private scoreForEachLine: Map<number, number> = new Map();
  private timestampOfFirstRefPitch: number = -1;
  private endTimeOfThisLyrics: number = 0;
  private indexOfCurrentLine: number = 0;
  private initialScore: number = 0;
  private cumulativeScore: number = 0;
  private continuousZeroCount: number = 0;
  private readonly ZERO_PITCH_COUNT_THRESHOLD: number = 10;

  constructor(listener?: OnScoringListener) {
    this.listener = listener;
    this.scoringAlgorithm = new DefaultScoringAlgorithm();
    this.reset();
  }

  /**
   * Prepare scoring data
   * @param model Lyrics model
   * @param usingInternalScoring Whether to use internal scoring algorithm
   */
  prepare(model: LyricModel, usingInternalScoring: boolean): void {
    LogUtils.d('ScoringMachine: prepare LyricModel:' + model + ' has pitch:' + model.hasPitch);
    this.reset();

    if (!model || !model.lines || model.lines.length === 0) {
      LogUtils.e('ScoringMachine: Invalid lyrics model');
      return;
    }

    this.lyricsModel = this.mayBeFixLyricModel(model);
    this.usingInternalScoring = usingInternalScoring;
    this.endTimeOfThisLyrics = model.lines[model.lines.length - 1].getEndTime();
    this.timestampOfFirstRefPitch = model.preludeEndPosition;

    // Process pitch data
    if (model.hasPitch) {
      this.processPitchData(model);
    } else {
      LogUtils.d('ScoringMachine: Model has no pitch data');
    }

    LogUtils.d(`ScoringMachine: Prepared with ${model.lines.length} lines, pitch range: ${this.minimumRefPitch} - ${this.maximumRefPitch}`);
  }

  /**
   * Fix potential issues in lyrics model, such as overlapping lyrics lines
   *
   * @param model Original lyrics model
   * @returns Fixed lyrics model
   */
  private mayBeFixLyricModel(model: LyricModel): LyricModel {
    if (!model || !model.lines || model.lines.length === 0) {
      LogUtils.e('ScoringMachine: Invalid lyrics model in mayBeFixLyricModel');
      return model;
    }

    // Create a copy of the model for fixing
    const newModel = model.copy();

    if (!newModel.lines || newModel.lines.length === 0) {
      return model;
    }

    let preLineModel = newModel.lines[0];
    for (let i = 1; i < newModel.lines.length; i++) {
      const lineModel = newModel.lines[i];

      // Check if current line's start time is earlier than previous line's end time (overlapping case)
      if (lineModel.getStartTime() < preLineModel.getEndTime()) {
        const tones = lineModel.tones;

        if (tones && tones.length > 0) {
          // Fix overlapping tone segments
          for (const tone of tones) {
            if (tone.begin < preLineModel.getEndTime()) {
              // Adjust tone segment's start time to previous line's end time
              tone.begin = preLineModel.getEndTime();

              // Ensure end time is not earlier than start time
              if (tone.end < tone.begin) {
                tone.end = tone.begin;
              }
            } else {
              // If current tone segment doesn't overlap, subsequent ones won't either, can break
              break;
            }
          }
        }
      }

      preLineModel = lineModel;
    }

    LogUtils.d('ScoringMachine: mayBeFixLyricModel completed, fixed potential overlapping issues');
    return newModel;
  }

  /**
   * Process pitch data
   * @param model Lyrics model
   */
  private processPitchData(model: LyricModel): void {
    if (model.pitchDataList && model.pitchDataList.length > 0) {
      // Use independent pitch data
      for (const data of model.pitchDataList) {
        this.minimumRefPitch = Math.min(this.minimumRefPitch, data.pitch);
        this.maximumRefPitch = Math.max(this.maximumRefPitch, data.pitch);
      }

      this.pitchLines = [];
      const firstStartTime = model.lines[0].getStartTime();
      const lastEndTime = model.lines[model.lines.length - 1].getEndTime();

      for (const line of model.lines) {
        const lineModel = new PitchLineModel();
        const startTime = line.getStartTime();
        const endTime = line.getEndTime();

        for (const data of model.pitchDataList) {
          if (data.startTime >= startTime && data.startTime < endTime) {
            const pitch = new Pitch();
            pitch.begin = Math.max(data.startTime, firstStartTime);
            pitch.end = Math.min(data.startTime + data.duration, lastEndTime);
            pitch.pitch = data.pitch;
            lineModel.pitches.push(pitch);
          }
        }
        this.pitchLines.push(lineModel);
      }
    } else {
      // Use pitch data from lyrics lines
      this.pitchLines = [];
      for (const line of model.lines) {
        const lineModel = new PitchLineModel();
        if (line.tones && line.tones.length > 0) {
          for (const tone of line.tones) {
            const pitch = new Pitch();
            pitch.begin = tone.begin;
            pitch.end = tone.end;
            pitch.pitch = tone.pitch;

            this.minimumRefPitch = Math.min(this.minimumRefPitch, pitch.pitch);
            this.maximumRefPitch = Math.max(this.maximumRefPitch, pitch.pitch);

            lineModel.pitches.push(pitch);
          }
        }
        this.pitchLines.push(lineModel);
      }
    }
  }

  /**
   * Set pitch data
   * @param speakerPitch Current pitch value
   * @param pitchScore Pitch score
   */
  setPitch(speakerPitch: number, pitchScore: number): void {
    if (!this.lyricsModel) {
      this.listener?.resetUi();
      return;
    }

    // Process pitch scoring
    this.processPitchScoring(speakerPitch, pitchScore, this.currentLyricProgress);
    this.listener?.requestRefreshUi();
  }

  /**
   * Process pitch scoring
   * @param speakerPitch User pitch
   * @param pitchScore Pitch score
   * @param progressInMs Current progress
   */
  private processPitchScoring(speakerPitch: number, pitchScore: number, progressInMs: number): void {
    const newLine: boolean[] = [false];
    const indexOfMostRecentLine: number[] = [-1];
    let currentRefPitch = -1;

    if (this.usingInternalScoring) {
      currentRefPitch = this.findRefPitchByTime(progressInMs, newLine, indexOfMostRecentLine);
    }

    // Handle continuous zero pitch
    if (speakerPitch === 0) {
      if (++this.continuousZeroCount < this.ZERO_PITCH_COUNT_THRESHOLD) {
        if (this.usingInternalScoring) {
          this.updateScoreForMostRecentLine(progressInMs, newLine[0], indexOfMostRecentLine[0]);
        }
        return;
      }
    } else {
      this.continuousZeroCount = 0;
    }

    if (this.usingInternalScoring) {
      if (currentRefPitch <= 0 || this.continuousZeroCount >= this.ZERO_PITCH_COUNT_THRESHOLD) {
        this.continuousZeroCount = 0;
        this.updateScoreForMostRecentLine(progressInMs, newLine[0], indexOfMostRecentLine[0]);
        this.listener?.resetUi();
        return;
      }

      this.updateScoreForMostRecentLine(progressInMs, newLine[0], indexOfMostRecentLine[0]);

      // Simplified pitch processing
      const pitchAfterProcess = speakerPitch;
      const scoreAfterNormalization = this.scoringAlgorithm.getPitchScore(pitchAfterProcess, currentRefPitch);
      this.pitchesForLine.set(progressInMs, scoreAfterNormalization);

      this.listener?.onPitchAndScoreUpdate(pitchAfterProcess, scoreAfterNormalization, progressInMs);
    } else {
      const calculateScore = pitchScore > 0 ? pitchScore : this.calculateScoreWithPitch(speakerPitch, progressInMs);
      this.listener?.onPitchAndScoreUpdate(speakerPitch, calculateScore, progressInMs);
    }
  }

  /**
   * Set lyrics progress
   * @param progress Current progress (milliseconds)
   */
  setLyricProgress(progress: number): void {
    this.currentLyricProgress = progress;
  }


  /**
   * Find reference pitch by time
   * @param timestamp Timestamp
   * @param returnNewLine Whether it's a new line
   * @param returnIndexOfMostRecentLine Most recent line index
   * @returns Reference pitch value
   */
  private findRefPitchByTime(timestamp: number, returnNewLine: boolean[],
    returnIndexOfMostRecentLine: number[]): number {
    if (!this.lyricsModel || !this.lyricsModel.lines) {
      return -1;
    }

    let referencePitch = -1;
    const numberOfLines = this.lyricsModel.lines.length;
    let timestampLineIndex = -1;

    for (let i = 0; i < numberOfLines; i++) {
      const line = this.lyricsModel.lines[i];
      if (timestamp >= line.getStartTime() && timestamp <= line.getEndTime()) {
        if (line.tones && line.tones.length > 0) {
          for (let j = 0; j < line.tones.length; j++) {
            const tone = line.tones[j];
            if (timestamp >= tone.begin && timestamp <= tone.end) {
              referencePitch = tone.pitch;
              if (j === line.tones.length - 1) {
                timestampLineIndex = i;
              }
              break;
            }
          }
        }
        break;
      }
    }

    if (referencePitch !== -1) {
      this.pitchesForLine.set(timestamp, -1);
    }

    if (this.isNewLine(timestamp, numberOfLines, timestampLineIndex)) {
      returnIndexOfMostRecentLine[0] = this.indexOfCurrentLine;
      returnNewLine[0] = true;
    }

    if (timestampLineIndex !== -1 && timestampLineIndex !== this.indexOfCurrentLine) {
      this.indexOfCurrentLine = timestampLineIndex;
    }

    return referencePitch;
  }

  /**
   * Check if it's a new line
   * @param timestamp Timestamp
   * @param numberOfLines Total line count
   * @param timestampLineIndex Current line index
   * @returns Whether it's a new line
   */
  private isNewLine(timestamp: number, numberOfLines: number, timestampLineIndex: number): boolean {
    let newLine = false;

    if (this.indexOfCurrentLine >= 0 && this.indexOfCurrentLine + 1 <= numberOfLines) {
      if (timestamp > this.lyricsModel!.lines[this.indexOfCurrentLine].getEndTime()) {
        if (timestampLineIndex === -1) {
          if (!this.scoreForEachLine.has(this.indexOfCurrentLine)) {
            newLine = true;
          }
        } else if (this.indexOfCurrentLine !== timestampLineIndex) {
          if (!this.scoreForEachLine.has(this.indexOfCurrentLine)) {
            newLine = true;
          }
        }
      }
    } else if (this.indexOfCurrentLine + 2 === numberOfLines) {
      if (timestamp >= this.lyricsModel!.lines[this.indexOfCurrentLine].getEndTime()) {
        if (!this.scoreForEachLine.has(this.indexOfCurrentLine)) {
          newLine = true;
        }
      }
    }

    return newLine;
  }

  /**
   * Update score for the most recent line
   * @param timestamp Timestamp
   * @param newLine Whether it's a new line
   * @param indexOfMostRecentLine Most recent line index
   */
  private updateScoreForMostRecentLine(timestamp: number, newLine: boolean, indexOfMostRecentLine: number): void {
    if ((timestamp < this.timestampOfFirstRefPitch) || this.timestampOfFirstRefPitch === -1) {
      return;
    }

    if (timestamp > this.endTimeOfThisLyrics + (2 * this.deltaOfUpdate)) {
      return;
    }

    if (newLine && this.lyricsModel) {
      const lineJustFinished = this.lyricsModel.lines[indexOfMostRecentLine];
      const scoreThisTime =
        this.scoringAlgorithm.getLineScore(this.pitchesForLine, indexOfMostRecentLine, lineJustFinished);

      this.cumulativeScore += scoreThisTime;

      LogUtils.d(`ScoringMachine: Line ${indexOfMostRecentLine} finished, score: ${scoreThisTime}, cumulative: ${this.cumulativeScore}`);

      this.listener?.onLineFinished(lineJustFinished, scoreThisTime, this.cumulativeScore, indexOfMostRecentLine,
        this.lyricsModel.lines.length);
      this.scoreForEachLine.set(indexOfMostRecentLine, scoreThisTime);
    }
  }

  /**
   * Calculate score based on pitch
   * @param speakerPitch User pitch
   * @param progressInMs Current progress
   * @returns Calculated score
   */
  calculateScoreWithPitch(speakerPitch: number, progressInMs: number): number {
    const refPitch = this.getRefPitch(progressInMs);

    if (refPitch === 0) {
      return 0;
    }

    let scoreAfterNormalization = 0;

    if (speakerPitch == refPitch) {
      scoreAfterNormalization = 100;
    } else if (Math.abs(speakerPitch - refPitch) <= 1) {
      scoreAfterNormalization = 90;
    } else if (Math.abs(speakerPitch - refPitch) <= 2) {
      scoreAfterNormalization = 80;
    } else if (Math.abs(speakerPitch - refPitch) <= 3) {
      scoreAfterNormalization = 70;
    } else if (Math.abs(speakerPitch - refPitch) <= 4) {
      scoreAfterNormalization = 60;
    } else if (Math.abs(speakerPitch - refPitch) <= 5) {
      scoreAfterNormalization = 50;
    }

    return scoreAfterNormalization;
  }

  /**
   * Get reference pitch at specified time
   * @param progressInMs Progress time
   * @returns Reference pitch
   */
  getRefPitch(progressInMs: number): number {
    if (!this.lyricsModel) {
      return 0;
    }

    if (this.lyricsModel.hasPitch) {
      if (this.lyricsModel.pitchDataList) {
        for (const data of this.lyricsModel.pitchDataList) {
          if (data.startTime <= progressInMs && data.startTime + data.duration >= progressInMs) {
            return data.pitch;
          }
        }
      } else if (this.lyricsModel.lines) {
        for (const line of this.lyricsModel.lines) {
          if (line.tones) {
            for (const tone of line.tones) {
              if (tone.begin <= progressInMs && tone.end >= progressInMs) {
                return tone.pitch;
              }
            }
          }
        }
      }
    }

    return 0;
  }

  /**
   * Reset state
   */
  reset(): void {
    this.resetProperties();
    this.resetStats();
  }

  /**
   * Reset properties
   */
  private resetProperties(): void {
    this.lyricsModel = null;
    this.minimumRefPitch = 100;
    this.maximumRefPitch = 0;
    this.timestampOfFirstRefPitch = -1;
    this.endTimeOfThisLyrics = 0;
  }

  /**
   * Reset statistics
   */
  private resetStats(): void {
    this.minorReset();
    this.cumulativeScore = this.initialScore;
    this.scoreForEachLine.clear();
  }

  /**
   * Minor reset
   */
  private minorReset(): void {
    this.currentLyricProgress = 0;
    this.indexOfCurrentLine = 0;
    this.pitchesForLine.clear();
  }

  /**
   * Handle drag event
   * @param progress Dragged progress
   */
  whenDraggingHappen(progress: number): void {
    this.minorReset();

    if (this.lyricsModel) {
      for (let index = 0; index < this.lyricsModel.lines.length; index++) {
        const line = this.lyricsModel.lines[index];
        if (progress <= line.getStartTime()) {
          this.scoreForEachLine.delete(index);
        }
      }

      this.cumulativeScore = this.initialScore;
      for (const score of this.scoreForEachLine.values()) {
        this.cumulativeScore += score;
      }
    }
  }

  /**
   * Prepare UI
   */
  prepareUi(): void {
    this.listener?.resetUi();
  }

  // Getter methods
  isReady(): boolean {
    return this.lyricsModel !== null;
  }

  getCurrentPitchProgress(): number {
    return this.currentLyricProgress;
  }

  getMinimumRefPitch(): number {
    return this.minimumRefPitch;
  }

  getMaximumRefPitch(): number {
    return this.maximumRefPitch;
  }

  getPitchLines(): PitchLineModel[] {
    return this.pitchLines;
  }

  hasPitchData(): boolean {
    return this.lyricsModel?.hasPitch || false;
  }

  getLineStartTime(lineIndex: number): number {
    if (!this.lyricsModel || lineIndex < 0 || lineIndex >= this.lyricsModel.lines.length) {
      return 0;
    }
    return this.lyricsModel.lines[lineIndex].getStartTime();
  }

  setInitialScore(initialScore: number): void {
    this.cumulativeScore += initialScore;
    this.initialScore = initialScore;
  }

  /**
   * Set scoring algorithm
   * @param algorithm Scoring algorithm
   */
  setScoringAlgorithm(algorithm: IScoringAlgorithm): void {
    if (!algorithm) {
      throw new Error('IScoringAlgorithm should not be null');
    }
    this.scoringAlgorithm = algorithm;
  }

  /**
   * Set scoring difficulty level
   * @param level Difficulty level
   */
  setScoringLevel(level: number): void {
    if (this.scoringAlgorithm) {
      this.scoringAlgorithm.setScoringLevel(level);
    }
  }

  /**
   * Get scoring difficulty level
   * @returns Difficulty level
   */
  getScoringLevel(): number {
    if (this.scoringAlgorithm) {
      return this.scoringAlgorithm.getScoringLevel();
    }
    return 0;
  }

  /**
   * Set scoring compensation offset
   * @param offset Offset value
   */
  setScoringCompensationOffset(offset: number): void {
    if (this.scoringAlgorithm) {
      this.scoringAlgorithm.setScoringCompensationOffset(offset);
    }
  }

  /**
   * Get scoring compensation offset
   * @returns Offset value
   */
  getScoringCompensationOffset(): number {
    if (this.scoringAlgorithm) {
      return this.scoringAlgorithm.getScoringCompensationOffset();
    }
    return 0;
  }

  /**
   * Check if using internal scoring
   * @returns Whether using internal scoring
   */
  isUsingInternalScoring(): boolean {
    return this.usingInternalScoring;
  }
}
