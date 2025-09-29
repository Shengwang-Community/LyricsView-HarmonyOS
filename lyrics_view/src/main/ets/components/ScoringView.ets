import { IScoringAlgorithm } from '../IScoringAlgorithm';
import { OnScoringListener, ScoringMachine } from '../internal/ScoringMachine';
import { ParticleConfig, ParticleRenderer, ParticleSystem, Range } from '../internal/particle';
import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel } from '../model/LyricsLineModel';
import { HighlightSegment, Pitch, PitchStickData } from '../model/PitchLineModel';
import { EventBus, ScoringEvents } from '../utils/EventBus';
import { LogUtils } from '../utils/LogUtils';

/**
 * Scoring display component - HarmonyOS version (ArkUI V2)
 * Used to display karaoke scoring information and pitch visualization
 */
@Component
export struct ScoringView {
  @Prop viewBackgroundColor: string = '#ffffbb33'; // Configurable background color
  @Prop leadingLinesColor: string = '#4DFFFFFF'
  @Prop leadingLinesHeight: number = 1
  @Prop pitchIndicatorColor: string = '#F0F0F0F0';
  @Prop pitchIndicatorWidth: number = 3;
  @Prop localPitchIndicatorColor: string = "#F0F0F0F0"
  @Prop localPitchIndicatorRadius: number = 8;
  @Prop pitchStickHeight: number = 4;
  @Prop pitchStickRadius: number = 4;
  @Prop refPitchStickDefaultColor: string = '#99FFFFFF';
  @Prop highlightedPitchStickColor: string = '#FFF44336';
  @Prop initialScore: number = 0;
  @Prop movingPixelsPerMs: number = 0.2;
  @Prop hitScoreThreshold: number = 0.7;
  @Prop startPointHorizontalBias: number = 0.4;
  @Prop enableParticleEffect: boolean = true;
  // Remove time compensation mechanism - should solve synchronization issues from root cause
  // State variables
  @State currentScore: number = 0;
  @State cumulativeScore: number = 0;
  @State localPitch: number = 0; // Raw input pitch value (may have jitter)
  @State inHighlightStatus: boolean = false;
  @State animatedPitch: number = 0; // Smoothed pitch value (used for UI display)
  @State animatedProgressMs: number = 0;
  @State preHighlightStatus: boolean = false;
  // Used to track pitch state changes for immediate response logic
  private lastLocalPitch: number = 0;
  // Highlighting related state - corresponding to Android version
  private pitchHighlightedTime: number = -1; // Current highlighting start time
  // UI layout related
  @State centerXOfStartPoint: number = 0;
  @State viewWidth: number = 0;
  @State viewHeight: number = 0;
  @State pitchIndicatorY: number = 0; // Y coordinate of pitch indicator
  @State pitchSticks: PitchStickData[] = []; // Currently visible pitch stick data
  // Particle system related
  @State particleSystem: ParticleSystem | null = null;
  private emittingInitialized: boolean = false;
  // Internal variables
  private eventBus: EventBus = EventBus.getInstance();
  private scoringMachine: ScoringMachine | null = null;
  private frameLoopRunning: boolean = false;
  private frameTimer: number = -1;

  build() {
    // Main pitch visualization area - using relative layout instead of absolute positioning
    Stack({ alignContent: Alignment.TopStart }) {
      // Layer 1: Background lines (bottom layer)
      this.buildBackgroundLines()

      // Layer 2: Gradient mask area (above background lines, below start line)
      this.buildOverPastWall()

      // Layer 3: Vertical start line (top layer, ensure visibility)
      this.buildStartLine()

      // Reference pitch sticks (based on lyrics pitch data)
      this.buildPitchSticks()

      // User pitch indicator
      this.buildLocalPitchIndicator()

      // Particle effect layer (topmost layer)
      if (this.enableParticleEffect && this.particleSystem) {
        ParticleRenderer({ particleSystem: this.particleSystem })
      }
    }
    .width('100%')
      .height('100%')
      .backgroundColor(this.viewBackgroundColor) // Configurable background color, default #ffffbb33
      .onAreaChange((oldValue: Area, newValue: Area) => {
        // Update view dimensions and calculate start point position
        this.viewWidth = Number(newValue.width);
        this.viewHeight = Number(newValue.height);
        this.centerXOfStartPoint = this.viewWidth * this.startPointHorizontalBias;
        LogUtils.d(`ScoringView: Area changed - width: ${this.viewWidth}, height: ${this.viewHeight}, centerX: ${this.centerXOfStartPoint}`);
      })
      .onAppear(() => {
        LogUtils.d('ScoringView: Component appeared, setting up event listeners');
        this.setupEventListeners();
        this.initParticleSystem();
      })
      .onDisAppear(() => {
        LogUtils.d('ScoringView: Component disappearing, cleaning up');
        this.removeEventListeners();
        this.cleanupParticleSystem();
      })
  }

  /**
   * Build background lines - using relative layout, not dependent on absolute coordinates
   */
  @Builder
  buildBackgroundLines() {
    // Solution 1: Use Column + justifyContent for even distribution
    Column() {
      // 6 lines, create 5 equal sections
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank() // Auto-fill space
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank()
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank()
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank()
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank()
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
    }
    .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween) // Even distribution
  }

  /**
   * Build gradient mask wall - corresponding to Android's drawOverPastWall
   * Linear gradient from mCenterXOfStartPoint to left boundary
   */
  @Builder
  buildOverPastWall() {
    if (this.centerXOfStartPoint > 0 && this.viewWidth > 0 && this.viewHeight > 0) {
      Rect()
        .width(this.centerXOfStartPoint)
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Right, // Left to right gradient
          colors: [
            ['#1F24C6FF', 0], // Left boundary
            ['#00FFFFFF', 1]// Right boundary
          ]
        })
        .position({ x: 0, y: 0 })
        .opacity(0.15)
    }
  }

  /**
   * Build start line - corresponding to Android's drawStartLine
   * Draw vertical line at mCenterXOfStartPoint position, using pitchIndicatorColor
   */
  @Builder
  buildStartLine() {
    if (this.centerXOfStartPoint > 0 && this.viewWidth > 0 && this.viewHeight > 0) {
      Line()
        .startPoint([this.centerXOfStartPoint, 0])
        .endPoint([this.centerXOfStartPoint, this.viewHeight])
        .stroke(this.pitchIndicatorColor) // Use pitchIndicatorColor, corresponding to Android implementation
        .strokeWidth(this.pitchIndicatorWidth)
    }
  }

  /**
   * Build pitch sticks - corresponding to Android's drawPitchSticks
   * Dynamically draw pitch sticks based on lyrics pitch data and current progress, supporting segmented coloring
   */
  @Builder
  buildPitchSticks() {
    if (this.viewWidth > 0 && this.viewHeight > 0 && this.pitchSticks.length > 0) {
      // Use ForEach to render all visible pitch sticks
      ForEach(this.pitchSticks, (stick: PitchStickData, index: number) => {
        Stack() {
          // 1. Draw basic pitch stick (default color)
          Rect()
            .width(stick.width)
            .height(stick.height)
            .fill(this.refPitchStickDefaultColor)
            .borderRadius(this.pitchStickRadius)

          // 2. Draw highlighted segments (corresponding to Android's highlightPartMap logic)
          ForEach(stick.highlightSegments, (segment: HighlightSegment, segIndex: number) => {
            Rect()
              .width(segment.endX - segment.startX)
              .height(stick.height)
              .fill(this.highlightedPitchStickColor)
              .borderRadius(this.pitchStickRadius)
              .position({
                x: segment.startX - stick.x, // Position relative to stick
                y: 0
              })
          }, (segment: HighlightSegment, segIndex: number) => `highlight_${index}_${segIndex}_${segment.startTime}`)

          // 3. Draw currently highlighting part (real-time highlighting)
          if (stick.isCurrentPitch && stick.isHighlighted) {
            Rect()
              .width(this.calculateCurrentHighlightWidth(stick))
              .height(stick.height)
              .fill(this.highlightedPitchStickColor)
              .borderRadius(this.pitchStickRadius)
              .position({
                x: this.calculateCurrentHighlightStartX(stick) - stick.x,
                y: 0
              })
          }
        }
        .position({
          x: stick.x,
          y: stick.y
        })
      }, (stick: PitchStickData, index: number) => `pitch_${index}_${stick.x}_${stick.y}`)
    }
  }

  /**
   * Build user pitch indicator - corresponding to Android's drawLocalPitchIndicator
   * Draw circular indicator at start line position, Y coordinate calculated based on current pitch
   */
  @Builder
  buildLocalPitchIndicator() {
    if (this.centerXOfStartPoint > 0 && this.viewWidth > 0 && this.viewHeight > 0 && this.pitchIndicatorY >= 0) {
      // Use Circle as pitch indicator, positioned on start line, Y coordinate calculated based on pitch
      Circle({ width: this.localPitchIndicatorRadius * 2, height: this.localPitchIndicatorRadius * 2 })
        .fill(this.localPitchIndicatorColor)
        .strokeWidth(2)
        .position({
          x: this.centerXOfStartPoint - this.localPitchIndicatorRadius,
          y: this.pitchIndicatorY - this.localPitchIndicatorRadius
        })
    }
  }

  /**
   * Calculate Y coordinate of pitch indicator - corresponding to Android's getYForPitchIndicator
   * Calculate Y position in view based on current pitch value and pitch range
   */
  private calculateYForPitchIndicator(): number {
    let targetY = 0;

    if (this.scoringMachine == null || !this.scoringMachine.isReady()) {
      // When not initialized, indicator at bottom
      targetY = this.viewHeight - this.localPitchIndicatorRadius;
    } else if (this.animatedPitch >= this.scoringMachine.getMinimumRefPitch() &&
      this.scoringMachine.getMaximumRefPitch() != 0) {
      // When there's valid pitch value, calculate position based on pitch range
      const realPitchMax = this.scoringMachine.getMaximumRefPitch() + 5;
      const realPitchMin = this.scoringMachine.getMinimumRefPitch() - 5;
      const itemHeightPerPitchLevel = this.viewHeight / (realPitchMax - realPitchMin);
      targetY = (realPitchMax - this.animatedPitch) * itemHeightPerPitchLevel;
    } else if (this.animatedPitch < this.scoringMachine.getMinimumRefPitch()) {
      // When pitch is too low, indicator at bottom
      targetY = this.viewHeight;
    } else {
      // When pitch is too high, indicator at top
      targetY = 0;
    }

    // 🎯 Strict boundary limits to ensure pitch ball doesn't go outside screen
    const minY = this.localPitchIndicatorRadius; // Top boundary, considering ball radius
    const maxY = this.viewHeight - this.localPitchIndicatorRadius; // Bottom boundary, considering ball radius
    targetY = Math.max(minY, Math.min(maxY, targetY));

    return targetY;
  }

  /**
   * Get render progress - corresponding to Android's getRenderProgressMs()
   * Use smooth animatedProgressMs for animation effects
   */
  private getRenderProgressMs(): number {
    return Math.round(this.animatedProgressMs);
  }

  /**
   * Get real-time playback progress - used for pitch stick position calculation
   * No smoothing to ensure timing accuracy
   */
  private getRealTimeProgressMs(): number {
    if (this.scoringMachine) {
      return this.scoringMachine.getCurrentPitchProgress();
    }
    return this.animatedProgressMs;
  }

  /**
   * Set up event listeners
   */
  private setupEventListeners(): void {
    LogUtils.d('ScoringView: Setting up event listeners');

    // Initialize ScoringMachine
    this.initScoringMachine();

    // Listen to lyric data setting event
    this.eventBus.on(ScoringEvents.SET_LYRIC_DATA, (lyricModel: LyricModel, usingInternalScoring: boolean) => {
      LogUtils.d('ScoringView: Received SET_LYRIC_DATA event');
      if (this.scoringMachine) {
        this.scoringMachine.prepare(lyricModel, usingInternalScoring);
        // Start frame loop for animation updates
        this.startFrameLoopIfNeeded();
        LogUtils.d(`ScoringView: Lyric data prepared in ScoringMachine with usingInternalScoring: ${usingInternalScoring}`);
      } else {
        LogUtils.e('ScoringView: ScoringMachine is null when receiving SET_LYRIC_DATA event');
      }
    });

    this.eventBus.on(ScoringEvents.SET_PROGRESS, (progress: number) => {
      if (this.scoringMachine) {
        this.scoringMachine.setLyricProgress(progress);
      }
    });

    // Listen to pitch data setting event
    this.eventBus.on(ScoringEvents.SET_PITCH, (speakerPitch: number, pitchScore: number) => {
      if (this.scoringMachine) {
        this.scoringMachine.setPitch(speakerPitch, pitchScore);
      }
    });

    // Listen to scoring algorithm setting event
    this.eventBus.on(ScoringEvents.SET_SCORING_ALGORITHM, (algorithm: IScoringAlgorithm) => {
      LogUtils.d('ScoringView: Received SET_SCORING_ALGORITHM event');
      if (this.scoringMachine) {
        this.scoringMachine.setScoringAlgorithm(algorithm);
        LogUtils.d('ScoringView: Scoring algorithm set successfully');
      } else {
        LogUtils.e('ScoringView: ScoringMachine is null when receiving SET_SCORING_ALGORITHM event');
      }
    });

    // Listen to scoring level setting event
    this.eventBus.on(ScoringEvents.SET_SCORING_LEVEL, (level: number) => {
      LogUtils.d(`ScoringView: Received SET_SCORING_LEVEL event, level: ${level}`);
      if (this.scoringMachine) {
        this.scoringMachine.setScoringLevel(level);
        LogUtils.d(`ScoringView: Scoring level set to ${level} successfully`);
      } else {
        LogUtils.e('ScoringView: ScoringMachine is null when receiving SET_SCORING_LEVEL event');
      }
    });

    // Listen to reset event
    this.eventBus.on(ScoringEvents.RESET, () => {
      LogUtils.d('ScoringView: Received RESET event');
      if (this.scoringMachine) {
        this.scoringMachine.reset();
      }
      this.reset();
    });
  }

  /**
   * Remove event listeners
   */
  private removeEventListeners(): void {
    LogUtils.d('ScoringView: Removing event listeners');
    this.stopFrameLoop();
  }

  /**
   * Initialize ScoringMachine
   */
  private initScoringMachine(): void {
    if(!this.scoringMachine) {
    LogUtils.d('ScoringView: Creating new ScoringMachine');

    /**
     * ScoringMachine listener implementation class
     */
    class ScoringViewListener implements OnScoringListener {
      private scoringView: ScoringView;

      constructor(scoringView: ScoringView) {
        this.scoringView = scoringView;
      }

      onLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number, index: number,
        lineCount: number): void {
        LogUtils.d(`ScoringView: Line finished - score: ${score}, cumulative: ${cumulativeScore}`);
        this.scoringView.handleLineFinished(score, cumulativeScore);
      }

      resetUi(): void {
        LogUtils.d('ScoringView: resetUi called from ScoringMachine');
        this.scoringView.resetPitchIndicatorAndAnimation();
      }

      requestRefreshUi(): void {
        this.scoringView.requestRefreshUi();
      }

      onPitchAndScoreUpdate(speakerPitch: number, scoreAfterNormalization: number, progress: number): void {
        this.scoringView.updatePitchAndScore(speakerPitch, scoreAfterNormalization);
      }
    }

    const listener = new ScoringViewListener(this);
    this.scoringMachine = new ScoringMachine(listener);

    // Set initial score
    this.scoringMachine.setInitialScore(this.initialScore);

    LogUtils.d('ScoringView: ScoringMachine created successfully');

  } else {
    LogUtils.d('ScoringView: ScoringMachine already exists');
  }
}

/**
 * Handle line finished event
 */
handleLineFinished(score: number, cumulativeScore: number): void {
  this.currentScore = score;
  this.cumulativeScore = cumulativeScore;
  this.resetPitchIndicatorAndAnimationWhenFullLineFinished(score);
}

  /**
   * Start frame loop (for animation updates)
   */
  private startFrameLoopIfNeeded(): void {
  if(this.frameLoopRunning) {
  return;
}

this.frameLoopRunning = true;

const frameLoop = () => {
  if (!this.frameLoopRunning) {
    return;
  }

  // Exponential smoothing algorithm - fully corresponding to Android version implementation
  // Corresponding to Java: float tauMs = 120f; float alpha = 1f - (float) Math.exp(-dtMs / tauMs);
  const tauMs = 120; // Smoothing constant, corresponding to Java version's 120f
  const dtMs = 16; // Frame interval 16ms (60fps)
  const alpha = 1 - Math.exp(-dtMs / tauMs);

  // Smart pitch update: immediate response only for silent to voiced, other cases use smooth animation
  const oldAnimatedPitch = this.animatedPitch;
  const wasZero = this.lastLocalPitch === 0;
  const isZero = this.localPitch === 0;
  const isNonZero = this.localPitch !== 0;

  if (wasZero && isNonZero) {
    // Immediate response: from 0 to non-0 (ensure highlighting starts immediately)
    this.animatedPitch = this.localPitch;
  } else {
    // Smooth animation: all other cases, including from value to 0 (make ending smoother)
    this.animatedPitch = this.animatedPitch + (this.localPitch - this.animatedPitch) * alpha;
  }

  // Update last pitch value for next judgment
  this.lastLocalPitch = this.localPitch;

  // Update Y coordinate of pitch indicator
  this.pitchIndicatorY = this.calculateYForPitchIndicator();

  // Update pitch stick data
  this.updatePitchSticks();

  // Update particle emission point position
  this.updateParticleEmissionPoint();

  // Smoothly update animation progress
  if (this.scoringMachine) {
    const machineProgress = this.scoringMachine.getCurrentPitchProgress();
    if (Math.abs(this.animatedProgressMs - machineProgress) > 2000) {
      this.animatedProgressMs = machineProgress; // Direct setting for large jumps
    } else {
      this.animatedProgressMs = this.animatedProgressMs + (machineProgress - this.animatedProgressMs) * alpha;
    }
  }

  // Continue to next frame
  this.frameTimer = setTimeout(frameLoop, 16); // About 60fps
};

frameLoop();
  }

  /**
   * Stop frame loop
   */
  private stopFrameLoop(): void {
  this.frameLoopRunning = false;
  if(this.frameTimer !== -1) {
  clearTimeout(this.frameTimer);
  this.frameTimer = -1;
}
  }

/**
 * Reset scoring display
 */
reset(): void {
  LogUtils.d('ScoringView: Resetting all state variables');

  // Reset basic state
  this.localPitch = 0;
  this.animatedPitch = 0;
  this.animatedProgressMs = 0;
  this.inHighlightStatus = false;
  this.preHighlightStatus = false;
  this.currentScore = 0;
  this.cumulativeScore = 0;
  this.pitchSticks = [];
  this.lastLocalPitch = 0; // Reset pitch state tracking

  // Reset highlighting related state
  this.pitchHighlightedTime = -1;

  // Reset UI position state
  this.pitchIndicatorY = 0;

  // Reset particle system state
  this.emittingInitialized = false;
  if(this.particleSystem) {
  this.particleSystem.stopEmitting(); // Stop particle emission
}

// Reset scoring machine state
if (this.scoringMachine) {
  this.scoringMachine.reset();
}

LogUtils.d('ScoringView: Reset completed');
  }

/**
 * Update pitch and score - corresponding to Android's updatePitchAndScore
 * Smart pitch value update: immediate response to 0 value changes, other cases smoothly handled by frame loop
 */
updatePitchAndScore(pitch: number, score: number): void {
  const oldLocalPitch = this.localPitch;
  this.localPitch = pitch;

  // Check if immediate Y coordinate update is needed (immediate response only for silent to voiced)
  const wasZero = oldLocalPitch === 0;
  const isNonZero = pitch !== 0;

  if(wasZero && isNonZero) {
  // Immediately update animatedPitch and Y coordinate to ensure highlighting logic can respond immediately
  this.animatedPitch = pitch;
  this.pitchIndicatorY = this.calculateYForPitchIndicator();
  this.lastLocalPitch = pitch;

  // Reset highlighting state to ensure new singing cycle can start correctly
  this.preHighlightStatus = false;
  this.pitchHighlightedTime = -1;

  // Immediately trigger pitch stick data update to ensure highlighting can take effect immediately
  this.updatePitchSticks();
}

// Set highlighting state based on externally passed score (corresponding to Android logic)
this.inHighlightStatus = score >= this.hitScoreThreshold * 100;

// Ensure particle animation based on externally passed score (corresponding to Android's assureAnimationForPitchIndicator)
this.assureParticleAnimation(score);

this.startFrameLoopIfNeeded();
  }

  /**
   * Calculate current highlight segment width - corresponding to Android's real-time highlighting logic
   */
  private calculateCurrentHighlightWidth(stick: PitchStickData): number {
  if (this.pitchHighlightedTime === -1) {
    return 0;
  }

  // Corresponding to Android's 40ms segment highlighting logic
  const INTERVAL_AUDIO_PCM = 40; // 40ms interval
  const realTimeProgress = this.getRealTimeProgressMs();
  const highlightEndX = this.centerXOfStartPoint - this.movingPixelsPerMs * INTERVAL_AUDIO_PCM;
  const highlightStartX =
    this.centerXOfStartPoint + (this.pitchHighlightedTime - realTimeProgress) * this.movingPixelsPerMs;

  return Math.max(0, highlightEndX - highlightStartX);
}

  /**
   * Calculate current highlight segment start X coordinate
   */
  private calculateCurrentHighlightStartX(stick: PitchStickData): number {
  if (this.pitchHighlightedTime === -1) {
    return stick.x;
  }

  const realTimeProgress = this.getRealTimeProgressMs();
  return this.centerXOfStartPoint + (this.pitchHighlightedTime - realTimeProgress) * this.movingPixelsPerMs;
}

  /**
   * Update pitch stick data - corresponding to Android's drawPitchSticks logic
   * Implement segmented highlighting and persistent highlighting effects
   */
  private updatePitchSticks(): void {
  if(!this.scoringMachine) {
  LogUtils.d('ScoringView: No scoring machine');
  this.pitchSticks = [];
  return;
}

if (!this.scoringMachine.isReady()) {
  this.pitchSticks = [];
  return;
}

if (!this.scoringMachine.hasPitchData()) {
  this.pitchSticks = [];
  return;
}

const renderProgress = this.getRenderProgressMs();
const pitchLines = this.scoringMachine.getPitchLines();

if (!pitchLines || pitchLines.length === 0) {
  LogUtils.d('ScoringView: No pitch lines available');
  this.pitchSticks = [];
  return;
}

const realPitchMax = this.scoringMachine.getMaximumRefPitch() + 5;
const realPitchMin = this.scoringMachine.getMinimumRefPitch() - 5;
const stickHeightPerPitchLevel = (this.viewHeight - this.pitchStickHeight) / (realPitchMax - realPitchMin);

const newPitchSticks: PitchStickData[] = [];

// Iterate through all pitch lines
for (let i = 0; i < pitchLines.length; i++) {
  const line = pitchLines[i];
  const pitches = line.pitches;

  if (!pitches || pitches.length === 0) {
    continue;
  }

  // Check if within visible range
  const lineStartTime = line.getStartTime();
  const lineEndTime = line.getEndTime();

  if (Math.abs(renderProgress - lineEndTime) * this.movingPixelsPerMs >= this.viewWidth &&
    Math.abs(renderProgress - lineStartTime) * this.movingPixelsPerMs >= this.viewWidth &&
    !(renderProgress >= lineStartTime && renderProgress <= lineEndTime)) {
    continue; // Not within visible range
  }

  // Iterate through all pitches in this line
  for (let pitchIndex = 0; pitchIndex < pitches.length; pitchIndex++) {
    const pitch = pitches[pitchIndex];

    // Calculate pitch stick X coordinate and width (use real-time progress to ensure synchronization with lyrics timing)
    const realTimeProgress = this.getRealTimeProgressMs();
    const pixelsAwayFromPilot = (pitch.begin - realTimeProgress) * this.movingPixelsPerMs;
    const x = this.centerXOfStartPoint + pixelsAwayFromPilot;
    const width = this.movingPixelsPerMs * pitch.getDuration();
    const endX = x + width;

    // Viewport clipping: skip invisible pitch sticks
    if (endX <= 0) {
      // When pitch stick moves off screen, reset highlight state
      pitch.resetHighlight();
      continue;
    }
    if (x >= this.viewWidth) {
      break;
    }

    // Calculate Y coordinate
    const y = (realPitchMax - pitch.pitch) * stickHeightPerPitchLevel;

    // Determine if it's the currently singing pitch (use real-time progress to ensure timing accuracy)
    const isCurrentPitch = realTimeProgress >= pitch.begin && realTimeProgress <= pitch.end;

    // Handle highlighting logic - corresponding to Android's highlightPartMap logic (use real-time progress)
    this.processHighlightLogic(pitch, isCurrentPitch, realTimeProgress);

    // Build highlight segment data (use real-time progress to ensure timing consistency)
    const highlightSegments = this.buildHighlightSegments(pitch, realTimeProgress, x, width);

    // Determine if highlighted (based on singing state)
    const isHighlighted = isCurrentPitch && this.inHighlightStatus;

    newPitchSticks.push({
      x: x,
      y: y,
      width: width,
      height: this.pitchStickHeight,
      pitch: pitch.pitch,
      isHighlighted: isHighlighted,
      isCurrentPitch: isCurrentPitch,
      highlightSegments: highlightSegments
    });
  }
}

this.pitchSticks = newPitchSticks;
  }

  /**
   * Process highlighting logic - corresponding to Android's highlightPartMap handling
   */
  private processHighlightLogic(pitch: Pitch, isCurrentPitch: boolean, realTimeProgress: number): void {
  const INTERVAL_AUDIO_PCM = 40; // 40ms interval, corresponding to Android's Constants.INTERVAL_AUDIO_PCM

  if(!isCurrentPitch) {
    // When not current pitch, complete all unfinished highlight segments
    const keys = Array.from(pitch.highlightPartMap.keys());
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = pitch.highlightPartMap.get(key);
      if (value === null) {
        pitch.highlightPartMap.set(key, { first: key, second: pitch.end });
      }
    }
  }

    if(isCurrentPitch) {
    if (this.inHighlightStatus) {
      // Start new highlight segment
      if (!this.preHighlightStatus) {
        this.pitchHighlightedTime = realTimeProgress;
        if (realTimeProgress - pitch.begin < INTERVAL_AUDIO_PCM) {
          this.pitchHighlightedTime = pitch.begin;
        }
        this.preHighlightStatus = this.inHighlightStatus;
      }

      // Record highlight segment start
      if (!pitch.highlightPartMap.has(this.pitchHighlightedTime)) {
        pitch.highlightPartMap.set(this.pitchHighlightedTime, null);
      }
    } else {
      // End highlight segment
      this.preHighlightStatus = false;
      if (this.pitchHighlightedTime !== -1) {
        pitch.highlightPartMap.set(this.pitchHighlightedTime, {
          first: this.pitchHighlightedTime,
          second: realTimeProgress
        });
        this.pitchHighlightedTime = -1;
      }
    }
  } else {
    // Reset state when not current pitch
    if(this.preHighlightStatus) {
  this.preHighlightStatus = false;
}
if (this.pitchHighlightedTime !== -1) {
  this.pitchHighlightedTime = -1;
}
    }
  }

  /**
   * Build highlight segment data - convert highlightPartMap to UI-usable HighlightSegment array
   */
  private buildHighlightSegments(pitch: Pitch, renderProgress: number, pitchX: number,
  pitchWidth: number): HighlightSegment[] {
  const segments: HighlightSegment[] = [];

  // Only process pitch sticks that have moved to the left of the start line
  if (pitchX < this.centerXOfStartPoint) {
    const keys = Array.from(pitch.highlightPartMap.keys());
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = pitch.highlightPartMap.get(key);
      if (value !== null && value !== undefined) {
        // Completed highlight segment
        const highlightStartTime = value.first;
        const highlightEndTime = value.second;

        const highlightStartX =
          this.centerXOfStartPoint + (highlightStartTime - renderProgress) * this.movingPixelsPerMs;
        const highlightEndX = highlightStartX + this.movingPixelsPerMs * (highlightEndTime - highlightStartTime);

        // Ensure highlight segment is within pitch stick range
        const clampedStartX = Math.max(highlightStartX, pitchX);
        const clampedEndX = Math.min(highlightEndX, pitchX + pitchWidth);

        if (clampedEndX > clampedStartX) {
          segments.push({
            startX: clampedStartX,
            endX: clampedEndX,
            startTime: highlightStartTime,
            endTime: highlightEndTime
          });
        }
      } else {
        // Ongoing highlight segment (currently singing)
        if (pitch.begin <= renderProgress && renderProgress <= pitch.end) {
          const highlightStartTime = key;
          const highlightStartX =
            this.centerXOfStartPoint + (highlightStartTime - renderProgress) * this.movingPixelsPerMs;
          const highlightEndX = this.centerXOfStartPoint;

          const clampedStartX = Math.max(highlightStartX, pitchX);
          const clampedEndX = Math.min(highlightEndX, pitchX + pitchWidth);

          if (clampedEndX > clampedStartX) {
            segments.push({
              startX: clampedStartX,
              endX: clampedEndX,
              startTime: highlightStartTime,
              endTime: renderProgress
            });
          }
        }
      }
    }
  }

  return segments;
}

/**
 * Reset pitch indicator and animation
 */
resetPitchIndicatorAndAnimation(): void {
  this.inHighlightStatus = false;
  this.localPitch = 0;
  this.pitchHighlightedTime = -1; // Reset highlight time
}

/**
 * Reset pitch indicator and animation when full line finished
 */
resetPitchIndicatorAndAnimationWhenFullLineFinished(score: number): void {
  if(score === 0) {
  this.inHighlightStatus = false;
  this.localPitch = 0;
}
  }

/**
 * Request UI refresh
 */
requestRefreshUi(): void {
  // UI will update automatically
}

  /**
   * Create particle configuration
   */
  private createParticleConfig(): Partial < ParticleConfig > {
  const speedRange: Range = { min: 1.0, max: 3.0 }; // Increase speed to make particles more visible
  const angleRange: Range = { min: 130, max: 230 };
  const rotationSpeedRange: Range = { min: 90, max: 180 };
  const scaleRange: Range = { min: 0.3, max: 0.5 }; // Adjust to more appropriate particle size

  const config: Partial<ParticleConfig> = {
  particlesPerSecond: 60, // Further increase emission frequency to ensure immediate large number of particles when highlighting
    maxParticles: 80, // Further increase maximum particle count
      particleLifetime: 800, // Extend particle lifetime to 1.5 seconds for more persistent particles
        speedRange: speedRange, // Corresponding to Android's setSpeedModuleAndAngleRange
          angleRange: angleRange, // Corresponding to Android's 130, 230 degrees
            rotationSpeedRange: rotationSpeedRange, // Corresponding to Android's setRotationSpeedRange
              scaleRange: scaleRange, // Corresponding to Android's setScaleRange
                fadeOutDuration: 50 // Extend fade out time to make particles more visible
};

return config;
  }

  /**
   * Initialize particle system - corresponding to Android's initParticleSystem
   */
  private initParticleSystem(): void {
  if(this.enableParticleEffect) {
  LogUtils.d('ScoringView: Initializing particle system');
  this.particleSystem = new ParticleSystem(this.createParticleConfig());
  LogUtils.d('ScoringView: Particle system initialized successfully');
}
  }

  /**
   * Clean up particle system
   */
  private cleanupParticleSystem(): void {
  if(this.particleSystem) {
  LogUtils.d('ScoringView: Cleaning up particle system');
  this.particleSystem.cancel();
  this.particleSystem = null;
  this.emittingInitialized = false;
}
  }

  /**
   * Ensure particle animation effect - corresponding to Android's assureAnimationForPitchIndicator
   */
  private assureParticleAnimation(scoreAfterNormalization: number): void {
  if(!this.enableParticleEffect || !this.particleSystem) {
  return;
}

// Corresponding to Android's particle animation logic: judge based on score threshold
if (scoreAfterNormalization >= this.hitScoreThreshold * 100) {

  if (!this.emittingInitialized) {
    // Particle animation position at current singing line (centerXOfStartPoint), corresponding to Android logic
    const emitX = this.centerXOfStartPoint;
    const emitY = this.pitchIndicatorY;

    this.particleSystem.emit(emitX, emitY);
    this.emittingInitialized = true;
  } else {
    // Update emission point position - corresponding to Android's updateEmitPoint
    this.particleSystem.updateEmitPoint(this.centerXOfStartPoint, this.pitchIndicatorY);
  }

  // Resume emission - corresponding to Android's resumeEmitting, this will immediately create particles
  this.particleSystem.resumeEmitting();
} else {
  // Score below threshold, stop particle emission
  if (this.particleSystem) {
    this.particleSystem.stopEmitting(); // Corresponding to Android's stopEmitting
  }
}
  }

  /**
   * Update particle emission point position - called in frame loop
   */
  private updateParticleEmissionPoint(): void {
  if(this.enableParticleEffect && this.particleSystem && this.inHighlightStatus) {
  // Smoothly update particle emission point position - corresponding to Android's particle position update in frame loop
  this.particleSystem.updateEmitPoint(this.centerXOfStartPoint, this.pitchIndicatorY);
}
  }
}
