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
  @Prop currentLineTextColor: string = '#FFFFFF';
  /** Text color for current line's highlighted portion */
  @Prop currentLineHighlightedTextColor: string = '#FF6B35';
  /** Text color for previous lyrics lines */
  @Prop previousLineTextColor: string = '#999999';
  /** Text color for upcoming lyrics lines */
  @Prop upcomingLineTextColor: string = '#999999';
  /** Vertical spacing between lyrics lines */
  @Prop lineSpacing: number = 12;
  /** Top padding for the entire lyrics view */
  @Prop paddingTop: number = 5;
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
  @Prop preludeEndPositionIndicatorPaddingTop: number = 3;
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
    //   this.enableLineWrap = true;
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
        // 当前行还能容纳这个字符，或者这是第一个字符
        currentLineText += tone.word;
        currentLineTones.push(tone);
        currentLineEndTime = tone.end;
      } else {
        // 当前行已满，开始新行
        if (currentLineText !== '') {
          result.push({
            text: currentLineText,
            tones: [...currentLineTones],
            startTime: currentLineStartTime,
            endTime: currentLineEndTime
          });
        }

        // 开始新行
        currentLineText = tone.word;
        currentLineTones = [tone];
        currentLineStartTime = tone.begin;
        currentLineEndTime = tone.end;
      }
    }

    // 添加最后一行
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
   * 计算多行歌词中特定物理行的高亮进度
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

    // 在这个物理行的时间范围内，计算字符级别的进度
    let highlightedChars = 0;
    for (const tone of displayLine.tones) {
      if (currentTime >= tone.end) {
        highlightedChars += tone.word.length;
      } else if (currentTime >= tone.begin) {
        // 部分高亮当前字符
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
   * 改进的文本宽度估算方法
   * 根据字符类型进行更精确的估算，并添加安全边距
   */
  private measureTextWidth(text: string, fontSize: number): number {
    let estimatedWidth = 0;
    let isChinese = false;

    for (let i = 0; i < text.length; i++) {
      const char = text.charAt(i);
      if (/[\u4e00-\u9fa5]/.test(char)) {
        // 中文字符，宽度约等于字体大小
        estimatedWidth += fontSize;
        isChinese = true;
      } else if (/[a-zA-Z0-9]/.test(char)) {
        // 英文字母和数字，宽度约为字体大小的0.6倍（稍微增加以确保准确性）
        estimatedWidth += fontSize * 0.6;
      } else {
        // 标点符号和其他字符
        if (isChinese) {
          estimatedWidth += fontSize * 0.8; // 中文标点符号
        } else {
          estimatedWidth += fontSize * 0.4; // 英文标点符号
        }
      }
    }

    // 为英文文本添加额外的安全边距，因为英文字符间距和字体渲染可能有差异
    if (!isChinese && text.length > 0) {
      estimatedWidth *= 1.1; // 增加10%的安全边距
    }

    return estimatedWidth;
  }

  /**
   * 检测文本是否需要滚动（超出容器宽度）
   */
  private isTextOverflowing(text: string, fontSize: number): boolean {
    const actualTextWidth = this.measureTextWidth(text, fontSize);
    // 考虑左右边距，实际可用宽度要减去边距
    const availableWidth = this.actualViewWidth - (this.linePaddingLeftRight * 2);
    const isOverflowing = actualTextWidth > availableWidth;

    // 为了测试，降低滚动触发阈值
    if (!this.shouldEnableLineWrap()) {
      // 对于不换行模式，如果文本长度超过5个字符就认为需要滚动（便于测试）
      if (text.length > 5) {
        return true;
      }
    }

    return isOverflowing;
  }

  /**
   * 计算文本滚动偏移量
   * 让正在播放的部分始终保持在视图中央
   */
  private calculateTextScrollOffset(line: LyricsLineModel, progress: number): number {
    const text = this.getLineText(line);
    const fontSize = this.currentLineTextSize; // 确保使用当前行字体大小
    const actualTextWidth = this.measureTextWidth(text, fontSize); // 使用精确测量
    // 考虑左右边距，实际可用宽度要减去边距
    const containerWidth = this.actualViewWidth - (this.linePaddingLeftRight * 2);

    // 为了测试，即使文本不是很长也允许滚动
    if (actualTextWidth <= containerWidth * 0.8) { // 降低阈值，80%就开始滚动
      return 0; // 文本不够长，无需滚动
    }

    // 计算当前播放位置的像素偏移
    const currentPlayPosition = actualTextWidth * progress;
    const halfContainerWidth = containerWidth / 2;

    // 让当前播放位置保持在容器中央
    let targetOffset = currentPlayPosition - halfContainerWidth;

    // 限制滚动范围：不能滚动到负值，也不能超过最大滚动距离
    const maxScrollOffset = actualTextWidth - containerWidth;
    targetOffset = Math.max(0, Math.min(targetOffset, maxScrollOffset));

    return targetOffset;
  }

  /**
   * 启动文本滚动动画
   */
  private startTextScrollAnimation(line: LyricsLineModel): void {
    const text = this.getLineText(line);

    // 重置滚动偏移，为新行准备
    this.currentLineScrollOffset = 0;

    if (this.shouldEnableLineWrap()) {
      return; // 启用换行时不需要滚动
    }

    if (!this.isTextOverflowing(text, this.currentLineTextSize)) {
      return; // 文本不超长时不需要滚动
    }

    this.isTextScrolling = true;

    // 清除之前的定时器
    if (this.textScrollTimer !== -1) {
      clearInterval(this.textScrollTimer);
    }

    // 启动滚动定时器，每50ms更新一次以获得更流畅的效果
    this.textScrollTimer = setInterval(() => {
      if (!this.isTextScrolling) {
        return;
      }

      const progress = this.calculateLineProgress(line);
      const targetOffset = this.calculateTextScrollOffset(line, progress);

      // 使用textScroller.scrollTo实现真正的滚动
      if (Math.abs(this.currentLineScrollOffset - targetOffset) > 0.5) {
        const oldOffset = this.currentLineScrollOffset;
        this.currentLineScrollOffset = targetOffset;

        // 使用Scroller进行滚动
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
   * 停止文本滚动动画
   */
  private stopTextScrollAnimation(): void {
    if (this.textScrollTimer !== -1) {
      clearInterval(this.textScrollTimer);
      this.textScrollTimer = -1;
    }
    this.isTextScrolling = false;
    this.mCurrentLineTranslateX = 0; // 重置水平滚动偏移
    // 重置滚动位置到开始
    this.textScroller.scrollTo({
      xOffset: 0,
      yOffset: 0
    });
  }

  /**
   * 检查是否需要应用横向滚动（参考Android版本实现）
   * 当高亮部分和剩余部分都大于视图宽度的一半时，开始滚动
   */
  private checkIfXTranslationShouldApply(line: LyricsLineModel): void {
    if (this.shouldEnableLineWrap()) {
      this.mCurrentLineTranslateX = 0; // 换行模式下不需要横向滚动
      this.updateScrollPosition(0);
      return;
    }

    const text = this.getLineText(line);
    const fontSize = this.currentLineTextSize;
    const textWidth = text.length * fontSize * 0.6; // 估算文本总宽度
    const viewWidth = this.actualViewWidth;
    const halfViewWidth = viewWidth / 2;

    // 检查文本是否超长
    if (!this.isLyricsLineOverlong(textWidth)) {
      this.mCurrentLineTranslateX = 0;
      this.updateScrollPosition(0);
      return;
    }

    // 计算当前高亮区域宽度
    const progress = this.calculateLineProgress(line);
    const currentHighlightWidth = textWidth * progress;

    // Android版本的滚动逻辑：
    // 1. 高亮部分大于视图宽度的一半
    // 2. 剩余部分也大于视图宽度的一半
    if (currentHighlightWidth > halfViewWidth &&
      (textWidth - currentHighlightWidth) > halfViewWidth) {

      // 计算目标滚动位置：让当前播放位置保持在屏幕中央
      const targetScrollX = currentHighlightWidth - halfViewWidth;

      // 限制滚动范围
      const maxScroll = textWidth - viewWidth;
      this.mCurrentLineTranslateX = Math.max(0, Math.min(maxScroll, targetScrollX));

      // 应用滚动
      this.updateScrollPosition(this.mCurrentLineTranslateX);

    } else {
      this.mCurrentLineTranslateX = 0;
      this.updateScrollPosition(0);
    }
  }

  /**
   * 更新滚动位置
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
   * 检查歌词行是否超长（需要横向滚动）
   */
  private isLyricsLineOverlong(textWidth: number): boolean {
    return textWidth > this.actualViewWidth;
  }

  /**
   * 计算可以显示的最大行数（上下各一半）
   */
  private getMaxVisibleLines(): number {
    const lineHeight = this.getLineHeight();
    const availableHeight = this.actualViewHeight;
    return Math.floor(availableHeight / lineHeight);
  }

  /**
   * 判断歌词行是否在可视范围内
   */
  private isLineVisible(index: number): boolean {
    // 计算该行的实际Y位置
    const lineY = this.calculateLineYPosition(index);
    const lineHeight = this.getLineHeight();

    // 判断行是否在视图范围内（包含部分可见）
    const lineTop = lineY;
    const lineBottom = lineY + lineHeight;
    const viewTop = -lineHeight * 0.5; // 允许稍微超出上边界
    const viewBottom = this.actualViewHeight + lineHeight * 0.5; // 允许稍微超出下边界

    // 如果行的任何部分在扩展视图范围内，就认为是可见的
    const isVisible = lineBottom > viewTop && lineTop < viewBottom;

    return isVisible;
  }

  /**
   * 判断是否应该渲染某一行（基于enablePreviousLines和enableUpcomingLines开关）
   */
  private shouldRenderLine(index: number): boolean {
    // 确定当前参考行索引
    let currentIndex = this.mIndexOfCurrentLine;

    if (this.mDraggingInProgress && this.originalCurrentLineIndex >= 0) {
      // 🎯 拖拽时使用虚拟当前行索引，实现滚动列表效果
      const lyricsModel = this.mLyricMachine?.getLyricsModel();
      const virtualCurrentLineIndex = this.originalCurrentLineIndex - this.dragLineOffset;
      currentIndex = Math.max(0, Math.min(virtualCurrentLineIndex,
        (lyricsModel?.lines?.length || 1) - 1));
    }

    // 当前行始终渲染
    if (index === currentIndex) {
      return true;
    }

    // 检查是否是之前的行
    if (index < currentIndex) {
      return this.enablePreviousLines;
    }

    // 检查是否是未来的行
    if (index > currentIndex) {
      return this.enableUpcomingLines;
    }

    return true;
  }

  /**
   * 统计并记录当前可见的行数（调试用）
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
   * 渐进式高亮歌词行Builder - 实现卡拉OK风格的流畅高亮效果
   */
  @Builder
  EnhancedLyricsLineBuilder(line: LyricsLineModel, index: number) {
    if (this.isLineVisible(index)) {
      // 渲染所有行，但使用透明度控制可见性，确保动画连续性
      if (index === this.mIndexOfCurrentLine && this.newCurrentTransitioning) {
        // 新当前行正在过渡：使用新当前行过渡效果
        this.NewCurrentLineTransitionBuilder(line, index)
      } else if (index === this.mIndexOfCurrentLine) {
        // 当前行：使用渐进式高亮效果
        this.ProgressiveHighlightLineBuilder(line, index)
      } else if (index === this.transitioningFromIndex && this.isAnimating) {
        this.TransitioningHighlightLineBuilder(line, index)
      } else {
        this.NormalLineBuilder(line, index)
      }
    }
  }

  /**
   * 检查是否应该启用换行（LRC格式默认启用）
   */
  private shouldEnableLineWrap(): boolean {
    // 如果明确设置了enableLineWrap，使用设置值
    if (this.enableLineWrap !== undefined) {
      return this.enableLineWrap;
    }

    // 检查是否是LRC格式（通过检查歌词模型的类型）
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (lyricsModel && lyricsModel.type === LyricType.LRC) {
      return true; // LRC格式默认启用换行
    }

    return false; // 其他格式默认不启用换行
  }

  /**
   * 渐进式高亮行Builder
   */
  @Builder
  ProgressiveHighlightLineBuilder(line: LyricsLineModel, index: number) {
    if (this.shouldEnableLineWrap()) {
      // 启用换行模式
      this.WrappedHighlightLineBuilder(line, index);
    } else {
      // 滚动模式
      this.ScrollingHighlightLineBuilder(line, index);
    }
  }

  /**
   * 换行高亮行Builder
   */
  @Builder
  WrappedHighlightLineBuilder(line: LyricsLineModel, index: number) {
    Stack() {
      // 背景文字（正常颜色）
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
                .maxLines(1) // 每个物理行都是单行
                .textOverflow({ overflow: TextOverflow.None })
            }
            .width('100%')
            .justifyContent(this.getRowJustifyContent())
            .height(this.currentLineTextSize)
          }, (displayLine: DisplayLine, displayIndex: number) => `${index}_bg_${displayIndex}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // 高亮文字（逐行渐进高亮）
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
                .maxLines(1) // 每个物理行都是单行
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
              duration: 50, // 更快的高亮响应
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
      duration: 400, // 统一动画时长
      delay: this.getAnimationDelay(index), // 错开动画延迟
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * 滚动高亮行Builder（单行显示，支持横向滚动动画）
   */
  @Builder
  ScrollingHighlightLineBuilder(line: LyricsLineModel, index: number) {
    // 使用Scroll组件实现真正的横向滚动
    Scroll(this.textScroller) {
      Stack() {
        // 背景文字（正常颜色，单行显示）
        Text(this.getLineText(line))
          .fontSize(this.currentLineTextSize)
          .fontColor(this.currentLineTextColor)
          .fontWeight(FontWeight.Bold)
          .textAlign(this.getTextAlign())
          .maxLines(1) // 单行显示
          .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
          .width('auto') // 让文本自然宽度
          .onAppear(() => {
          })

        // 高亮文字（使用clip实现渐进效果）
        Text(this.getLineText(line))
          .fontSize(this.currentLineTextSize)
          .fontColor(this.currentLineHighlightedTextColor)
          .fontWeight(FontWeight.Bold)
          .textAlign(this.getTextAlign())
          .maxLines(1) // 单行显示
          .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
          .width('auto') // 让文本自然宽度
          .clip(true)
          .clipShape(new Rect({
            width: `${this.calculateLineProgress(line) * 100}%`, // 使用百分比确保正确对齐
            height: '100%'
          }))
          .animation({
            duration: 50, // 更快的高亮响应
            curve: Curve.Linear,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .alignContent(this.getAlignment())
    }
    .scrollable(ScrollDirection.Horizontal) // 水平滚动
    .scrollBar(BarState.Off) // 隐藏滚动条
    .width(this.actualViewWidth)
    .height(this.getLineHeight())
    .position({ x: this.linePaddingLeftRight, y: this.calculateLineYPosition(index) })
    .opacity(this.getLineOpacity(index))
    .scale({
      x: this.getLineScale(index),
      y: this.getLineScale(index)
    })
    .animation({
      duration: 400, // 统一动画时长
      delay: this.getAnimationDelay(index), // 错开动画延迟
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * 过渡普通行Builder - 处理原当前行以普通行样式从当前位置移动到目标位置
   */
  @Builder
  TransitioningHighlightLineBuilder(line: LyricsLineModel, index: number) {
    // 根据enableLineWrap决定显示方式
    if (this.shouldEnableLineWrap()) {
      // 换行模式：支持多行显示
      Row() {
        Text(this.getLineText(line))
          .fontSize(this.getTransitioningHighlightLineTextSize()) // 保持当前行字体大小，通过缩放实现大小变化
          .fontColor(this.getTransitioningHighlightLineTextColor()) // 使用动态颜色
          .fontWeight(this.getTransitioningHighlightLineFontWeight()) // 保持当前行字重
          .textAlign(this.getTextAlign())
          .width('100%')
          .maxLines(3) // 最多3行
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(this.actualViewWidth)
      .height(this.getDynamicLineHeight(line, this.currentLineTextSize))
      .justifyContent(this.getRowJustifyContent())
      .alignItems(VerticalAlign.Center)
      .position({
        x: this.linePaddingLeftRight,
        y: this.getTransitioningYPosition() // 使用动画插值位置
      })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getTransitioningScale(index),
        y: this.getTransitioningScale(index)
      })
      .animation({
        duration: 350, // ArkUI V2 优化：稍微延长动画时间，让过渡更平滑
        curve: Curve.EaseOut, // 使用 EaseOut 让动画结尾更自然
        iterations: 1,
        playMode: PlayMode.Normal,
        delay: 0 // 确保没有延迟，立即开始
      })
    } else {
      // 不换行模式：使用Scroll组件避免字体变化时的闪动
      Scroll() {
        Stack() {
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningHighlightLineTextSize()) // 保持当前行字体大小，通过缩放实现大小变化
            .fontColor(this.getTransitioningHighlightLineTextColor()) // 使用动态颜色
            .fontWeight(this.getTransitioningHighlightLineFontWeight()) // 保持当前行字重
            .textAlign(this.getTextAlign())
            .maxLines(1) // 单行显示
            .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
            .width('auto') // 让文本自然宽度
        }
        .alignContent(this.getAlignment())
      }
      .scrollable(ScrollDirection.Horizontal) // 水平滚动
      .scrollBar(BarState.Off) // 隐藏滚动条
      .width(this.actualViewWidth)
      .height(this.getLineHeight())
      .position({
        x: this.linePaddingLeftRight,
        y: this.getTransitioningYPosition() // 使用动画插值位置
      })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getTransitioningScale(index),
        y: this.getTransitioningScale(index),
      })
      .animation({
        duration: 350, // ArkUI V2 优化：稍微延长动画时间，让过渡更平滑
        curve: Curve.EaseOut, // 使用 EaseOut 让动画结尾更自然
        iterations: 1,
        playMode: PlayMode.Normal,
        delay: 0 // 确保没有延迟，立即开始
      })
    }
  }

  /**
   * 新当前行过渡Builder - 处理从下一行位置移动到中心并变为高亮样式
   */
  @Builder
  NewCurrentLineTransitionBuilder(line: LyricsLineModel, index: number) {
    // 根据enableLineWrap决定显示方式
    if (this.shouldEnableLineWrap()) {
      // 换行模式：使用Stack布局
      Stack() {
        // 背景文字（平滑过渡样式）
        Row() {
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize())
            .fontColor(this.getTransitioningTextColor())
            .fontWeight(this.getTransitioningFontWeight())
            .textAlign(this.getTextAlign())
            .width('100%')
            .maxLines(3) // 最多3行
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .animation({
              duration: 300, // 样式过渡动画
              curve: Curve.EaseInOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })
        }
        .width('100%')
        .justifyContent(this.getRowJustifyContent())

        // 高亮文字（渐进显示）- 始终显示，但在动画期间使用相同的字体大小
        Row() {
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize()) // 使用相同的过渡字体大小，确保完全对齐
            .fontColor(this.currentLineHighlightedTextColor)
            .fontWeight(this.getTransitioningFontWeight()) // 使用相同的过渡字重
            .textAlign(this.getTextAlign())
            .width('100%')
            .maxLines(3) // 最多3行
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .animation({
              duration: 300, // 样式过渡动画，与背景文字同步
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
        .opacity(this.styleTransitioning ? 1.0 : 0.0) // 样式过渡开始后才显示高亮
        .animation({
          duration: 300, // 高亮渐入动画
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
        y: this.getNewCurrentYPosition() // 使用新当前行的位置
      })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getNewCurrentScale(),
        y: this.getNewCurrentScale()
      })
      .animation({
        duration: 400, // 位置和缩放动画
        delay: this.getAnimationDelay(index),
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
    } else {
      // 不换行模式：使用Scroll组件避免闪动
      Scroll(this.textScroller) {
        Stack() {
          // 背景文字（单行显示）
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize())
            .fontColor(this.getTransitioningTextColor())
            .fontWeight(this.getTransitioningFontWeight())
            .textAlign(this.getTextAlign()) // 左对齐
            .maxLines(1) // 单行显示
            .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
            .width('auto') // 让文本自然宽度
            .animation({
              duration: 300, // 样式过渡动画
              curve: Curve.EaseInOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })

          // 高亮文字（渐进显示，单行）- 始终显示，但在动画期间使用相同的字体大小
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize()) // 使用相同的过渡字体大小，确保完全对齐
            .fontColor(this.currentLineHighlightedTextColor)
            .fontWeight(this.getTransitioningFontWeight()) // 使用相同的过渡字重
            .textAlign(this.getTextAlign()) // 左对齐
            .maxLines(1) // 单行显示
            .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
            .width('auto') // 让文本自然宽度
            .clip(true)
            .clipShape(new Rect({
              width: `${this.calculateLineProgress(line) * 100}%`,
              height: '100%'
            }))
            .opacity(this.styleTransitioning ? 1.0 : 0.0) // 样式过渡开始后才显示高亮
            .animation({
              duration: 300, // 高亮渐入动画
              curve: Curve.EaseInOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })
        }
        .alignContent(this.getAlignment())
      }
      .scrollable(ScrollDirection.Horizontal) // 水平滚动
      .scrollBar(BarState.Off) // 隐藏滚动条
      .width(this.actualViewWidth)
      .height(this.getLineHeight())
      .position({
        x: this.linePaddingLeftRight,
        y: this.getNewCurrentYPosition() // 使用新当前行的位置
      })
      .opacity(this.getLineOpacity(index))
      .scale({
        x: this.getNewCurrentScale(),
        y: this.getNewCurrentScale()
      })
      .animation({
        duration: 400, // 位置和缩放动画
        delay: this.getAnimationDelay(index),
        curve: Curve.EaseInOut,
        iterations: 1,
        playMode: PlayMode.Normal
      })
    }
  }

  /**
   * 普通行Builder
   */
  @Builder
  NormalLineBuilder(line: LyricsLineModel, index: number) {
    if (this.shouldEnableLineWrap()) {
      // 换行模式：普通行支持换行
      this.WrappedNormalLineBuilder(line, index);
    } else {
      // 不换行模式：普通行单行显示，不显示省略号
      this.SingleLineNormalBuilder(line, index);
    }
  }

  /**
   * 换行普通行Builder
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
        .maxLines(3) // 最多3行
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
      duration: 400, // 统一动画时长，与高亮行保持一致
      delay: this.getAnimationDelay(index), // 错开动画延迟
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * 单行普通行Builder（不换行，不显示省略号）
   */
  @Builder
  SingleLineNormalBuilder(line: LyricsLineModel, index: number) {
    Stack() {
      Text(this.getLineText(line))
        .fontSize(this.textSize)
        .fontColor(this.getNormalLineColor(index))
        .fontWeight(FontWeight.Normal)
        .textAlign(this.getTextAlign())
        .maxLines(1) // 单行显示
        .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
        .width('auto') // 让文本自然宽度
    }
    .width(this.actualViewWidth)
    .height(this.getLineHeight())
    .alignContent(this.getAlignment())
    .clip(true) // 裁剪超出部分，不显示省略号
    .position({ x: this.linePaddingLeftRight, y: this.calculateLineYPosition(index) })
    .opacity(this.getLineOpacity(index))
    .scale({
      x: this.getLineScale(index),
      y: this.getLineScale(index)
    })
    .animation({
      duration: 400, // 统一动画时长，与高亮行保持一致
      delay: this.getAnimationDelay(index), // 错开动画延迟
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * 计算当前行的高亮进度（0-1之间）
   * 基于时间的精确进度计算，避免中文字符计算偏快
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

    // 基于时间的进度计算，更准确地反映播放进度
    const lineDuration = lineEndTime - lineStartTime;
    const playedTime = this.mCurrentTime - lineStartTime;

    if (lineDuration <= 0) {
      return 1;
    }

    return Math.min(1, playedTime / lineDuration);
  }

  /**
   * 获取当前行字符颜色（实现高亮逻辑）
   */
  private getCurrentLineCharColor(tone: Tone): string {
    // 当前行的高亮逻辑：唱过的部分全部高亮
    if (this.mCurrentTime >= tone.begin) {
      return this.currentLineHighlightedTextColor; // 高亮颜色
    } else {
      return this.currentLineTextColor; // 当前行正常颜色
    }
  }

  /**
   * 获取普通行颜色
   */
  private getNormalLineColor(index: number): string {
    if (index < this.mIndexOfCurrentLine) {
      return this.previousLineTextColor; // 已唱过的行
    } else {
      return this.upcomingLineTextColor; // 未唱的行
    }
  }

  /**
   * 计算行的透明度（基于可见性和距离当前行的远近）
   */
  private getLineOpacity(index: number): number {
    // 首先检查是否应该渲染该行
    if (!this.shouldRenderLine(index)) {
      // 🎯 关键日志：监控原当前行的透明度变化
      if (Math.abs(Date.now() - this.animationKey) < 3000 && index === this.mIndexOfCurrentLine - 1) {
        LogUtils.d(`LyricsView: 👻 Line ${index} opacity set to 0.0 - shouldRenderLine returned false`);
      }
      return 0.0; // 如果开关禁用了该行，完全透明
    }

    const isVisible = this.isLineVisible(index);

    // 🎯 拖拽时移除保底机制，允许所有行（包括原当前行）正常按位置隐藏
    // 这样向上滚动时当前行可以正常移出视图顶部
    if (this.mDraggingInProgress) {
      // 拖拽时不使用保底机制，完全依赖isLineVisible的边界判断
      // 这样原当前行可以正常移出视图范围
    }

    // 如果不可见，返回透明
    if (!isVisible) {
      // 已经在上面记录了日志，这里直接返回
      return 0.0;
    }

    // 🎯 如果禁用了透明度效果，所有可见行都完全不透明
    if (!this.enableOpacityEffect) {
      return 1.0;
    }

    // 可见的行根据距离当前行的远近计算透明度
    // 🎯 拖拽时使用虚拟当前行索引计算距离
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
      return 1.0; // 当前行完全不透明
    } else if (distance <= maxDistance) {
      // 使用更平滑的透明度渐变
      const fadeRatio = distance / maxDistance;
      const opacity = Math.max(0.2, 1.0 - (fadeRatio * 0.4)); // 从1.0渐变到0.6
      return opacity;
    } else if (distance <= maxDistance + 1) {
      // 边界行使用很低的透明度，确保平滑过渡
      return 0.1;
    } else {
      return 0.0; // 超出范围的行完全透明
    }
  }

  /**
   * 计算行的缩放比例
   */
  private getLineScale(index: number): number {
    if (index === this.mIndexOfCurrentLine) {
      return 1.1; // 当前行稍微放大，突出显示
    } else {
      const distance = Math.abs(index - this.mIndexOfCurrentLine);
      // 距离当前行越远，缩放越小，但保持最小值
      return Math.max(0.95, 1.0 - (distance * 0.03));
    }
  }

  /**
   * 获取过渡行的Y位置（使用动画插值）
   */
  private getTransitioningYPosition(): number {
    // 基于样式过渡状态判断，而不是时间
    if (!this.styleTransitioning) {
      return this.transitioningFromY; // 第一帧：起始位置（中心位置）
    } else {
      return this.transitioningToY; // 后续帧：目标位置，让动画系统处理插值
    }
  }

  /**
   * 获取过渡行的字体大小（使用动画插值）
   */
  private getTransitioningHighlightLineTextSize(): number {
    // 基于样式过渡状态判断，而不是时间
    if (!this.styleTransitioning) {
      return this.currentLineTextSize; // 第一帧：保持高亮行字体大小
    } else {
      return this.textSize; // 后续帧：过渡到普通行字体大小
    }
  }

  /**
   * 获取过渡行的字体颜色（使用动画插值）
   */
  private getTransitioningHighlightLineTextColor(): string {
    // 基于样式过渡状态判断，而不是时间
    if (!this.styleTransitioning) {
      return this.currentLineHighlightedTextColor; // 第一帧：保持高亮行颜色
    } else {
      return this.previousLineTextColor; // 后续帧：过渡到普通行颜色
    }
  }

  /**
   * 获取过渡行的字体粗细（使用动画插值）
   */
  private getTransitioningHighlightLineFontWeight(): FontWeight {
    // 基于样式过渡状态判断，而不是时间
    if (!this.styleTransitioning) {
      return FontWeight.Bold; // 第一帧：保持高亮行字重
    } else {
      return FontWeight.Normal; // 后续帧：过渡到普通行字重
    }
  }

  /**
   * 获取过渡行的缩放比例（平滑过渡）
   */
  private getTransitioningScale(index: number): number {
    // 基于样式过渡状态判断，而不是时间
    if (!this.styleTransitioning) {
      // 第一帧：保持高亮行缩放比例
      return this.getLineScale(this.mIndexOfCurrentLine);
    } else {
      // 后续帧：过渡到目标行的缩放比例
      return this.getLineScale(index);
    }
  }

  /**
   * 获取新当前行的Y位置
   */
  private getNewCurrentYPosition(): number {
    // 在动画刚开始时返回起始位置，然后快速切换到目标位置触发动画
    const currentTime = Date.now();
    const timeSinceAnimation = currentTime - this.animationKey;
    const isInStartPhase = timeSinceAnimation < 50;
    const position = isInStartPhase ? this.newCurrentFromY : this.newCurrentToY;

    return position;
  }

  /**
   * 获取新当前行的缩放比例
   */
  private getNewCurrentScale(): number {
    if (this.styleTransitioning) {
      return 1.1; // 样式过渡时使用当前行缩放
    } else {
      return 1.0; // 位置过渡时使用普通行缩放
    }
  }

  /**
   * 获取过渡中的字体大小
   */
  private getTransitioningFontSize(): number {
    if (this.styleTransitioning) {
      return this.currentLineTextSize; // 过渡到当前行字体大小
    } else {
      return this.textSize; // 开始时使用普通行字体大小
    }
  }

  /**
   * 获取过渡中的文字颜色
   */
  private getTransitioningTextColor(): string {
    if (this.styleTransitioning) {
      return this.currentLineTextColor; // 过渡到当前行颜色
    } else {
      return this.upcomingLineTextColor; // 开始时使用未唱行颜色
    }
  }

  /**
   * 获取过渡中的字体粗细
   */
  private getTransitioningFontWeight(): FontWeight {
    if (this.styleTransitioning) {
      return FontWeight.Bold; // 过渡到当前行字重
    } else {
      return FontWeight.Normal; // 开始时使用普通行字重
    }
  }

  /**
   * 根据歌词行索引获取对应的开始时间
   * @param lineIndex 歌词行索引
   * @return 对应的开始时间（毫秒），如果无效则返回-1
   */
  private getLineStartTime(lineIndex: number): number {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines || lineIndex < 0 || lineIndex >= lyricsModel.lines.length) {
      return -1;
    }

    return lyricsModel.lines[lineIndex].getStartTime();
  }

  /**
   * 处理拖拽开始事件
   * @param touchY 初始触摸Y坐标
   */
  private handleDragStart(touchY: number): void {
    if (!this.enableDragging) {
      return;
    }

    this.mDraggingInProgress = true;
    this.initialTouchY = touchY;
    this.dragLineOffset = 0;
    this.originalCurrentLineIndex = this.mIndexOfCurrentLine; // 记录拖拽开始时的当前行

    // 通过EventBus通知拖拽开始
    this.eventBus.emit(LyricsEvents.DRAG_START);
  }

  /**
   * 处理拖拽移动事件
   * @param touchY 当前触摸Y坐标
   */
  private handleDragMove(touchY: number): void {
    if (!this.enableDragging || !this.mDraggingInProgress) {
      return;
    }

    // 计算Y轴移动距离
    const deltaY = touchY - this.initialTouchY;

    // 根据Y轴移动距离计算歌词行偏移量
    // 🎯 使用动态行高确保拖拽计算与渲染一致
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    let lineHeight = this.getLineHeight(); // 默认值

    if (lyricsModel && lyricsModel.lines && this.originalCurrentLineIndex >= 0 &&
      this.originalCurrentLineIndex < lyricsModel.lines.length) {
      const currentLine = lyricsModel.lines[this.originalCurrentLineIndex];
      lineHeight = currentLine ?
      this.getDynamicLineHeight(currentLine, this.currentLineTextSize) :
      this.getLineHeight();
    }

    const rawLineOffset = Math.round(deltaY / lineHeight);

    // 计算拖拽边界限制
    if (lyricsModel && lyricsModel.lines) {
      // 计算更保守的边界限制
      const totalLines = lyricsModel.lines.length;

      // 向上拖拽限制：不能超过第一行
      const maxUpwardOffset = this.originalCurrentLineIndex;

      // 向下拖拽限制：不能超过最后一行
      const maxDownwardOffset = totalLines - 1 - this.originalCurrentLineIndex;

      // 限制拖拽偏移量在安全范围内
      this.dragLineOffset = Math.max(-maxDownwardOffset, Math.min(maxUpwardOffset, rawLineOffset));

      // 🎯 拖拽调试日志：显示虚拟当前行变化，实现滚动列表效果
      const virtualCurrentLineIndex = this.originalCurrentLineIndex - this.dragLineOffset;
      const clampedVirtualIndex = Math.max(0, Math.min(virtualCurrentLineIndex, totalLines - 1));
    } else {
      this.dragLineOffset = 0;
    }
  }

  /**
   * 处理拖拽结束事件
   * @param touchY 最终触摸点的Y坐标
   */
  private handleDragEnd(touchY: number): void {
    if (!this.enableDragging) {
      return;
    }

    this.mDraggingInProgress = false;

    // 计算最终的目标行索引
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (lyricsModel && lyricsModel.lines) {
      const finalLineIndex = this.originalCurrentLineIndex - this.dragLineOffset;
      const clampedIndex = Math.max(0, Math.min(finalLineIndex, lyricsModel.lines.length - 1));
      const startTime = this.getLineStartTime(clampedIndex);

      if (startTime >= 0) {
        // 通过EventBus通知最终拖拽位置
        this.eventBus.emit(LyricsEvents.DRAG_END, startTime);
      }
    }

    // 重置拖拽状态
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
        // 使用 Stack 来支持绝对定位
        Stack() {
          if (this.lyricsLines.length > 0) {
            ForEach(this.lyricsLines, (line: LyricsLineModel, index: number) => {
              // 根据开关决定是否绘制该行
              if (this.shouldRenderLine(index)) {
                this.EnhancedLyricsLineBuilder(line, index)
              }
            })
          }
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.TopStart) // 从顶部开始定位
        .clip(true) // 🎯 裁剪超出边界的歌词内容，防止显示在视图外
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
      // 动态获取组件实际尺寸
      if (newValue.height && typeof newValue.height === 'number') {
        this.actualViewHeight = newValue.height;
        LogUtils.d(`LyricsView: Component height measured: ${this.actualViewHeight}`);
        // 高度变化后，位置会自动重新计算，不需要手动滚动
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
      this.resetCompletely(); // 完全清理
    })
  }

  /**
   * 设置事件监听器
   */
  private setupEventListeners(): void {
    LogUtils.d('LyricsView: Setting up event listeners');

    // 初始化LyricMachine
    this.initLyricMachine();

    // 监听歌词数据设置事件
    const setLyricDataHandler = (lyricModel: LyricModel) => {
      if (this.mLyricMachine) {
        this.mLyricMachine.prepare(lyricModel);

        // 立即同步更新响应式状态
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

    // 监听进度更新事件
    this.eventBus.on(LyricsEvents.SET_PROGRESS, (progress: number) => {
      if (this.mLyricMachine) {
        this.mLyricMachine.setProgress(progress);
      }
    });

    // 监听重置事件
    this.eventBus.on(LyricsEvents.RESET, () => {
      LogUtils.d('LyricsView: Received RESET event');
      if (this.mLyricMachine) {
        this.mLyricMachine.reset();
      }
    });

    // 监听刷新UI事件
    this.eventBus.on(LyricsEvents.REQUEST_REFRESH, () => {
      LogUtils.d('LyricsView: Received REQUEST_REFRESH event');
      this.requestRefreshUi();
    });
  }

  /**
   * 移除事件监听器
   */
  private removeEventListeners(): void {
    LogUtils.d('LyricsView: Removing event listeners');
    // 这里可以添加具体的移除逻辑，但由于EventBus是单例，
    // 我们可能需要保存回调函数的引用来正确移除
  }

  /**
   * 初始化LyricMachine
   */
  private initLyricMachine(): void {
    // 创建LyricMachine并准备数据
    if (!this.mLyricMachine) {
      LogUtils.d('LyricsView: Creating new LyricMachine');

      // 创建一个简单的监听器实现
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
