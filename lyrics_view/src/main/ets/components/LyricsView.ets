import { LyricType } from '../constants/LyricType';
import { LyricMachine, OnLyricListener } from '../internal/LyricMachine';
import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel, Tone } from '../model/LyricsLineModel';
import { EventBus, LyricsEvents } from '../utils/EventBus';
import { LogUtils } from '../utils/LogUtils';

/**
 * Physical display line interface
 * Represents a physical display line after splitting a logical lyrics line
 */
interface DisplayLine {
  text: string;
  tones: Tone[];
  startTime: number;
  endTime: number;
}

/**
 * A custom component for displaying karaoke lyrics with various visual effects.
 * Supports features like highlighting current line, scrolling animations,
 * line wrapping, and touch interactions for seeking.
 */
@Component
export struct LyricsView {
  @Prop viewBackgroundColor: string = '#CE93D8'; // Configurable background color
  /** Text size for normal lyrics lines */
  @Prop textSize: number = 16;
  /** Text size for current line */
  @Prop currentLineTextSize: number = 20;
  /** Text color for current line's normal text */
  @Prop currentLineTextColor: string = '#FFFF00';
  /** Text color for current line's highlighted portion */
  @Prop currentLineHighlightedTextColor: string = '#FFF44336';
  /** Text color for previous lyrics lines */
  @Prop previousLineTextColor: string = '#FFFFFF';
  /** Text color for upcoming lyrics lines */
  @Prop upcomingLineTextColor: string = '#FFFFFF';
  /** Vertical spacing between lyrics lines */
  @Prop lineSpacing: number = 15;
  /** Top padding for the entire lyrics view */
  @Prop paddingTop: number = 15;
  /** Text to display when no lyrics are available */
  @Prop labelWhenNoLyrics: string = '暂无歌词';
  /** Whether to enable automatic line wrapping for long lyrics */
  @Prop enableLineWrap: boolean = false;
  /** Whether dragging is enabled */
  @Prop enableDragging: boolean = true;
  /** Whether to enable opacity fade effect for top and bottom lyrics lines */
  @Prop enableOpacityEffect: boolean = true;
  /** Whether to show lyrics lines before the current line */
  @Prop enablePreviousLines: boolean = true;
  /** Whether to show lyrics lines after the current line */
  @Prop enableUpcomingLines: boolean = true;
  /** Whether to show the prelude end position indicator */
  @Prop enablePreludeEndPositionIndicator: boolean = true;
  /** Top padding for the prelude end position indicator */
  @Prop preludeEndPositionIndicatorPaddingTop: number = 5;
  /** Radius of the prelude end position indicator dots */
  @Prop preludeEndPositionIndicatorRadius: number = 4;
  /** Color of the prelude end position indicator */
  @Prop preludeEndPositionIndicatorColor: string = '#FF6B35';
  /** Horizontal alignment of lyrics text (0=center, 1=left, 2=right) */
  @Prop textGravity: number = 0;
  // Internal state
  /** Index of the currently displayed lyrics line */
  @State private mIndexOfCurrentLine: number = -1;
  /** Reactive copy of the lyrics model */
  @State private lyricsModel: LyricModel | null = null;
  /** Reactive array of lyrics lines */
  @State private lyricsLines: LyricsLineModel[] = [];
  /** Current timestamp in the lyrics playback */
  @State private mCurrentTime: number = 0;
  @State private mDraggingInProgress: boolean = false;
  @State private mCurrentLineTranslateX: number = 0;
  // Horizontal scrolling related state
  // Actual component dimensions measured dynamically
  @State private actualViewHeight: number = 400; // Default value, will be overridden by actual measurement
  @State private actualViewWidth: number = 300; // Default value, will be overridden by actual measurement
  // Drag related state
  @State private initialTouchY: number = 0; // Initial touch Y coordinate
  @State private dragLineOffset: number = 0; // Lyrics line offset during dragging
  @State private originalCurrentLineIndex: number = -1; // Original current line index when drag started
  // Animation state management
  @State private isAnimating: boolean = false;
  @State private animationKey: number = 0; // Used to force re-render animation
  @State private transitioningFromIndex: number = -1; // Index of the line transitioning from current
  @State private transitioningFromY: number = 0; // Starting Y position of transitioning line
  @State private transitioningToY: number = 0; // Target Y position of transitioning line
  @State private newCurrentTransitioning: boolean = false; // Whether new current line is transitioning
  @State private newCurrentFromY: number = 0; // Starting Y position of new current line
  @State private newCurrentToY: number = 0; // Target Y position of new current line
  @State private styleTransitioning: boolean = false; // Whether style is transitioning
  // Text scrolling related state
  @State private isTextScrolling: boolean = false; // Whether text is scrolling
  @State private textScrollTimer: number = -1; // Text scroll timer
  // Current line scroll offset state (for debug logging)
  @State private currentLineScrollOffset: number = 0;
  @State private linePaddingLeftRight: number = 20;
  /** The lyrics state machine managing lyrics progression */
  private mLyricMachine: LyricMachine | null = null;
  // Text scroll controller for horizontal scrolling
  private textScroller: Scroller = new Scroller();
  // Event bus instance for global communication
  private eventBus: EventBus = EventBus.getInstance();

  /**
   * Requests a refresh of the UI.
   * Updates the progress and triggers a redraw if necessary.
   */
  requestRefreshUi(): void {
    if (this.mLyricMachine) {
      // Synchronously update reactive state
      const currentModel = this.mLyricMachine.getLyricsModel();
      this.lyricsModel = currentModel;
      this.lyricsLines = currentModel?.lines || [];

      this.updateByProgress(this.mLyricMachine.getCurrentLyricProgress());
    }
  }

  /**
   * Resets the view to its initial state.
   * Clears all loaded lyrics and internal state.
   */
  reset(): void {

    this.resetInternal();
  }

  /**
   * Complete reset, including clearing LyricMachine reference
   * Only called when component is destroyed or needs complete cleanup
   */
  resetCompletely(): void {
    this.mLyricMachine = null;
    this.resetInternal();
  }

  /**
   * Checks if the lyrics view is uninitialized or has no lyrics data.
   * @return true if lyrics are not available or not initialized
   */
  private uninitializedOrNoLyrics(): boolean {
    const hasLyricMachine = !!this.mLyricMachine;
    const hasModel = !!this.lyricsModel;
    const hasLines = this.lyricsLines.length > 0;

    return !hasLyricMachine || !hasModel || !hasLines;
  }

  /**
   * Updates the view based on the current timestamp.
   * Handles line transitions and triggers animations when necessary.
   * @param timestamp Current playback position in milliseconds
   */
  private updateByProgress(timestamp: number): void {
    this.mCurrentTime = timestamp;
    const lyricsModel = this.mLyricMachine?.getLyricsModel();

    if (this.refreshNoLyrics()) {
      LogUtils.d('LyricsView: No lyrics available, showing no lyrics message');
      return;
    }

    const line = this.quickSearchLineByTimestamp(this.mCurrentTime);

    if (line < 0 || !lyricsModel || line >= lyricsModel.lines.length) {
      LogUtils.d('LyricsView: Invalid line index, no UI update needed');
      return;
    }

    if (line !== this.mIndexOfCurrentLine) {
      const oldLine = this.mIndexOfCurrentLine;

      // Stop previous line's text scrolling
      this.stopTextScrollAnimation();

      // Trigger line change animation
      this.triggerLineChangeAnimation(this.mIndexOfCurrentLine, line);

      this.mIndexOfCurrentLine = line;

      // Start new current line's text scrolling
      const lyricsModel = this.mLyricMachine?.getLyricsModel();
      if (lyricsModel && lyricsModel.lines && line >= 0 && line < lyricsModel.lines.length) {
        this.startTextScrollAnimation(lyricsModel.lines[line]);
      }
    }
  }

  /**
   * Refreshes the "No Lyrics" display state.
   * @return true if no lyrics are available and refresh was performed
   */
  private refreshNoLyrics(): boolean {
    return this.uninitializedOrNoLyrics();
  }

  /**
   * Performs binary search to find the lyrics line that should be displayed at the given timestamp.
   * @param time Current timestamp in milliseconds
   * @return Index of the lyrics line to display
   */
  private quickSearchLineByTimestamp(time: number): number {
    if (this.uninitializedOrNoLyrics()) {
      return 0;
    }

    let left = 0;
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel) {
      return 0;
    }
    let right = lyricsModel.lines.length - 1;

    while (left <= right) {
      const middle = Math.floor((left + right) / 2);
      const middleTime = lyricsModel.lines[middle].getStartTime();

      if (time < middleTime) {
        right = middle - 1;
      } else {
        if (middle + 1 >= lyricsModel.lines.length ||
          time < lyricsModel.lines[middle + 1].getStartTime()) {
          return middle;
        }
        left = middle + 1;
      }
    }

    return 0;
  }

  /**
   * Resets all internal state variables to their default values.
   */
  private resetInternal(): void {
    this.mCurrentTime = 0;
    this.mCurrentLineTranslateX = 0;
    this.mIndexOfCurrentLine = -1;

    this.lyricsModel = null;
    this.lyricsLines = [];
  }

  /**
   * Force check line wrap based on lyric type
   */
  private forceCheckLineWrap(): void {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines || lyricsModel.lines.length === 0) {
      return;
    }
    // if (lyricsModel.type === LyricType.LRC) {
    // this.enableLineWrap = true                                               ;
    // }
  }

  /**
   * Renders the no lyrics state
   */
  @Builder
  NoLyricsBuilder() {
    Column() {
      Text(this.labelWhenNoLyrics)
        .fontSize(this.currentLineTextSize)
        .fontColor(this.currentLineHighlightedTextColor)
        .textAlign(this.getTextAlign())
    }
    .width('100%')
    .height('100%')
    .justifyContent(this.getRowJustifyContent())
  }

  /**
   * Gets the complete text of a lyrics line
   */
  private getLineText(line: LyricsLineModel): string {
    if (line.tones && line.tones.length > 0) {
      return line.tones.map(tone => tone.word).join('');
    }
    return '';
  }

  /**
   * Gets text alignment based on textGravity property
   */
  private getTextAlign(): TextAlign {
    switch (this.textGravity) {
      case 1:
        return TextAlign.Start; // left
      case 2:
        return TextAlign.End; // right
      default:
        return TextAlign.Center; // center
    }
  }

  /**
   * Gets Row alignment based on textGravity
   */
  private getRowJustifyContent(): FlexAlign {
    switch (this.textGravity) {
      case 1:
        return FlexAlign.Start; // left
      case 2:
        return FlexAlign.End; // right
      default:
        return FlexAlign.Center; // center
    }
  }

  /**
   * Gets Alignment based on textGravity
   */
  private getAlignment(): Alignment {
    switch (this.textGravity) {
      case 1:
        return Alignment.Start; // left
      case 2:
        return Alignment.End; // right
      default:
        return Alignment.Center; // center
    }
  }

  /**
   * Gets the countdown value for prelude indicator
   */
  private getPreludeCountDown(): number {
    if (!this.lyricsModel) {
      return 0;
    }
    return Math.ceil((this.lyricsModel.preludeEndPosition - this.mCurrentTime) / 1000);
  }

  /**
   * Triggers line change animation
   */
  private triggerLineChangeAnimation(fromLine: number, toLine: number): void {
    if (fromLine === toLine) {
      return;
    }

    // 🎯 Disable animation during drag to avoid UI confusion
    if (this.mDraggingInProgress) {
      LogUtils.d(`LyricsView: Skip animation during drag - from ${fromLine} to ${toLine}`);
      return;
    }

    // 🎯 When line jump exceeds 1 line (e.g., after drag setProgress jump), don't execute transition animation
    // Let target line directly change from normal line to current line, avoiding unnatural animation effects
    const lineJump = Math.abs(toLine - fromLine);
    if (lineJump > 1) {
      return;
    }

    this.isAnimating = true;
    this.transitioningFromIndex = fromLine; // Record original current line
    this.newCurrentTransitioning = true; // New current line starts transitioning
    this.styleTransitioning = false; // Style transition starts later

    // 🎯 Fix jitter issue: Use dynamic line height calculation consistent with calculateLineYPosition
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    let currentLineHeight = this.getLineHeight(); // Default value

    if (lyricsModel && lyricsModel.lines && toLine >= 0 && toLine < lyricsModel.lines.length) {
      const currentLine = lyricsModel.lines[toLine];
      currentLineHeight = currentLine ?
        this.getDynamicLineHeight(currentLine, this.currentLineTextSize) :
        this.getLineHeight();
    }

    const centerY = (this.actualViewHeight / 2) - (currentLineHeight / 2);

    // === Original current line transition settings ===
    // Original current line starts from center position
    this.transitioningFromY = centerY;

    // 🎯 Key fix: Use exactly the same logic as calculateLineYPosition to calculate transition line target position
    // Ensure position matches exactly after animation ends, avoiding jumps
    let oldTargetY = centerY;

    if (lyricsModel && lyricsModel.lines && fromLine < toLine) {
      // fromLine will become previous line, use same cumulative calculation logic as calculateLineYPosition
      let totalOffset = 0;
      for (let i = toLine - 1; i >= fromLine; i--) {
        const line = lyricsModel.lines[i];
        if (line) {
          const lineHeight = this.getDynamicLineHeight(line, i === toLine ? this.currentLineTextSize : this.textSize);
          totalOffset += lineHeight;
        }
      }
      oldTargetY = centerY - totalOffset;
    } else {
      // Use original simple calculation as fallback
      oldTargetY = centerY - currentLineHeight;
    }

    // ArkUI V2 optimization: More precise position calculation, avoiding overlap
    // Set starting position
    this.transitioningFromY = centerY; // Transition line starting position: center

    // 🎯 V2 fix: New current line starting position more precise, avoiding overlap with transition line
    const nextLine = lyricsModel?.lines?.[toLine];
    const nextLineOffset = nextLine ?
      this.getDynamicLineHeight(nextLine, this.currentLineTextSize) + this.lineSpacing :
      this.getLineHeight() + this.lineSpacing;
    this.newCurrentFromY = centerY + nextLineOffset; // New current line starting position: ensure no overlap

    // Set target position
    this.transitioningToY = oldTargetY; // Transition line target position: previous line
    this.newCurrentToY = centerY; // New current line target position: center

    this.animationKey = Date.now(); // Update animation key to force re-render

    // ArkUI V2 optimization: Reduce delay, make animation more synchronized
    setTimeout(() => {
      if (this.isAnimating) {
        this.styleTransitioning = true; // Start style transition
      }
    }, 50); // V2 optimization: Reduce delay to 50ms, make animation more synchronized

    // Clear state after animation completes
    setTimeout(() => {
      this.isAnimating = false;
      this.transitioningFromIndex = -1; // Clear transition state
      this.newCurrentTransitioning = false; // Clear new current line transition state
      this.styleTransitioning = false; // Clear style transition state
    }, 400); // V2 optimization: Adjust total duration to 400ms, matching animation duration
  }

  /**
   * Calculates line animation delay (staggered animation)
   */
  private getAnimationDelay(index: number): number {
    if (!this.isAnimating) {
      return 0; // No delay in non-animation state
    }

    const distance = Math.abs(index - this.mIndexOfCurrentLine);
    // Current line has no delay, other lines have increasing delay based on distance
    if (distance === 0) {
      return 0; // Current line starts animation immediately
    } else {
      // Farther distance means larger delay, but use smaller increment to avoid excessive delay
      return Math.min(distance * 15, 80); // Maximum 80ms delay
    }
  }

  /**
   * Calculates Y position of lyrics line (simplified version, using basic spacing)
   */
  private calculateLineYPosition(index: number): number {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines || index < 0 || index >= lyricsModel.lines.length) {
      return 0;
    }

    // 🎯 Important note: Transition line and new current line positions are directly controlled by their respective Builders
    // TransitioningHighlightLineBuilder uses getTransitioningYPosition()
    // NewCurrentLineTransitionBuilder uses getNewCurrentYPosition()
    // This calculateLineYPosition only handles normal line position calculation

    // Unified position calculation logic
    let currentLineIndex = this.mIndexOfCurrentLine;
    let additionalOffset = 0;

    // Get actual height of current line for center calculation
    const currentLine = lyricsModel.lines[currentLineIndex];
    const currentLineHeight = currentLine ?
      this.getDynamicLineHeight(currentLine, this.currentLineTextSize) :
      this.getLineHeight();
    const centerY = (this.actualViewHeight / 2) - (currentLineHeight / 2);

    if (this.mDraggingInProgress && this.originalCurrentLineIndex >= 0) {
      // 🎯 During drag, implement scrolling list effect: calculate virtual current line, but don't use animation transition
      // This allows showing different lyrics content while avoiding UI confusion during drag
      const virtualCurrentLineIndex = this.originalCurrentLineIndex - this.dragLineOffset;
      const clampedVirtualIndex = Math.max(0, Math.min(virtualCurrentLineIndex,
        (lyricsModel?.lines?.length || 1) - 1));

      currentLineIndex = clampedVirtualIndex;
      additionalOffset = 0; // Use virtual current line for re-layout, no additional offset needed
    }

    // Dynamic position calculation: accumulate actual height of each line
    let yPosition = centerY;

    if (index === currentLineIndex) {
      // Current line: at center position
      yPosition = centerY + additionalOffset;

    } else if (index < currentLineIndex) {
      // Lines above: accumulate upward offset
      let totalOffset = 0;
      for (let i = currentLineIndex - 1; i >= index; i--) {
        const line = lyricsModel.lines[i];
        if (line) {
          const lineHeight = this.getDynamicLineHeight(line, this.textSize);
          totalOffset += lineHeight;
        }
      }
      yPosition = centerY - totalOffset + additionalOffset;
    } else {
      // Lines below: accumulate downward offset
      let totalOffset = currentLineHeight; // Start from bottom of current line
      for (let i = currentLineIndex + 1; i <= index; i++) {
        const line = lyricsModel.lines[i];
        if (line) {
          const lineHeight = this.getDynamicLineHeight(line, this.textSize);
          if (i === index) {
            // Target line: don't add its own height, because yPosition is top position
            break;
          }
          totalOffset += lineHeight;
        }
      }
      yPosition = centerY + totalOffset + additionalOffset;
    }

    // Boundary check logic
    const targetLine = lyricsModel.lines[index];
    const targetLineHeight = targetLine ?
      this.getDynamicLineHeight(targetLine,
        index === this.mIndexOfCurrentLine ? this.currentLineTextSize : this.textSize) :
      this.getLineHeight();

    // 🎯 Fix boundary limits: set different boundary ranges for different types of lines
    let minY: number;
    let maxY: number;

    if (index < currentLineIndex) {
      // Sung lines (above): allow larger upward expansion range
      minY = -this.actualViewHeight * 2; // Allow upward expansion to 2x screen height
      maxY = centerY; // Lowest not exceeding center position
    } else if (index > currentLineIndex) {
      // Unsung lines (below): allow larger downward expansion range
      minY = centerY; // Highest not exceeding center position
      maxY = this.actualViewHeight * 3; // Allow downward expansion to 3x screen height
    } else {
      // Current line: use original boundary limits
      minY = -targetLineHeight * 0.5;
      maxY = this.actualViewHeight + targetLineHeight * 0.5;
    }

    // 🎯 Smart boundary control during drag:
    // - Original current line (may move from center to top or bottom) allows complete movement out of view
    // - Other lines still need boundary limits to prevent interface confusion
    if (this.mDraggingInProgress) {
      if (index === this.originalCurrentLineIndex) {
        // Original current line allows movement out of view, achieving true scrolling effect
        return yPosition;
      } else {
        // Other lines still subject to boundary limits, preventing display confusion
        const clampedY = Math.max(minY, Math.min(maxY, yPosition));
        return clampedY;
      }
    }

    // Standard boundary check for non-drag state
    const clampedY = Math.max(minY, Math.min(maxY, yPosition));

    return clampedY;
  }

  /**
   * Calculates lyrics line height
   */
  private getLineHeight(): number {
    return this.currentLineTextSize + this.lineSpacing;
  }

  /**
   * Dynamically calculates actual display height of specific lyrics line
   * Only increases height when text really needs multiple lines
   */
  private getDynamicLineHeight(line: LyricsLineModel, fontSize: number): number {
    if (!this.shouldEnableLineWrap() || !line) {
      return fontSize + this.lineSpacing;
    }

    const text = this.getLineText(line);
    if (!text || text.length === 0) {
      return fontSize + this.lineSpacing;
    }

    // Estimate text width
    const textWidth = this.measureTextWidth(text, fontSize);
    const availableWidth = this.actualViewWidth;

    if (availableWidth <= 0 || textWidth <= availableWidth) {
      // Can be displayed in one line, use standard line height
      return fontSize + this.lineSpacing;
    } else {
      // Needs multiple lines, calculate actual required line count
      const estimatedLines = Math.ceil(textWidth / availableWidth);
      const actualLines = Math.min(estimatedLines, 3); // Maximum 3 lines
      return (fontSize * actualLines) + this.lineSpacing;
    }
  }

  /**
   * Splits lyrics line into multiple physical lines based on display width
   */
  private splitLineIntoDisplayLines(line: LyricsLineModel, fontSize: number): DisplayLine[] {
    if (!this.shouldEnableLineWrap() || !line || !line.tones || line.tones.length === 0) {
      return [{
        text: this.getLineText(line),
        tones: line.tones || [],
        startTime: line.getStartTime(),
        endTime: line.getEndTime()
      }];
    }

    const availableWidth = this.actualViewWidth;
    if (availableWidth <= 0) {
      return [{
        text: this.getLineText(line),
        tones: line.tones || [],
        startTime: line.getStartTime(),
        endTime: line.getEndTime()
      }];
    }

    const result: DisplayLine[] = [];
    let currentLineText = '';
    let currentLineTones: Tone[] = [];
    let currentLineStartTime = line.getStartTime();
    let currentLineEndTime = line.getStartTime();

    for (let i = 0; i < line.tones.length; i++) {
      const tone = line.tones[i];
      const testText = currentLineText + tone.word;
      const testWidth = this.measureTextWidth(testText, fontSize);

      if (testWidth <= availableWidth || currentLineText === '') {
        // Current line can still accommodate this character, or this is the first character
        currentLineText += tone.word;
        currentLineTones.push(tone);
        currentLineEndTime = tone.end;
      } else {
        // Current line is full, start new line
        if (currentLineText !== '') {
          result.push({
            text: currentLineText,
            tones: [...currentLineTones],
            startTime: currentLineStartTime,
            endTime: currentLineEndTime
          });
        }

        // Start new line
        currentLineText = tone.word;
        currentLineTones = [tone];
        currentLineStartTime = tone.begin;
        currentLineEndTime = tone.end;
      }
    }

    // Add last line
    if (currentLineText !== '') {
      result.push({
        text: currentLineText,
        tones: [...currentLineTones],
        startTime: currentLineStartTime,
        endTime: currentLineEndTime
      });
    }

    return result.length > 0 ? result : [{
      text: this.getLineText(line),
      tones: line.tones || [],
      startTime: line.getStartTime(),
      endTime: line.getEndTime()
    }];
  }

  /**
   * Calculate highlight progress for specific physical line in multi-line lyrics
   */
  private calculateDisplayLineProgress(displayLine: DisplayLine, currentTime: number): number {
    if (!displayLine.tones || displayLine.tones.length === 0) {
      return 0;
    }

    if (currentTime < displayLine.startTime) {
      return 0;
    }

    if (currentTime >= displayLine.endTime) {
      return 1;
    }

    // Within this physical line's time range, calculate character-level progress
    let highlightedChars = 0;
    for (const tone of displayLine.tones) {
      if (currentTime >= tone.end) {
        highlightedChars += tone.word.length;
      } else if (currentTime >= tone.begin) {
        // Partially highlight current character
        const charProgress = (currentTime - tone.begin) / (tone.end - tone.begin);
        highlightedChars += tone.word.length * charProgress;
        break;
      } else {
        break;
      }
    }

    return Math.min(highlightedChars / displayLine.text.length, 1);
  }

  /**
   * Improved text width estimation method
   * More accurate estimation based on character type, with safety margin
   */
  private measureTextWidth(text: string, fontSize: number): number {
    let estimatedWidth = 0;
    let isChinese = false;

    for (let i = 0; i < text.length; i++) {
      const char = text.charAt(i);
      if (/[\u4e00-\u9fa5]/.test(char)) {
        // Chinese character, width approximately equals font size
        estimatedWidth += fontSize;
        isChinese = true;
      } else if (/[a-zA-Z0-9]/.test(char)) {
        // English letters and numbers, width approximately 0.6 times font size (slightly increased for accuracy)
        estimatedWidth += fontSize * 0.6;
      } else {
        // Punctuation and other characters
        if (isChinese) {
          estimatedWidth += fontSize * 0.8; // Chinese punctuation
        } else {
          estimatedWidth += fontSize * 0.4; // English punctuation
        }
      }
    }

    // Add extra safety margin for English text, as character spacing and font rendering may vary
    if (!isChinese && text.length > 0) {
      estimatedWidth *= 1.1; // Add 10% safety margin
    }

    return estimatedWidth;
  }

  /**
   * Detect if text needs scrolling (exceeds container width)
   */
  private isTextOverflowing(text: string, fontSize: number): boolean {
    const actualTextWidth = this.measureTextWidth(text, fontSize);
    // Consider left and right margins, actual available width needs to subtract margins
    const availableWidth = this.actualViewWidth - (this.linePaddingLeftRight * 2);
    const isOverflowing = actualTextWidth > availableWidth;

    // For testing, lower scroll trigger threshold
    if (!this.shouldEnableLineWrap()) {
      // For non-wrap mode, consider scrolling needed if text length exceeds 5 characters (for testing convenience)
      if (text.length > 5) {
        return true;
      }
    }

    return isOverflowing;
  }

  /**
   * Calculate text scroll offset
   * Keep the currently playing part always in the center of the view
   */
  private calculateTextScrollOffset(line: LyricsLineModel, progress: number): number {
    const text = this.getLineText(line);
    const fontSize = this.currentLineTextSize; // Ensure using current line font size
    const actualTextWidth = this.measureTextWidth(text, fontSize); // Use precise measurement
    // Consider left and right margins, actual available width needs to subtract margins
    const containerWidth = this.actualViewWidth - (this.linePaddingLeftRight * 2);

    // For testing, allow scrolling even if text is not very long
    if (actualTextWidth <= containerWidth * 0.8) { // Lower threshold, start scrolling at 80%
      return 0; // Text not long enough, no scrolling needed
    }

    // Calculate pixel offset of current play position
    const currentPlayPosition = actualTextWidth * progress;
    const halfContainerWidth = containerWidth / 2;

    // Keep current play position in container center
    let targetOffset = currentPlayPosition - halfContainerWidth;

    // Limit scroll range: cannot scroll to negative value, also cannot exceed maximum scroll distance
    const maxScrollOffset = actualTextWidth - containerWidth;
    targetOffset = Math.max(0, Math.min(targetOffset, maxScrollOffset));

    return targetOffset;
  }

  /**
   * Start text scroll animation
   */
  private startTextScrollAnimation(line: LyricsLineModel): void {
    const text = this.getLineText(line);

    // Reset scroll offset, prepare for new line
    this.currentLineScrollOffset = 0;

    if (this.shouldEnableLineWrap()) {
      return; // No scrolling needed when line wrap is enabled
    }

    if (!this.isTextOverflowing(text, this.currentLineTextSize)) {
      return; // No scrolling needed when text is not overflowing
    }

    this.isTextScrolling = true;

    // Clear previous timer
    if (this.textScrollTimer !== -1) {
      clearInterval(this.textScrollTimer);
    }

    // Start scroll timer, update every 50ms for smoother effect
    this.textScrollTimer = setInterval(() => {
      if (!this.isTextScrolling) {
        return;
      }

      const progress = this.calculateLineProgress(line);
      const targetOffset = this.calculateTextScrollOffset(line, progress);

      // Use textScroller.scrollTo to implement real scrolling
      if (Math.abs(this.currentLineScrollOffset - targetOffset) > 0.5) {
        const oldOffset = this.currentLineScrollOffset;
        this.currentLineScrollOffset = targetOffset;

        // Use Scroller for scrolling
        this.textScroller.scrollTo({
          xOffset: targetOffset,
          yOffset: 0,
          animation: {
            duration: 100,
            curve: Curve.EaseOut
          }
        });
      }
    }, 50);
  }

  /**
   * Stop text scroll animation
   */
  private stopTextScrollAnimation(): void {
    if (this.textScrollTimer !== -1) {
      clearInterval(this.textScrollTimer);
      this.textScrollTimer = -1;
    }
    this.isTextScrolling = false;
    this.mCurrentLineTranslateX = 0; // Reset horizontal scroll offset
    // Reset scroll position to start
    this.textScroller.scrollTo({
      xOffset: 0,
      yOffset: 0
    });
  }

  /**
   * Check if horizontal scrolling should be applied (reference Android version implementation)
   * Start scrolling when both highlighted part and remaining part are greater than half of view width
   */
  private checkIfXTranslationShouldApply(line: LyricsLineModel): void {
    if (this.shouldEnableLineWrap()) {
      this.mCurrentLineTranslateX = 0; // No horizontal scrolling needed in wrap mode
      this.updateScrollPosition(0);
      return;
    }

    const text = this.getLineText(line);
    const fontSize = this.currentLineTextSize;
    const textWidth = text.length * fontSize * 0.6; // Estimate total text width
    const viewWidth = this.actualViewWidth;
    const halfViewWidth = viewWidth / 2;

    // Check if text is overlong
    if (!this.isLyricsLineOverlong(textWidth)) {
      this.mCurrentLineTranslateX = 0;
      this.updateScrollPosition(0);
      return;
    }

    // Calculate current highlight area width
    const progress = this.calculateLineProgress(line);
    const currentHighlightWidth = textWidth * progress;

    // Android version scroll logic:
    // 1. Highlighted part greater than half of view width
    // 2. Remaining part also greater than half of view width
    if (currentHighlightWidth > halfViewWidth &&
      (textWidth - currentHighlightWidth) > halfViewWidth) {

      // Calculate target scroll position: keep current play position in screen center
      const targetScrollX = currentHighlightWidth - halfViewWidth;

      // Limit scroll range
      const maxScroll = textWidth - viewWidth;
      this.mCurrentLineTranslateX = Math.max(0, Math.min(maxScroll, targetScrollX));

      // Apply scrolling
      this.updateScrollPosition(this.mCurrentLineTranslateX);

    } else {
      this.mCurrentLineTranslateX = 0;
      this.updateScrollPosition(0);
    }
  }

  /**
   * Update scroll position
   */
  private updateScrollPosition(scrollX: number): void {
    if (this.textScroller) {
      this.textScroller.scrollTo({
        xOffset: scrollX,
        yOffset: 0
      });
    }
  }

  /**
   * Check if lyrics line is overlong (needs horizontal scrolling)
   */
  private isLyricsLineOverlong(textWidth: number): boolean {
    return textWidth > this.actualViewWidth;
  }

  /**
   * Calculate maximum number of visible lines (half above and half below)
   */
  private getMaxVisibleLines(): number {
    const lineHeight = this.getLineHeight();
    const availableHeight = this.actualViewHeight;
    return Math.floor(availableHeight / lineHeight);
  }

  /**
   * Determine if lyrics line is within visible range
   */
  private isLineVisible(index: number): boolean {
    // Calculate actual Y position of this line
    const lineY = this.calculateLineYPosition(index);
    const lineHeight = this.getLineHeight();

    // Determine if line is within view range (including partially visible)
    const lineTop = lineY;
    const lineBottom = lineY + lineHeight;
    const viewTop = -lineHeight * 0.5; // Allow slightly exceeding top boundary
    const viewBottom = this.actualViewHeight + lineHeight * 0.5; // Allow slightly exceeding bottom boundary

    // If any part of line is within extended view range, consider it visible
    const isVisible = lineBottom > viewTop && lineTop < viewBottom;

    return isVisible;
  }

  /**
   * Determine if a line should be rendered (based on enablePreviousLines and enableUpcomingLines switches)
   */
  private shouldRenderLine(index: number): boolean {
    // Determine current reference line index
    let currentIndex = this.mIndexOfCurrentLine;

    if (this.mDraggingInProgress && this.originalCurrentLineIndex >= 0) {
      // 🎯 Use virtual current line index during drag to implement scrolling list effect
      const lyricsModel = this.mLyricMachine?.getLyricsModel();
      const virtualCurrentLineIndex = this.originalCurrentLineIndex - this.dragLineOffset;
      currentIndex = Math.max(0, Math.min(virtualCurrentLineIndex,
        (lyricsModel?.lines?.length || 1) - 1));
    }

    // Current line always rendered
    if (index === currentIndex) {
      return true;
    }

    // Check if it's a previous line
    if (index < currentIndex) {
      return this.enablePreviousLines;
    }

    // Check if it's a future line
    if (index > currentIndex) {
      return this.enableUpcomingLines;
    }

    return true;
  }

  /**
   * Count and log current number of visible lines (for debugging)
   */
  private logVisibleLinesCount(): void {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines) {
      return;
    }

    const visibleLines: number[] = [];
    const renderedLines: number[] = [];

    for (let i = 0; i < lyricsModel.lines.length; i++) {
      if (this.shouldRenderLine(i)) {
        renderedLines.push(i);

        if (this.isLineVisible(i)) {
          visibleLines.push(i);
        }
      }
    }
  }

  /**
   * Progressive highlight lyrics line Builder - implements karaoke-style smooth highlight effect
   */
  @Builder
  EnhancedLyricsLineBuilder(line: LyricsLineModel, index: number) {
    if (this.isLineVisible(index)) {
      // Render all lines, but use opacity to control visibility, ensuring animation continuity
      if (index === this.mIndexOfCurrentLine && this.newCurrentTransitioning) {
        // New current line is transitioning: use new current line transition effect
        this.NewCurrentLineTransitionBuilder(line, index)
      } else if (index === this.mIndexOfCurrentLine) {
        // Current line: use progressive highlight effect
        this.ProgressiveHighlightLineBuilder(line, index)
      } else if (index === this.transitioningFromIndex && this.isAnimating) {
        this.TransitioningHighlightLineBuilder(line, index)
      } else {
        this.NormalLineBuilder(line, index)
      }
    }
  }

  /**
   * Check if line wrap should be enabled (LRC format enabled by default)
   */
  private shouldEnableLineWrap(): boolean {
    // If enableLineWrap is explicitly set, use the set value
    if (this.enableLineWrap !== undefined) {
      return this.enableLineWrap;
    }

    // Check if it's LRC format (by checking lyrics model type)
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (lyricsModel && lyricsModel.type === LyricType.LRC) {
      return true; // LRC format enables line wrap by default
    }

    return false; // Other formats don't enable line wrap by default
  }

  /**
   * Check if current lyrics is LRC format
   * LRC format should highlight entire line, not character-by-character coloring
   */
  private isLrcType(): boolean {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    return lyricsModel !== null && lyricsModel !== undefined && lyricsModel.type === LyricType.LRC;
  }

  /**
   * Progressive highlight line Builder
   */
  @Builder
  ProgressiveHighlightLineBuilder(line: LyricsLineModel, index: number) {
    if (this.shouldEnableLineWrap()) {
      // Enable wrap mode
      this.WrappedHighlightLineBuilder(line, index);
    } else {
      // Scroll mode
      this.ScrollingHighlightLineBuilder(line, index);
    }
  }

  /**
   * Wrapped highlight line Builder
   */
  @Builder
  WrappedHighlightLineBuilder(line: LyricsLineModel, index: number) {
    if (this.isLrcType()) {
      // LRC format: entire line highlight, no character-by-character coloring
      Column() {
        ForEach(this.splitLineIntoDisplayLines(line, this.currentLineTextSize),
          (displayLine: DisplayLine, displayIndex: number) => {
            Row() {
              Text(displayLine.text)
                .fontSize(this.currentLineTextSize)
                .fontColor(this.currentLineHighlightedTextColor) // Directly use highlight color
                .fontWeight(FontWeight.Bold)
                .textAlign(this.getTextAlign())
                .width('100%')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.None })
            }
            .width('100%')
            .justifyContent(this.getRowJustifyContent())
            .height(this.currentLineTextSize)
          }, (displayLine: DisplayLine, displayIndex: number) => `${index}_lrc_${displayIndex}`)
      }
      .width(this.actualViewWidth)
      .height(this.getDynamicLineHeight(line, this.currentLineTextSize))
      .position({ x: this.linePaddingLeftRight, y: this.calculateLineYPosition(index) })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getLineScale(index),
        y: this.getLineScale(index)
      })
      .animation({
        duration: 400,
        delay: this.getAnimationDelay(index),
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
    } else {
      // XML/KRC format: character-by-character coloring
      Stack() {
        // Background text (normal color)
        Column() {
          ForEach(this.splitLineIntoDisplayLines(line, this.currentLineTextSize),
            (displayLine: DisplayLine, displayIndex: number) => {
              Row() {
                Text(displayLine.text)
                  .fontSize(this.currentLineTextSize)
                  .fontColor(this.currentLineTextColor)
                  .fontWeight(FontWeight.Bold)
                  .textAlign(this.getTextAlign())
                  .width('100%')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.None })
              }
              .width('100%')
              .justifyContent(this.getRowJustifyContent())
              .height(this.currentLineTextSize)
            }, (displayLine: DisplayLine, displayIndex: number) => `${index}_bg_${displayIndex}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        // Highlight text (progressive display line by line)
        Column() {
          ForEach(this.splitLineIntoDisplayLines(line, this.currentLineTextSize),
            (displayLine: DisplayLine, displayIndex: number) => {
              Row() {
                Text(displayLine.text)
                  .fontSize(this.currentLineTextSize)
                  .fontColor(this.currentLineHighlightedTextColor)
                  .fontWeight(FontWeight.Bold)
                  .textAlign(this.getTextAlign())
                  .width('100%')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.None })
              }
              .width('100%')
              .justifyContent(this.getRowJustifyContent())
              .height(this.currentLineTextSize)
              .clip(true)
              .clipShape(new Rect({
                width: `${this.calculateDisplayLineProgress(displayLine, this.mCurrentTime) * 100}%`,
                height: '100%'
              }))
              .animation({
                duration: 50,
                curve: Curve.Linear,
                iterations: 1,
                playMode: PlayMode.Normal
              })
            }, (displayLine: DisplayLine, displayIndex: number) => `${index}_fg_${displayIndex}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width(this.actualViewWidth)
      .height(this.getDynamicLineHeight(line, this.currentLineTextSize))
      .position({ x: this.linePaddingLeftRight, y: this.calculateLineYPosition(index) })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getLineScale(index),
        y: this.getLineScale(index)
      })
      .animation({
        duration: 400,
        delay: this.getAnimationDelay(index),
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
    }
  }

  /**
   * Scrolling highlight line Builder (single line display, supports horizontal scroll animation)
   */
  @Builder
  ScrollingHighlightLineBuilder(line: LyricsLineModel, index: number) {
    if (this.isLrcType()) {
      // LRC format: entire line highlight, no character-by-character coloring
      Scroll(this.textScroller) {
        Text(this.getLineText(line))
          .fontSize(this.currentLineTextSize)
          .fontColor(this.currentLineHighlightedTextColor) // Directly use highlight color
          .fontWeight(FontWeight.Bold)
          .textAlign(this.getTextAlign())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.None })
          .width('auto')
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width(this.actualViewWidth)
      .height(this.getLineHeight())
      .position({ x: this.linePaddingLeftRight, y: this.calculateLineYPosition(index) })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getLineScale(index),
        y: this.getLineScale(index)
      })
      .animation({
        duration: 400,
        delay: this.getAnimationDelay(index),
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
    } else {
      // XML/KRC format: character-by-character coloring
      Scroll(this.textScroller) {
        Stack() {
          // Background text (normal color, single line display)
          Text(this.getLineText(line))
            .fontSize(this.currentLineTextSize)
            .fontColor(this.currentLineTextColor)
            .fontWeight(FontWeight.Bold)
            .textAlign(this.getTextAlign())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.None })
            .width('auto')
            .onAppear(() => {
            })

          // Highlight text (use clip for progressive effect)
          Text(this.getLineText(line))
            .fontSize(this.currentLineTextSize)
            .fontColor(this.currentLineHighlightedTextColor)
            .fontWeight(FontWeight.Bold)
            .textAlign(this.getTextAlign())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.None })
            .width('auto')
            .clip(true)
            .clipShape(new Rect({
              width: `${this.calculateLineProgress(line) * 100}%`,
              height: '100%'
            }))
            .animation({
              duration: 50,
              curve: Curve.Linear,
              iterations: 1,
              playMode: PlayMode.Normal
            })
        }
        .alignContent(this.getAlignment())
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width(this.actualViewWidth)
      .height(this.getLineHeight())
      .position({ x: this.linePaddingLeftRight, y: this.calculateLineYPosition(index) })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getLineScale(index),
        y: this.getLineScale(index)
      })
      .animation({
        duration: 400,
        delay: this.getAnimationDelay(index),
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
    }
  }

  /**
   * Transitioning normal line Builder - handles original current line moving from current position to target position with normal line style
   */
  @Builder
  TransitioningHighlightLineBuilder(line: LyricsLineModel, index: number) {
    // Decide display method based on enableLineWrap
    if (this.shouldEnableLineWrap()) {
      // Wrap mode: supports multi-line display
      Row() {
        Text(this.getLineText(line))
          .fontSize(this.getTransitioningHighlightLineTextSize()) // Keep current line font size, size change through scaling
          .fontColor(this.getTransitioningHighlightLineTextColor()) // Use dynamic color
          .fontWeight(this.getTransitioningHighlightLineFontWeight()) // Keep current line font weight
          .textAlign(this.getTextAlign())
          .width('100%')
          .maxLines(3) // Maximum 3 lines
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(this.actualViewWidth)
      .height(this.getDynamicLineHeight(line, this.currentLineTextSize))
      .justifyContent(this.getRowJustifyContent())
      .alignItems(VerticalAlign.Center)
      .position({
        x: this.linePaddingLeftRight,
        y: this.getTransitioningYPosition() // Use animation interpolation position
      })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getTransitioningScale(index),
        y: this.getTransitioningScale(index)
      })
      .animation({
        duration: 350, // ArkUI V2 optimization: slightly extend animation time for smoother transition
        curve: Curve.EaseOut, // Use EaseOut for more natural animation ending
        iterations: 1,
        playMode: PlayMode.Normal,
        delay: 0 // Ensure no delay, start immediately
      })
    } else {
      // No wrap mode: use Scroll component to avoid flashing when font changes
      Scroll() {
        Stack() {
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningHighlightLineTextSize()) // Keep current line font size, size change through scaling
            .fontColor(this.getTransitioningHighlightLineTextColor()) // Use dynamic color
            .fontWeight(this.getTransitioningHighlightLineFontWeight()) // Keep current line font weight
            .textAlign(this.getTextAlign())
            .maxLines(1) // Single line display
            .textOverflow({ overflow: TextOverflow.None }) // No ellipsis
            .width('auto') // Let text natural width
        }
        .alignContent(this.getAlignment())
      }
      .scrollable(ScrollDirection.Horizontal) // Horizontal scroll
      .scrollBar(BarState.Off) // Hide scrollbar
      .width(this.actualViewWidth)
      .height(this.getLineHeight())
      .position({
        x: this.linePaddingLeftRight,
        y: this.getTransitioningYPosition() // Use animation interpolation position
      })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getTransitioningScale(index),
        y: this.getTransitioningScale(index),
      })
      .animation({
        duration: 350, // ArkUI V2 optimization: slightly extend animation time for smoother transition
        curve: Curve.EaseOut, // Use EaseOut for more natural animation ending
        iterations: 1,
        playMode: PlayMode.Normal,
        delay: 0 // Ensure no delay, start immediately
      })
    }
  }

  /**
   * New current line transition Builder - handles moving from next line position to center and becoming highlight style
   */
  @Builder
  NewCurrentLineTransitionBuilder(line: LyricsLineModel, index: number) {
    // Decide display method based on enableLineWrap
    if (this.shouldEnableLineWrap()) {
      if (this.isLrcType()) {
        // LRC format: wrap mode, directly display highlight color, no Stack
        Row() {
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize())
            .fontColor(this.currentLineHighlightedTextColor) // Directly use highlight color
            .fontWeight(this.getTransitioningFontWeight())
            .textAlign(this.getTextAlign())
            .width('100%')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .animation({
              duration: 300,
              curve: Curve.EaseInOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })
        }
        .width(this.actualViewWidth)
        .height(this.getDynamicLineHeight(line, this.currentLineTextSize))
        .justifyContent(this.getRowJustifyContent())
        .position({
          x: this.linePaddingLeftRight,
          y: this.getNewCurrentYPosition()
        })
        .opacity(this.getLineOpacity(index))
        .scale({
          x: this.getNewCurrentScale(),
          y: this.getNewCurrentScale()
        })
        .animation({
          duration: 400,
          delay: this.getAnimationDelay(index),
          curve: Curve.EaseInOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
      } else {
        // XML/KRC format: wrap mode, use Stack layout for character-by-character coloring
        Stack() {
          // Background text (smooth transition style)
          Row() {
            Text(this.getLineText(line))
              .fontSize(this.getTransitioningFontSize())
              .fontColor(this.getTransitioningTextColor())
              .fontWeight(this.getTransitioningFontWeight())
              .textAlign(this.getTextAlign())
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .animation({
                duration: 300,
                curve: Curve.EaseInOut,
                iterations: 1,
                playMode: PlayMode.Normal
              })
          }
          .width('100%')
          .justifyContent(this.getRowJustifyContent())

          // Highlight text (progressive display)
          Row() {
            Text(this.getLineText(line))
              .fontSize(this.getTransitioningFontSize())
              .fontColor(this.currentLineHighlightedTextColor)
              .fontWeight(this.getTransitioningFontWeight())
              .textAlign(this.getTextAlign())
              .width('100%')
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .animation({
                duration: 300,
                curve: Curve.EaseInOut,
                iterations: 1,
                playMode: PlayMode.Normal
              })
          }
          .width('100%')
          .justifyContent(this.getRowJustifyContent())
          .clip(true)
          .clipShape(new Rect({
            width: `${this.calculateLineProgress(line) * 100}%`,
            height: '100%'
          }))
          .opacity(this.styleTransitioning ? 1.0 : 0.0)
          .animation({
            duration: 300,
            curve: Curve.EaseInOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
        }
        .width(this.actualViewWidth)
        .height(this.getDynamicLineHeight(line, this.currentLineTextSize))
        .alignContent(this.getAlignment())
        .position({
          x: this.linePaddingLeftRight,
          y: this.getNewCurrentYPosition()
        })
        .opacity(this.getLineOpacity(index))
        .scale({
          x: this.getNewCurrentScale(),
          y: this.getNewCurrentScale()
        })
        .animation({
          duration: 400,
          delay: this.getAnimationDelay(index),
          curve: Curve.EaseInOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
      }
    } else {
      // No wrap mode: use Scroll component to avoid flashing
      if (this.isLrcType()) {
        // LRC format: no wrap mode, directly display highlight color
        Scroll(this.textScroller) {
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize())
            .fontColor(this.currentLineHighlightedTextColor) // Directly use highlight color
            .fontWeight(this.getTransitioningFontWeight())
            .textAlign(this.getTextAlign())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.None })
            .width('auto')
            .animation({
              duration: 300,
              curve: Curve.EaseInOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width(this.actualViewWidth)
        .height(this.getLineHeight())
        .position({
          x: this.linePaddingLeftRight,
          y: this.getNewCurrentYPosition()
        })
        .opacity(this.getLineOpacity(index))
        .scale({
          x: this.getNewCurrentScale(),
          y: this.getNewCurrentScale()
        })
        .animation({
          duration: 400,
          delay: this.getAnimationDelay(index),
          curve: Curve.EaseInOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
      } else {
        // XML/KRC format: no wrap mode, use Stack for character-by-character coloring
        Scroll(this.textScroller) {
          Stack() {
            // Background text (single line display)
            Text(this.getLineText(line))
              .fontSize(this.getTransitioningFontSize())
              .fontColor(this.getTransitioningTextColor())
              .fontWeight(this.getTransitioningFontWeight())
              .textAlign(this.getTextAlign())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.None })
              .width('auto')
              .animation({
                duration: 300,
                curve: Curve.EaseInOut,
                iterations: 1,
                playMode: PlayMode.Normal
              })

            // Highlight text (progressive display, single line)
            Text(this.getLineText(line))
              .fontSize(this.getTransitioningFontSize())
              .fontColor(this.currentLineHighlightedTextColor)
              .fontWeight(this.getTransitioningFontWeight())
              .textAlign(this.getTextAlign())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.None })
              .width('auto')
              .clip(true)
              .clipShape(new Rect({
                width: `${this.calculateLineProgress(line) * 100}%`,
                height: '100%'
              }))
              .opacity(this.styleTransitioning ? 1.0 : 0.0)
              .animation({
                duration: 300,
                curve: Curve.EaseInOut,
                iterations: 1,
                playMode: PlayMode.Normal
              })
          }
          .alignContent(this.getAlignment())
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width(this.actualViewWidth)
        .height(this.getLineHeight())
        .position({
          x: this.linePaddingLeftRight,
          y: this.getNewCurrentYPosition()
        })
        .opacity(this.getLineOpacity(index))
        .scale({
          x: this.getNewCurrentScale(),
          y: this.getNewCurrentScale()
        })
        .animation({
          duration: 400,
          delay: this.getAnimationDelay(index),
          curve: Curve.EaseInOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
      }
    }
  }

  /**
   * Normal line Builder
   */
  @Builder
  NormalLineBuilder(line: LyricsLineModel, index: number) {
    if (this.shouldEnableLineWrap()) {
      // Wrap mode: normal line supports line wrapping
      this.WrappedNormalLineBuilder(line, index);
    } else {
      // No wrap mode: normal line single line display, no ellipsis
      this.SingleLineNormalBuilder(line, index);
    }
  }

  /**
   * Wrapped normal line Builder
   */
  @Builder
  WrappedNormalLineBuilder(line: LyricsLineModel, index: number) {
    Row() {
      Text(this.getLineText(line))
        .fontSize(this.textSize)
        .fontColor(this.getNormalLineColor(index))
        .fontWeight(FontWeight.Normal)
        .textAlign(this.getTextAlign())
        .width('100%')
        .maxLines(3) // Maximum 3 lines
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(this.actualViewWidth)
    .height(this.getDynamicLineHeight(line, this.textSize))
    .justifyContent(this.getRowJustifyContent())
    .alignItems(VerticalAlign.Center)
    .position({ x: this.linePaddingLeftRight, y: this.calculateLineYPosition(index) })
    .opacity(this.getLineOpacity(index))
    .scale({
      x: this.getLineScale(index),
      y: this.getLineScale(index)
    })
    .animation({
      duration: 400, // Unified animation duration, consistent with highlight line
      delay: this.getAnimationDelay(index), // Staggered animation delay
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * Single line normal Builder (no wrap, no ellipsis)
   */
  @Builder
  SingleLineNormalBuilder(line: LyricsLineModel, index: number) {
    Stack() {
      Text(this.getLineText(line))
        .fontSize(this.textSize)
        .fontColor(this.getNormalLineColor(index))
        .fontWeight(FontWeight.Normal)
        .textAlign(this.getTextAlign())
        .maxLines(1) // Single line display
        .textOverflow({ overflow: TextOverflow.None }) // No ellipsis
        .width('auto') // Let text natural width
    }
    .width(this.actualViewWidth)
    .height(this.getLineHeight())
    .alignContent(this.getAlignment())
    .clip(true) // Clip exceeding part, no ellipsis
    .position({ x: this.linePaddingLeftRight, y: this.calculateLineYPosition(index) })
    .opacity(this.getLineOpacity(index))
    .scale({
      x: this.getLineScale(index),
      y: this.getLineScale(index)
    })
    .animation({
      duration: 400, // Unified animation duration, consistent with highlight line
      delay: this.getAnimationDelay(index), // Staggered animation delay
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * Calculate current line's highlight progress (between 0-1)
   * Precise progress calculation based on time, avoiding Chinese character calculation being too fast
   */
  private calculateLineProgress(line: LyricsLineModel): number {
    if (!line.tones || line.tones.length === 0) {
      return 0;
    }

    const lineStartTime = line.getStartTime();
    const lineEndTime = line.getEndTime();

    if (this.mCurrentTime < lineStartTime) {
      return 0;
    } else if (this.mCurrentTime >= lineEndTime) {
      return 1;
    }

    // Time-based progress calculation, more accurately reflects playback progress
    const lineDuration = lineEndTime - lineStartTime;
    const playedTime = this.mCurrentTime - lineStartTime;

    if (lineDuration <= 0) {
      return 1;
    }

    return Math.min(1, playedTime / lineDuration);
  }

  /**
   * Get current line character color (implement highlight logic)
   */
  private getCurrentLineCharColor(tone: Tone): string {
    // Current line highlight logic: all sung parts are highlighted
    if (this.mCurrentTime >= tone.begin) {
      return this.currentLineHighlightedTextColor; // Highlight color
    } else {
      return this.currentLineTextColor; // Current line normal color
    }
  }

  /**
   * Get normal line color
   */
  private getNormalLineColor(index: number): string {
    if (index < this.mIndexOfCurrentLine) {
      return this.previousLineTextColor; // Already sung lines
    } else {
      return this.upcomingLineTextColor; // Unsung lines
    }
  }

  /**
   * Calculate line opacity (based on visibility and distance from current line)
   */
  private getLineOpacity(index: number): number {
    // First check if this line should be rendered
    if (!this.shouldRenderLine(index)) {
      // 🎯 Key log: monitor original current line opacity changes
      if (Math.abs(Date.now() - this.animationKey) < 3000 && index === this.mIndexOfCurrentLine - 1) {
        LogUtils.d(`LyricsView: 👻 Line ${index} opacity set to 0.0 - shouldRenderLine returned false`);
      }
      return 0.0; // If switch disabled this line, completely transparent
    }

    const isVisible = this.isLineVisible(index);

    // 🎯 Remove fallback mechanism during drag, allow all lines (including original current line) to hide normally by position
    // This way current line can move out of view top normally when scrolling up
    if (this.mDraggingInProgress) {
      // Don't use fallback mechanism during drag, completely rely on isLineVisible boundary judgment
      // This way original current line can move out of view range normally
    }

    // If not visible, return transparent
    if (!isVisible) {
      // Already logged above, directly return here
      return 0.0;
    }

    // 🎯 If opacity effect is disabled, all visible lines are completely opaque
    if (!this.enableOpacityEffect) {
      return 1.0;
    }

    // Visible lines calculate opacity based on distance from current line
    // 🎯 Use virtual current line index to calculate distance during drag
    let currentIndex = this.mIndexOfCurrentLine;
    if (this.mDraggingInProgress && this.originalCurrentLineIndex >= 0) {
      const lyricsModel = this.mLyricMachine?.getLyricsModel();
      const virtualCurrentLineIndex = this.originalCurrentLineIndex - this.dragLineOffset;
      currentIndex = Math.max(0, Math.min(virtualCurrentLineIndex,
        (lyricsModel?.lines?.length || 1) - 1));
    }

    const distance = Math.abs(index - currentIndex);
    const maxVisibleLines = this.getMaxVisibleLines();
    const maxDistance = Math.floor(maxVisibleLines / 2);

    if (distance === 0) {
      return 1.0; // Current line completely opaque
    } else if (distance <= maxDistance) {
      // Use smoother opacity gradient
      const fadeRatio = distance / maxDistance;
      const opacity = Math.max(0.2, 1.0 - (fadeRatio * 0.4)); // Gradient from 1.0 to 0.6
      return opacity;
    } else if (distance <= maxDistance + 1) {
      // Boundary lines use very low opacity, ensure smooth transition
      return 0.1;
    } else {
      return 0.0; // Lines beyond range completely transparent
    }
  }

  /**
   * Calculate line scale ratio
   */
  private getLineScale(index: number): number {
    if (index === this.mIndexOfCurrentLine) {
      return 1.1; // Current line slightly enlarged, highlight display
    } else {
      const distance = Math.abs(index - this.mIndexOfCurrentLine);
      // Farther from current line, smaller scale, but maintain minimum value
      return Math.max(0.95, 1.0 - (distance * 0.03));
    }
  }

  /**
   * Get transition line Y position (use animation interpolation)
   */
  private getTransitioningYPosition(): number {
    // Judge based on style transition state, not time
    if (!this.styleTransitioning) {
      return this.transitioningFromY; // First frame: starting position (center position)
    } else {
      return this.transitioningToY; // Subsequent frames: target position, let animation system handle interpolation
    }
  }

  /**
   * Get transition line font size (use animation interpolation)
   */
  private getTransitioningHighlightLineTextSize(): number {
    // Judge based on style transition state, not time
    if (!this.styleTransitioning) {
      return this.currentLineTextSize; // First frame: keep highlight line font size
    } else {
      return this.textSize; // Subsequent frames: transition to normal line font size
    }
  }

  /**
   * Get transition line font color (use animation interpolation)
   */
  private getTransitioningHighlightLineTextColor(): string {
    // Judge based on style transition state, not time
    if (!this.styleTransitioning) {
      return this.currentLineHighlightedTextColor; // First frame: keep highlight line color
    } else {
      return this.previousLineTextColor; // Subsequent frames: transition to normal line color
    }
  }

  /**
   * Get transition line font weight (use animation interpolation)
   */
  private getTransitioningHighlightLineFontWeight(): FontWeight {
    // Judge based on style transition state, not time
    if (!this.styleTransitioning) {
      return FontWeight.Bold; // First frame: keep highlight line font weight
    } else {
      return FontWeight.Normal; // Subsequent frames: transition to normal line font weight
    }
  }

  /**
   * Get transition line scale ratio (smooth transition)
   */
  private getTransitioningScale(index: number): number {
    // Judge based on style transition state, not time
    if (!this.styleTransitioning) {
      // First frame: keep highlight line scale ratio
      return this.getLineScale(this.mIndexOfCurrentLine);
    } else {
      // Subsequent frames: transition to target line scale ratio
      return this.getLineScale(index);
    }
  }

  /**
   * Get new current line Y position
   */
  private getNewCurrentYPosition(): number {
    // Return starting position at animation start, then quickly switch to target position to trigger animation
    const currentTime = Date.now();
    const timeSinceAnimation = currentTime - this.animationKey;
    const isInStartPhase = timeSinceAnimation < 50;
    const position = isInStartPhase ? this.newCurrentFromY : this.newCurrentToY;

    return position;
  }

  /**
   * Get new current line scale ratio
   */
  private getNewCurrentScale(): number {
    if (this.styleTransitioning) {
      return 1.1; // Use current line scale during style transition
    } else {
      return 1.0; // Use normal line scale during position transition
    }
  }

  /**
   * Get transitioning font size
   */
  private getTransitioningFontSize(): number {
    if (this.styleTransitioning) {
      return this.currentLineTextSize; // Transition to current line font size
    } else {
      return this.textSize; // Use normal line font size at start
    }
  }

  /**
   * Get transitioning text color
   */
  private getTransitioningTextColor(): string {
    if (this.styleTransitioning) {
      return this.currentLineTextColor; // Transition to current line color
    } else {
      return this.upcomingLineTextColor; // Use unsung line color at start
    }
  }

  /**
   * Get transitioning font weight
   */
  private getTransitioningFontWeight(): FontWeight {
    if (this.styleTransitioning) {
      return FontWeight.Bold; // Transition to current line font weight
    } else {
      return FontWeight.Normal; // Use normal line font weight at start
    }
  }

  /**
   * Get start time corresponding to lyrics line index
   * @param lineIndex Lyrics line index
   * @return Corresponding start time (milliseconds), return -1 if invalid
   */
  private getLineStartTime(lineIndex: number): number {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines || lineIndex < 0 || lineIndex >= lyricsModel.lines.length) {
      return -1;
    }

    return lyricsModel.lines[lineIndex].getStartTime();
  }

  /**
   * Handle drag start event
   * @param touchY Initial touch Y coordinate
   */
  private handleDragStart(touchY: number): void {
    if (!this.enableDragging) {
      return;
    }

    this.mDraggingInProgress = true;
    this.initialTouchY = touchY;
    this.dragLineOffset = 0;
    this.originalCurrentLineIndex = this.mIndexOfCurrentLine; // Record current line at drag start

    // Notify drag start through EventBus
    this.eventBus.emit(LyricsEvents.DRAG_START);
  }

  /**
   * Handle drag move event
   * @param touchY Current touch Y coordinate
   */
  private handleDragMove(touchY: number): void {
    if (!this.enableDragging || !this.mDraggingInProgress) {
      return;
    }

    // Calculate Y-axis movement distance
    const deltaY = touchY - this.initialTouchY;

    // Calculate lyrics line offset based on Y-axis movement distance
    // 🎯 Use dynamic line height to ensure drag calculation consistent with rendering
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    let lineHeight = this.getLineHeight(); // Default value

    if (lyricsModel && lyricsModel.lines && this.originalCurrentLineIndex >= 0 &&
      this.originalCurrentLineIndex < lyricsModel.lines.length) {
      const currentLine = lyricsModel.lines[this.originalCurrentLineIndex];
      lineHeight = currentLine ?
        this.getDynamicLineHeight(currentLine, this.currentLineTextSize) :
        this.getLineHeight();
    }

    const rawLineOffset = Math.round(deltaY / lineHeight);

    // Calculate drag boundary limits
    if (lyricsModel && lyricsModel.lines) {
      // Calculate more conservative boundary limits
      const totalLines = lyricsModel.lines.length;

      // Upward drag limit: cannot exceed first line
      const maxUpwardOffset = this.originalCurrentLineIndex;

      // Downward drag limit: cannot exceed last line
      const maxDownwardOffset = totalLines - 1 - this.originalCurrentLineIndex;

      // Limit drag offset within safe range
      this.dragLineOffset = Math.max(-maxDownwardOffset, Math.min(maxUpwardOffset, rawLineOffset));

      // 🎯 Drag debug log: show virtual current line change, implement scrolling list effect
      const virtualCurrentLineIndex = this.originalCurrentLineIndex - this.dragLineOffset;
      const clampedVirtualIndex = Math.max(0, Math.min(virtualCurrentLineIndex, totalLines - 1));
    } else {
      this.dragLineOffset = 0;
    }
  }

  /**
   * Handle drag end event
   * @param touchY Final touch point Y coordinate
   */
  private handleDragEnd(touchY: number): void {
    if (!this.enableDragging) {
      return;
    }

    this.mDraggingInProgress = false;

    // Calculate final target line index
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (lyricsModel && lyricsModel.lines) {
      const finalLineIndex = this.originalCurrentLineIndex - this.dragLineOffset;
      const clampedIndex = Math.max(0, Math.min(finalLineIndex, lyricsModel.lines.length - 1));
      const startTime = this.getLineStartTime(clampedIndex);

      if (startTime >= 0) {
        // Notify final drag position through EventBus
        this.eventBus.emit(LyricsEvents.DRAG_END, startTime);
      }
    }

    // Reset drag state
    this.initialTouchY = 0;
    this.dragLineOffset = 0;
    this.originalCurrentLineIndex = -1;
  }

  /**
   * Renders the prelude end position indicator
   */
  @Builder
  PreludeIndicatorBuilder() {
    if (this.enablePreludeEndPositionIndicator && this.lyricsModel &&
      this.getPreludeCountDown() > 0) {
      Row() {
        // Indicator 1
        Circle({
          width: this.preludeEndPositionIndicatorRadius * 2,
          height: this.preludeEndPositionIndicatorRadius * 2
        })
          .fill(this.preludeEndPositionIndicatorColor)

        if (this.getPreludeCountDown() >= 2) {
          // Indicator 2
          Circle({
            width: this.preludeEndPositionIndicatorRadius * 2,
            height: this.preludeEndPositionIndicatorRadius * 2
          })
            .fill(this.preludeEndPositionIndicatorColor)
            .margin({ left: this.preludeEndPositionIndicatorRadius * 2 })
        }

        if (this.getPreludeCountDown() >= 3) {
          // Indicator 3 (with blinking effect)
          Circle({
            width: this.preludeEndPositionIndicatorRadius * 2,
            height: this.preludeEndPositionIndicatorRadius * 2
          })
            .fill(this.preludeEndPositionIndicatorColor)
            .margin({ left: this.preludeEndPositionIndicatorRadius * 2 })
            .opacity((this.getPreludeCountDown() % 2 === 1 || this.mCurrentTime < 2000) ? 1 : 0)
        }
      }
      .width('100%')
      .justifyContent(this.getRowJustifyContent())
      .margin({ top: this.preludeEndPositionIndicatorPaddingTop })
    }
  }

  build() {
    Column() {
      // Prelude indicator
      this.PreludeIndicatorBuilder()

      if (this.uninitializedOrNoLyrics()) {
        this.NoLyricsBuilder()
      } else {
        // Use Stack to support absolute positioning
        Stack() {
          if (this.lyricsLines.length > 0) {
            ForEach(this.lyricsLines, (line: LyricsLineModel, index: number) => {
              // Decide whether to render this line based on switches
              if (this.shouldRenderLine(index)) {
                this.EnhancedLyricsLineBuilder(line, index)
              }
            })
          }
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.TopStart) // Position from top
        .clip(true) // 🎯 Clip lyrics content beyond boundaries to prevent display outside view
      }
    }
    .width('100%')
    .height('90%')
    .backgroundColor(this.viewBackgroundColor)
    .margin({ top: this.paddingTop })
    .onTouch((event: TouchEvent) => {
      if (!this.enableDragging) {
        return false;
      }

      switch (event.type) {
        case TouchType.Down:
          this.handleDragStart(event.touches[0].y);
          return true;
        case TouchType.Move:
          this.handleDragMove(event.touches[0].y);
          return true;
        case TouchType.Up:
        case TouchType.Cancel:
          this.handleDragEnd(event.touches[0].y);
          return true;
        default:
          return false;
      }
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      // Dynamically get component actual size
      if (newValue.height && typeof newValue.height === 'number') {
        this.actualViewHeight = newValue.height;
        LogUtils.d(`LyricsView: Component height measured: ${this.actualViewHeight}`);
        // After height changes, positions will automatically recalculate, no need to manually scroll
      }
      if (newValue.width && typeof newValue.width === 'number') {
        this.actualViewWidth = newValue.width - this.linePaddingLeftRight * 2;
        LogUtils.d(`LyricsView: Component width measured: ${this.actualViewWidth}`);
      }
    })
    .onAppear(() => {
      LogUtils.d('LyricsView: Component appeared, setting up event listeners');
      this.setupEventListeners();
    })
    .onDisAppear(() => {
      LogUtils.d('LyricsView: Component disappearing, cleaning up');
      this.removeEventListeners();
      this.resetCompletely(); // Complete cleanup
    })
  }

  /**
   * Setup event listeners
   */
  private setupEventListeners(): void {
    LogUtils.d('LyricsView: Setting up event listeners');

    // Initialize LyricMachine
    this.initLyricMachine();

    // Listen to lyric data set event
    const setLyricDataHandler = (lyricModel: LyricModel) => {
      if (this.mLyricMachine) {
        this.mLyricMachine.prepare(lyricModel);

        // Immediately sync update reactive state
        const currentModel = this.mLyricMachine.getLyricsModel();
        this.lyricsModel = currentModel;
        this.lyricsLines = currentModel?.lines || [];

        this.forceCheckLineWrap();
        LogUtils.d(`LyricsView: Lyric data set successfully, model: ${!!this.lyricsModel}, lines: ${this.lyricsLines.length}`);
      } else {
        LogUtils.e('LyricsView: mLyricMachine is null when receiving SET_LYRIC_DATA event');
      }
    };
    this.eventBus.on(LyricsEvents.SET_LYRIC_DATA, setLyricDataHandler);

    // Listen to progress update event
    this.eventBus.on(LyricsEvents.SET_PROGRESS, (progress: number) => {
      if (this.mLyricMachine) {
        this.mLyricMachine.setProgress(progress);
      }
    });

    // Listen to reset event
    this.eventBus.on(LyricsEvents.RESET, () => {
      LogUtils.d('LyricsView: Received RESET event');
      if (this.mLyricMachine) {
        this.mLyricMachine.reset();
      }
    });

    // Listen to refresh UI event
    this.eventBus.on(LyricsEvents.REQUEST_REFRESH, () => {
      LogUtils.d('LyricsView: Received REQUEST_REFRESH event');
      this.requestRefreshUi();
    });
  }

  /**
   * Remove event listeners
   */
  private removeEventListeners(): void {
    LogUtils.d('LyricsView: Removing event listeners');
    // Can add specific removal logic here, but since EventBus is singleton,
    // we may need to save callback function references to remove correctly
  }

  /**
   * Initialize LyricMachine
   */
  private initLyricMachine(): void {
    // Create LyricMachine and prepare data
    if (!this.mLyricMachine) {
      LogUtils.d('LyricsView: Creating new LyricMachine');

      // Create a simple listener implementation
      class LyricListenerImpl implements OnLyricListener {
        private lyricsView: LyricsView;

        constructor(lyricsView: LyricsView) {
          this.lyricsView = lyricsView;
        }

        resetUi(): void {
          this.lyricsView.reset();
        }

        requestRefreshUi(): void {
          this.lyricsView.requestRefreshUi();
        }
      }

      const listener = new LyricListenerImpl(this);
      this.mLyricMachine = new LyricMachine(listener);
      LogUtils.d(`LyricsView: LyricMachine created successfully, initial ready state: ${this.mLyricMachine.isReady()}`);
    } else {
      LogUtils.d('LyricsView: LyricMachine already exists');
    }
  }
}
