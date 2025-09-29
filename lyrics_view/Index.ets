export { IKaraokeEvent } from './src/main/ets/IKaraokeEvent';

export { IScoringAlgorithm } from './src/main/ets/IScoringAlgorithm';

export { KaraokeView } from './src/main/ets/KaraokeView';

export { LyricsView } from './src/main/ets/components/LyricsView';

export { ScoringView } from './src/main/ets/components/ScoringView';

export { Constants } from './src/main/ets/constants/Constants';

export { LyricType } from './src/main/ets/constants/LyricType';

export { LyricMachine, OnLyricListener } from './src/main/ets/internal/LyricMachine';

export { OnScoringListener, ScoringMachine } from './src/main/ets/internal/ScoringMachine';

export { LyricsParser } from './src/main/ets/internal/parser/LyricsParser';

export { DefaultScoringAlgorithm } from './src/main/ets/internal/scoring/DefaultScoringAlgorithm';

export { LyricModel } from './src/main/ets/model/LyricModel';

export { Lang, LyricsLineModel, Monolog, Tone } from './src/main/ets/model/LyricsLineModel';

export { PitchData, createPitchData } from './src/main/ets/model/PitchData';

export { Pitch, PitchLineModel, TimePair } from './src/main/ets/model/PitchLineModel';

export { LogUtils } from './src/main/ets/utils/LogUtils';

export { LyricsCutter } from './src/main/ets/utils/LyricsCutter';

export { Utils } from './src/main/ets/utils/Utils';

// 导出构建信息
export { default as BuildProfile } from './BuildProfile';

// 导出项目配置
export {
  AUTHOR,
  DESCRIPTION,
  FULL_HAR_NAME,
  HAR_NAME,
  IS_SDK_MODE,
  IS_SOURCE_MODE,
  LICENSE,
  OUTPUT_DIR,
  PROJECT_NAME,
  ProjectConfig,
  REPOSITORY,
  SDK_MODE,
  SIGNING_ENABLED,
  VERSION,
  VERSION_NAME,
  getBuildInfo,
  getConfigSummary,
  getModeDescription,
  getSdkInfo,
  getVersionInfo,
  isUsingSdk
} from './src/main/ets/config/ProjectConfig';

// 导出下载器相关类
export {
  DownloadError,
  DownloadErrorDetail,
  DownloadLyricModel,
  HttpUrlRequest,
  LyricsFileDownloader,
  LyricsFileDownloaderCallback,
  RequestCallback
} from './src/main/ets/downloader/index';

