/**
 * LyricsView 配置类
 * 管理 LyricsView 组件的所有可配置属性
 */
export class LyricsViewConfig {
  // ========== 颜色配置 ==========
  /** 视图背景颜色 */
  viewBackgroundColor: string = '#CE93D8';
  /** 当前行普通文本颜色 */
  currentLineTextColor: string = '#FFFF00';
  /** 当前行高亮文本颜色 */
  currentLineHighlightedTextColor: string = '#FFF44336';
  /** 已唱歌词颜色 */
  previousLineTextColor: string = '#FFFFFF';
  /** 未唱歌词颜色 */
  upcomingLineTextColor: string = '#FFFFFF';
  /** 前奏指示器颜色 */
  preludeEndPositionIndicatorColor: string = '#FF6B35';
  // ========== 文本大小配置 ==========
  /** 普通歌词文本大小 */
  textSize: number = 16;
  /** 当前行文本大小 */
  currentLineTextSize: number = 20;
  // ========== 间距配置 ==========
  /** 行间距 */
  lineSpacing: number = 15;
  /** 顶部边距 */
  paddingTop: number = 15;
  /** 前奏指示器顶部边距 */
  preludeEndPositionIndicatorPaddingTop: number = 5;
  /** 前奏指示器圆点半径 */
  preludeEndPositionIndicatorRadius: number = 4;
  // ========== 功能开关配置 ==========
  /** 是否启用自动换行 */
  enableLineWrap: boolean = false;
  /** 是否启用拖拽 */
  enableDragging: boolean = true;
  /** 是否启用透明度渐变效果 */
  enableOpacityEffect: boolean = true;
  /** 是否显示已唱歌词 */
  enablePreviousLines: boolean = true;
  /** 是否显示未唱歌词 */
  enableUpcomingLines: boolean = true;
  /** 是否显示前奏结束位置指示器 */
  enablePreludeEndPositionIndicator: boolean = true;
  // ========== 其他配置 ==========
  /** 无歌词时显示的文本 */
  labelWhenNoLyrics: string = '暂无歌词';
  /** 文本对齐方式 (0=center, 1=left, 2=right) */
  textGravity: number = 0;

  /**
   * 从 JSON 对象创建配置
   */
  static fromJson(json: ESObject): LyricsViewConfig {
    const config = new LyricsViewConfig();

    // 颜色配置
    if (json.viewBackgroundColor !== undefined) {
      config.viewBackgroundColor = json.viewBackgroundColor as string;
    }
    if (json.currentLineTextColor !== undefined) {
      config.currentLineTextColor = json.currentLineTextColor as string;
    }
    if (json.currentLineHighlightedTextColor !== undefined) {
      config.currentLineHighlightedTextColor =
        json.currentLineHighlightedTextColor as string;
    }
    if (json.previousLineTextColor !== undefined) {
      config.previousLineTextColor = json.previousLineTextColor as string;
    }
    if (json.upcomingLineTextColor !== undefined) {
      config.upcomingLineTextColor = json.upcomingLineTextColor as string;
    }
    if (json.preludeEndPositionIndicatorColor !== undefined) {
      config.preludeEndPositionIndicatorColor =
        json.preludeEndPositionIndicatorColor as string;
    }

    // 文本大小配置
    if (json.textSize !== undefined) {
      config.textSize = json.textSize as number;
    }
    if (json.currentLineTextSize !== undefined) {
      config.currentLineTextSize = json.currentLineTextSize as number;
    }

    // 间距配置
    if (json.lineSpacing !== undefined) {
      config.lineSpacing = json.lineSpacing as number;
    }
    if (json.paddingTop !== undefined) {
      config.paddingTop = json.paddingTop as number;
    }
    if (json.preludeEndPositionIndicatorPaddingTop !== undefined) {
      config.preludeEndPositionIndicatorPaddingTop =
        json.preludeEndPositionIndicatorPaddingTop as number;
    }
    if (json.preludeEndPositionIndicatorRadius !== undefined) {
      config.preludeEndPositionIndicatorRadius =
        json.preludeEndPositionIndicatorRadius as number;
    }

    // 功能开关配置
    if (json.enableLineWrap !== undefined) {
      config.enableLineWrap = json.enableLineWrap as boolean;
    }
    if (json.enableDragging !== undefined) {
      config.enableDragging = json.enableDragging as boolean;
    }
    if (json.enableOpacityEffect !== undefined) {
      config.enableOpacityEffect = json.enableOpacityEffect as boolean;
    }
    if (json.enablePreviousLines !== undefined) {
      config.enablePreviousLines = json.enablePreviousLines as boolean;
    }
    if (json.enableUpcomingLines !== undefined) {
      config.enableUpcomingLines = json.enableUpcomingLines as boolean;
    }
    if (json.enablePreludeEndPositionIndicator !== undefined) {
      config.enablePreludeEndPositionIndicator =
        json.enablePreludeEndPositionIndicator as boolean;
    }

    // 其他配置
    if (json.labelWhenNoLyrics !== undefined) {
      config.labelWhenNoLyrics = json.labelWhenNoLyrics as string;
    }
    if (json.textGravity !== undefined) {
      config.textGravity = json.textGravity as number;
    }

    return config;
  }

  /**
   * 转换为 JSON 对象
   */
  toJson(): ESObject {
    return {
      // 颜色配置
      viewBackgroundColor: this.viewBackgroundColor,
      currentLineTextColor: this.currentLineTextColor,
      currentLineHighlightedTextColor: this.currentLineHighlightedTextColor,
      previousLineTextColor: this.previousLineTextColor,
      upcomingLineTextColor: this.upcomingLineTextColor,
      preludeEndPositionIndicatorColor: this.preludeEndPositionIndicatorColor,

      // 文本大小配置
      textSize: this.textSize,
      currentLineTextSize: this.currentLineTextSize,

      // 间距配置
      lineSpacing: this.lineSpacing,
      paddingTop: this.paddingTop,
      preludeEndPositionIndicatorPaddingTop: this.preludeEndPositionIndicatorPaddingTop,
      preludeEndPositionIndicatorRadius: this.preludeEndPositionIndicatorRadius,

      // 功能开关配置
      enableLineWrap: this.enableLineWrap,
      enableDragging: this.enableDragging,
      enableOpacityEffect: this.enableOpacityEffect,
      enablePreviousLines: this.enablePreviousLines,
      enableUpcomingLines: this.enableUpcomingLines,
      enablePreludeEndPositionIndicator: this.enablePreludeEndPositionIndicator,

      // 其他配置
      labelWhenNoLyrics: this.labelWhenNoLyrics,
      textGravity: this.textGravity
    };
  }

  /**
   * 复制配置
   */
  copy(): LyricsViewConfig {
    return LyricsViewConfig.fromJson(this.toJson());
  }
}
