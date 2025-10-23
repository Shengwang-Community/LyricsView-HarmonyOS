/**
 * ScoringView 配置类
 * 管理 ScoringView 组件的所有可配置属性
 */
export class ScoringViewConfig {
  // ========== 颜色配置 ==========
  /** 视图背景颜色 */
  viewBackgroundColor: string = '#ffffbb33';
  /** 导航线颜色 */
  leadingLinesColor: string = '#4DFFFFFF';
  /** 音高指示器颜色 */
  pitchIndicatorColor: string = '#F0F0F0F0';
  /** 本地音高指示器颜色 */
  localPitchIndicatorColor: string = '#F0F0F0F0';
  /** 参考音高条默认颜色 */
  refPitchStickDefaultColor: string = '#99FFFFFF';
  /** 高亮音高条颜色 */
  highlightedPitchStickColor: string = '#FFF44336';
  // ========== 尺寸配置 ==========
  /** 导航线高度 */
  leadingLinesHeight: number = 1;
  /** 音高指示器宽度 */
  pitchIndicatorWidth: number = 3;
  /** 本地音高指示器半径 */
  localPitchIndicatorRadius: number = 8;
  /** 音高条高度 */
  pitchStickHeight: number = 4;
  /** 音高条圆角半径 */
  pitchStickRadius: number = 4;
  // ========== 行为配置 ==========
  /** 初始分数 */
  initialScore: number = 0;
  /** 每毫秒移动像素数 */
  movingPixelsPerMs: number = 0.2;
  /** 命中分数阈值 */
  hitScoreThreshold: number = 0.7;
  /** 起点水平偏移比例 */
  startPointHorizontalBias: number = 0.4;
  /** 是否启用粒子效果 */
  enableParticleEffect: boolean = true;

  /**
   * 从 JSON 对象创建配置
   */
  static fromJson(json: ESObject): ScoringViewConfig {
    const config = new ScoringViewConfig();

    // 颜色配置
    if (json.viewBackgroundColor !== undefined) {
      config.viewBackgroundColor = json.viewBackgroundColor as string;
    }
    if (json.leadingLinesColor !== undefined) {
      config.leadingLinesColor = json.leadingLinesColor as string;
    }
    if (json.pitchIndicatorColor !== undefined) {
      config.pitchIndicatorColor = json.pitchIndicatorColor as string;
    }
    if (json.localPitchIndicatorColor !== undefined) {
      config.localPitchIndicatorColor = json.localPitchIndicatorColor as string;
    }
    if (json.refPitchStickDefaultColor !== undefined) {
      config.refPitchStickDefaultColor = json.refPitchStickDefaultColor as string;
    }
    if (json.highlightedPitchStickColor !== undefined) {
      config.highlightedPitchStickColor = json.highlightedPitchStickColor as string;
    }

    // 尺寸配置
    if (json.leadingLinesHeight !== undefined) {
      config.leadingLinesHeight = json.leadingLinesHeight as number;
    }
    if (json.pitchIndicatorWidth !== undefined) {
      config.pitchIndicatorWidth = json.pitchIndicatorWidth as number;
    }
    if (json.localPitchIndicatorRadius !== undefined) {
      config.localPitchIndicatorRadius = json.localPitchIndicatorRadius as number;
    }
    if (json.pitchStickHeight !== undefined) {
      config.pitchStickHeight = json.pitchStickHeight as number;
    }
    if (json.pitchStickRadius !== undefined) {
      config.pitchStickRadius = json.pitchStickRadius as number;
    }

    // 行为配置
    if (json.initialScore !== undefined) {
      config.initialScore = json.initialScore as number;
    }
    if (json.movingPixelsPerMs !== undefined) {
      config.movingPixelsPerMs = json.movingPixelsPerMs as number;
    }
    if (json.hitScoreThreshold !== undefined) {
      config.hitScoreThreshold = json.hitScoreThreshold as number;
    }
    if (json.startPointHorizontalBias !== undefined) {
      config.startPointHorizontalBias = json.startPointHorizontalBias as number;
    }
    if (json.enableParticleEffect !== undefined) {
      config.enableParticleEffect = json.enableParticleEffect as boolean;
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
      leadingLinesColor: this.leadingLinesColor,
      pitchIndicatorColor: this.pitchIndicatorColor,
      localPitchIndicatorColor: this.localPitchIndicatorColor,
      refPitchStickDefaultColor: this.refPitchStickDefaultColor,
      highlightedPitchStickColor: this.highlightedPitchStickColor,

      // 尺寸配置
      leadingLinesHeight: this.leadingLinesHeight,
      pitchIndicatorWidth: this.pitchIndicatorWidth,
      localPitchIndicatorRadius: this.localPitchIndicatorRadius,
      pitchStickHeight: this.pitchStickHeight,
      pitchStickRadius: this.pitchStickRadius,

      // 行为配置
      initialScore: this.initialScore,
      movingPixelsPerMs: this.movingPixelsPerMs,
      hitScoreThreshold: this.hitScoreThreshold,
      startPointHorizontalBias: this.startPointHorizontalBias,
      enableParticleEffect: this.enableParticleEffect
    };
  }

  /**
   * 复制配置
   */
  copy(): ScoringViewConfig {
    return ScoringViewConfig.fromJson(this.toJson());
  }
}
