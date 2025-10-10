import { common } from '@kit.AbilityKit';
import { MusicContentCenterVendorId } from '@shengwang/rtc-full';
import { IMccCallback } from '../interfaces/IMccCallback';
import { MusicManager, PlaybackStatus } from '../managers/MusicManager';
import { PlaybackState } from '../models/PlaybackState';
import { SongInfo } from '../models/SongInfo';
import { UIState } from '../models/UIState';
import { LyricsService } from '../services/LyricsService';
import { ContextManager } from '../utils/ContextManager';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';
import { KeyCenter, TokenCallback, TokenResponse, YSDTokenCallback, YSDTokenResponse } from '../utils/KeyCenter';
import { PermissionUtil } from '../utils/PermissionUtil';
import { BaseViewModel } from './BaseViewModel';

import { IKaraokeEvent, KaraokeView, LyricModel, LyricsLineModel } from '@shengwang/lyrics-view';

/**
 * MCC Karaoke ViewModel
 * Integrates MCC music playback and lyrics display functionality
 */
@ObservedV2
export class MccKaraokeViewModel extends BaseViewModel implements IMccCallback {
  protected readonly TAG: string = 'LyricsView-MccKaraokeViewModel';
  // Reactive state models
  @Trace playbackState: PlaybackState = new PlaybackState();
  @Trace songInfo: SongInfo = new SongInfo();
  @Trace uiState: UIState = new UIState();
  // Scoring state
  @Trace currentLineIndex: number = 0;
  @Trace totalLines: number = 0;
  @Trace currentLineScore: number = 0;
  @Trace totalScore: number = 0;
  // Service dependencies
  private lyricsService: LyricsService;
  public musicManager: MusicManager;
  // KaraokeView instance
  private karaokeView: KaraokeView | null = null;
  // Configuration information - obtained from KeyCenter
  public appId: string = KeyCenter.APP_ID;
  public rtcToken: string = "";
  public rtmToken: string = "";
  public userId: string = "";
  public ysdAppId: string = KeyCenter.VENDOR_2_APP_ID;
  public ysdAppKey: string = KeyCenter.VENDOR_2_APP_KEY;
  public ysdUserId: string = "";
  public ysdToken: string = "";
  // Current service type
  private currentVendorId: MusicContentCenterVendorId = MusicContentCenterVendorId.DEFAULT;

  constructor() {
    super();
    this.lyricsService = new LyricsService();
    this.musicManager = new MusicManager();
  }

  /**
   * Initialize ViewModel
   */
  async initialize(): Promise<void> {
    await super.initialize();

    // 首先检查权限状态
    await this.safeExecute(
      () => this.checkPermissionsAndInitialize(),
      () => {
        ExampleLogUtils.logDebug(this.TAG, 'ViewModel initialization completed successfully');
      },
      (error) => {
        this.uiState.setError(`Initialization failed: ${error.message}`);
      }
    );
  }

  /**
   * 检查权限并初始化MCC Karaoke系统
   */
  private async checkPermissionsAndInitialize(): Promise<void> {
    const context = ContextManager.getInstance().getContext();
    if (!context) {
      throw new Error('Application context not available');
    }

    ExampleLogUtils.logDebug(this.TAG, 'Checking permissions before initializing MCC Karaoke');

    // 检查必需权限
    const hasEssentialPermissions = await PermissionUtil.hasEssentialPermissions(context);

    if (!hasEssentialPermissions) {
      // 尝试申请权限
      ExampleLogUtils.logDebug(this.TAG, 'Essential permissions not granted, requesting permissions');
      const result = await PermissionUtil.requestEssentialPermissions(context);
      PermissionUtil.logPermissionResult(result);

      if (!result.success) {
        throw new Error(`权限申请失败: ${result.message}`);
      }
    }

    // 权限检查通过，初始化MCC Karaoke
    ExampleLogUtils.logDebug(this.TAG, 'Permissions verified, initializing MCC Karaoke');
    await this.initializeMccKaraoke();

    this.uiState.setSuccess('歌词组件初始化成功');
    this.musicManager.joinChannel();
  }

  /**
   * Initialize MCC Karaoke system
   */
  private async initializeMccKaraoke(): Promise<void> {
    ExampleLogUtils.logDebug(this.TAG, 'Initializing MCC Karaoke');
    // 1. Create KaraokeView
    this.karaokeView = new KaraokeView();

    // 2. Setup KaraokeView event listeners
    this.setupKaraokeViewEvents();

    // 3. Setup lyrics service
    this.lyricsService.setKaraokeView(this.karaokeView);

    // 4. Get tokens and initialize music manager
    const context = ContextManager.getInstance().getContext();
    if (!context) {
      throw new Error('Application context not available');
    }

    await this.initializeWithTokens(context);

    // 5. Update current song information
    this.updateCurrentSongInfo();

    ExampleLogUtils.logDebug(this.TAG, 'MCC Karaoke initialized successfully');
  }

  /**
   * Setup KaraokeView event listeners
   */
  private setupKaraokeViewEvents(): void {
    if (!this.karaokeView) {
      return;
    }

    const eventHandler: IKaraokeEvent = new MccKaraokeEventImpl(this);
    this.karaokeView.setKaraokeEvent(eventHandler);
  }

  /**
   * Get tokens and initialize music manager
   */
  private async initializeWithTokens(context: common.UIAbilityContext): Promise<void> {
    ExampleLogUtils.logDebug(this.TAG, 'Starting token initialization');

    // Get user ID
    this.userId = KeyCenter.getUserUid().toString();
    const channelName = KeyCenter.CHANNEL_NAME;

    ExampleLogUtils.logDebug(this.TAG, `Using userId: ${this.userId}, channel: ${channelName}`);

    return new Promise((resolve, reject) => {
      let rtcTokenReceived = false;
      let rtmTokenReceived = false;
      let ysdTokenReceived = false;
      let hasError = false;

      const checkComplete = () => {
        if ((rtcTokenReceived && rtmTokenReceived && ysdTokenReceived) || hasError) {
          if (!hasError) {
            ExampleLogUtils.logDebug(this.TAG, 'All tokens received, initializing MusicManager');
            this.musicManager.init(context, this.appId, KeyCenter.CHANNEL_NAME, this.rtcToken,
              this.rtmToken,
              this.userId,
              this.ysdAppId, this.ysdAppKey, this.ysdUserId, this.ysdToken, this)
              .then(() => resolve())
              .catch((error: Error) => reject(error));
          }
        }
      };

      // Get RTC Token
      const rtcTokenCallback = new RtcTokenCallbackImpl(this, () => {
        rtcTokenReceived = true;
      }, checkComplete);
      KeyCenter.getRtcTokenV6(channelName, KeyCenter.getUserUid(), rtcTokenCallback);

      // Get RTM Token
      const rtmTokenCallback = new RtmTokenCallbackImpl(this, () => {
        rtmTokenReceived = true;
      }, checkComplete);
      KeyCenter.getRtmToken(KeyCenter.getUserUid(), rtmTokenCallback);

      // Get YSD Token
      const ysdTokenCallback = new YSDTokenCallbackImpl(this, () => {
        ysdTokenReceived = true;
      }, checkComplete);
      KeyCenter.getYSDToken(KeyCenter.getUserUid(), ysdTokenCallback);

      // Set timeout
      setTimeout(() => {
        if (!rtcTokenReceived || !rtmTokenReceived || !ysdTokenReceived) {
          hasError = true;
          ExampleLogUtils.logError(this.TAG, 'Token initialization timeout');
          reject(new Error('Token initialization timeout'));
        }
      }, 15000); // 15 seconds timeout
    });
  }

  /**
   * Update current song information
   */
  private updateCurrentSongInfo(): void {
    const currentMusic = this.musicManager.getCurrentMusicInfo();
    if (currentMusic) {
      this.songInfo.name = currentMusic.songName;
    }

    this.songInfo.vendorName = this.getVendorName();
  }

  public getVendorName(): string {
    switch (this.currentVendorId) {
      case MusicContentCenterVendorId.DEFAULT:
        return "Default (音集协)";
      case MusicContentCenterVendorId.VENDOR_2:
        return "Vendor2 (音速达)";
      default:
        return "Unknown Vendor";
    }
  }

  /**
   * Start playback
   */
  startPlayback(): void {
    ExampleLogUtils.logDebug(this.TAG, 'startPlayback');
    if (this.musicManager.isPaused()) {
      this.uiState.setLoading(false, 'Playing music...');
      this.playbackState.isPlaying = true;
    } else {
      this.uiState.setLoading(true, 'Loading music...');
    }
    this.musicManager.playMusic();
  }

  /**
   * Pause playback
   */
  pausePlayback(): void {
    this.musicManager.pauseOrResumeMusic();
  }

  /**
   * Stop playback
   */
  stopPlayback(): void {
    ExampleLogUtils.logDebug(this.TAG, 'stopPlayback');
    this.musicManager.stopMusic();
    this.playbackState.reset();
    this.karaokeView?.reset();
    this.resetScoringState();
  }

  /**
   * Switch to next song
   */
  switchToNext(): void {
    ExampleLogUtils.logDebug(this.TAG, 'switchToNext');
    this.stopPlayback();
    this.musicManager.switchMusic();
    this.updateCurrentSongInfo();
    this.resetScoringState();
    this.uiState.setSuccess('切歌');
  }

  /**
   * Skip intro
   */
  skipIntro(): void {
    ExampleLogUtils.logDebug(this.TAG, 'skipIntro');
    // Jump to lyrics start position
    if (this.karaokeView) {
      const preludeEnd = this.lyricsService.getPreludeEndPosition();
      if (preludeEnd > 0) {
        this.musicManager.seekMusic(preludeEnd);
        this.uiState.setSuccess(`跳过前奏 ${preludeEnd}ms`);
      } else {
        this.uiState.callBackInfo = '当前歌曲没有前奏';
      }
    }
  }

  /**
   * Toggle original/accompaniment track
   */
  toggleOriginalTrack(): void {
    ExampleLogUtils.logDebug(this.TAG, 'toggleOriginalTrack');
    this.musicManager.switchPlayOriginal();
    this.playbackState.isOriginalTrack = this.musicManager.isOriginalMode();

    const mode = this.musicManager.isOriginalMode() ? 'Original' : 'Accompaniment';
    this.uiState.setSuccess(`原唱/伴唱切到 ${mode} 模式`);
  }

  /**
   * Switch service type
   */
  switchServiceType(): void {
    ExampleLogUtils.logDebug(this.TAG, 'switchServiceType');

    // Stop current playback first
    this.stopPlayback();

    this.karaokeView?.reset();

    // Switch service type
    this.currentVendorId =
      this.currentVendorId === MusicContentCenterVendorId.DEFAULT ? MusicContentCenterVendorId.VENDOR_2 :
      MusicContentCenterVendorId.DEFAULT;
    this.musicManager.updateMusicVendor(this.currentVendorId);

    // Update song information
    this.updateCurrentSongInfo();

    const typeName = this.getVendorName();
    this.uiState.setSuccess(`vendor切到 ${typeName}`); // API may not exist

    this.songInfo.vendorName = typeName;
  }

  // ==================== IMccCallback Implementation ====================

  /**
   * Music lyrics request callback
   */
  onMusicLyricRequest(
    songCode: bigint,
    lyricUrl: string,
    pitchUrl: string,
    songOffsetBegin: number,
    songOffsetEnd: number,
    lyricOffset: number
  ): void {
    // Load lyrics asynchronously
    this.loadLyricsFromMcc(lyricUrl, pitchUrl, songOffsetBegin, songOffsetEnd, lyricOffset);
  }

  /**
   * Load lyrics from MCC
   */
  private async loadLyricsFromMcc(
    lyricUrl: string,
    pitchUrl: string,
    songOffsetBegin: number,
    songOffsetEnd: number,
    lyricOffset: number
  ): Promise<void> {
    try {
      this.uiState.setLoading(true, 'Loading lyrics...');

      const lyricModel: LyricModel | null = await this.lyricsService.loadLyricsFromMcc(
        lyricUrl,
        pitchUrl,
        songOffsetBegin,
        songOffsetEnd,
        lyricOffset
      );

      if (lyricModel && this.karaokeView) {

        this.songInfo.setLyricModel(lyricModel)

        // Set lyrics data
        this.karaokeView.setLyricData(lyricModel);

        this.uiState.setSuccess('歌词加载成功');
        ExampleLogUtils.logDebug(this.TAG, `Lyrics loaded successfully, duration: ${lyricModel.duration}ms`);
      } else {
        throw new Error('Failed to load lyrics from MCC');
      }
    } catch (error) {
      console.error('Failed to load lyrics from MCC', JSON.stringify(error));
      this.uiState.setError(`Failed to load lyrics: ${error.message}`);
    }
  }

  /**
   * Music preload result callback
   */
  onMusicPreloadResult(songCode: bigint, percent: number): void {
    ExampleLogUtils.logDebug(this.TAG, `onMusicPreloadResult: songCode=${songCode}, percent=${percent}`);
    this.uiState.setLoading(true, `Loading music... ${percent}%`);
  }

  /**
   * Music position change callback
   */
  onMusicPositionChange(position: number): void {
    this.playbackState.updateProgress(position);

    // Update lyrics progress
    if (this.karaokeView) {
      this.karaokeView.setProgress(position);
    }
  }

  /**
   * Music pitch score callback
   */
  onMusicPitchScore(
    internalSongCode: bigint,
    voicePitch: number,
    pitchScore: number,
    progressInMs: number
  ): void {
    // Update pitch data
    this.playbackState.updatePitch(voicePitch);

    // Update KaraokeView pitch
    if (this.karaokeView) {
      this.karaokeView.setPitch(voicePitch, pitchScore);
    }
  }

  /**
   * Music line score callback
   */
  onMusicLineScore(
    internalSongCode: bigint,
    linePitchScore: number,
    cumulativeTotalLinePitchScores: number,
    performedLineIndex: number,
    performedTotalLines: number
  ): void {
    ExampleLogUtils.logDebug(this.TAG,
      `onMusicLineScore: line=${performedLineIndex}, score=${linePitchScore}, total=${cumulativeTotalLinePitchScores}`);

    // Update scoring state
    this.currentLineIndex = performedLineIndex;
    this.totalLines = performedTotalLines;
    this.currentLineScore = Math.round(linePitchScore);
    this.totalScore = Math.round(cumulativeTotalLinePitchScores);
  }

  /**
   * Music start playing callback
   */
  onMusicPlaying(): void {
    this.playbackState.setPlayingState(true);
    this.uiState.setSuccess('音乐播放中...');
  }

  onMusicPause(): void {
    this.playbackState.setPlayingState(false);
    this.uiState.callBackInfo = '音乐暂停...';
  }

  /**
   * Music stop playing callback
   */
  onMusicStop(): void {
    ExampleLogUtils.logDebug(this.TAG, 'onMusicStop');
    this.playbackState.setPlayingState(false);
    this.uiState.callBackInfo = '音乐停止播放...';
  }

  /**
   * Music playback error callback
   */
  onMusicError(error: number): void {
    ExampleLogUtils.logError(this.TAG, `onMusicError: error=${error}`);
    this.playbackState.setPlayingState(false);
    this.uiState.setError(`Playback error: ${error}`);
  }

  // ==================== State Management Methods ====================

  /**
   * Reset scoring state
   */
  private resetScoringState(): void {
    this.currentLineIndex = 0;
    this.totalLines = 0;
    this.currentLineScore = 0;
    this.totalScore = 0;
  }

  // ==================== State Query Methods ====================

  /**
   * Get current playback status
   */
  getPlaybackStatus(): PlaybackStatus {
    return this.musicManager.getPlaybackStatus();
  }

  /**
   * Check if channel is joined
   */
  isChannelJoined(): boolean {
    return this.musicManager.isChannelJoined();
  }

  /**
   * Get channel ID
   */
  getChannelId(): string {
    return this.musicManager.getChannelId();
  }


  // ==================== Destroy Methods ====================

  /**
   * Destroy ViewModel
   */
  destroy(): void {
    if (this.checkDestroyed()) {
      return;
    }

    // Stop playback
    this.stopPlayback();

    // Destroy music manager
    this.musicManager.destroy();

    // Destroy KaraokeView
    if (this.karaokeView && !this.karaokeView.getIsDestroyed()) {
      this.karaokeView.destroy();
      this.karaokeView = null;
    }

    super.destroy();
    ExampleLogUtils.logDebug(this.TAG, 'MccKaraokeViewModel destroyed');
  }
}

/**
 * MCC KaraokeEvent implementation class
 */
class MccKaraokeEventImpl implements IKaraokeEvent {
  private viewModel: MccKaraokeViewModel;

  constructor(viewModel: MccKaraokeViewModel) {
    this.viewModel = viewModel;
  }

  onDragTo(position: number): void {
    ExampleLogUtils.logDebug('LyricsView-MccKaraokeEventImpl', `onDragTo: ${position}`);
    this.viewModel.musicManager.seekMusic(position);
  }

  onLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number, index: number, total: number): void {
    ExampleLogUtils.logDebug('LyricsView-MccKaraokeEventImpl',
      `onLineFinished: line=${line}, score=${score}, total=${cumulativeScore}`);
    // Handle line finished event here
  }
}

class RtcTokenCallbackImpl implements TokenCallback {
  private viewModel: MccKaraokeViewModel;
  private rtcTokenReceived: () => void;
  private checkComplete: () => void;

  constructor(viewModel: MccKaraokeViewModel, rtcTokenReceived: () => void, checkComplete: () => void) {
    this.viewModel = viewModel;
    this.rtcTokenReceived = rtcTokenReceived;
    this.checkComplete = checkComplete;
  }

  onTokenGenerated(response: TokenResponse): void {
    if (response.success && response.token) {
      this.viewModel.rtcToken = response.token;
      ExampleLogUtils.logDebug('LyricsView-RtcTokenCallbackImpl',
        `RTC Token received: ${response.token}`);
    } else {
      ExampleLogUtils.logError('LyricsView-RtcTokenCallbackImpl', `RTC Token failed: ${response.error}`);
      this.viewModel.rtcToken = this.viewModel.appId; // Fallback to APP_ID
    }
    this.rtcTokenReceived();
    this.checkComplete();
  }
}

class RtmTokenCallbackImpl implements TokenCallback {
  private viewModel: MccKaraokeViewModel;
  private rtmTokenReceived: () => void;
  private checkComplete: () => void;

  constructor(viewModel: MccKaraokeViewModel, rtmTokenReceived: () => void, checkComplete: () => void) {
    this.viewModel = viewModel;
    this.rtmTokenReceived = rtmTokenReceived;
    this.checkComplete = checkComplete;
  }

  onTokenGenerated(response: TokenResponse): void {
    if (response.success && response.token) {
      this.viewModel.rtmToken = response.token;
      ExampleLogUtils.logDebug('LyricsView-RtmTokenCallbackImpl',
        `RTM Token received: ${response.token.substring(0, 20)}...`);
    } else {
      ExampleLogUtils.logError('LyricsView-RtmTokenCallbackImpl', `RTM Token failed: ${response.error}`);
      this.viewModel.rtmToken = this.viewModel.appId; // Fallback to APP_ID
    }
    this.rtmTokenReceived();
    this.checkComplete();
  }
}

class YSDTokenCallbackImpl implements YSDTokenCallback {
  private viewModel: MccKaraokeViewModel;
  private ysdTokenReceived: () => void;
  private checkComplete: () => void;

  constructor(viewModel: MccKaraokeViewModel, ysdTokenReceived: () => void, checkComplete: () => void) {
    this.viewModel = viewModel;
    this.ysdTokenReceived = ysdTokenReceived;
    this.checkComplete = checkComplete;
  }

  onYSDTokenGenerated(response: YSDTokenResponse): void {
    if (response.success && response.ysdUserId && response.ysdToken) {
      this.viewModel.ysdUserId = response.ysdUserId;
      this.viewModel.ysdToken = response.ysdToken;
      ExampleLogUtils.logDebug('LyricsView-YSDTokenCallbackImpl',
        `YSD Token received - userId: ${response.ysdUserId}, token: ${response.ysdToken.substring(0, 20)}...`);
    } else {
      ExampleLogUtils.logError('LyricsView-YSDTokenCallbackImpl', `YSD Token failed: ${response.error}`);
      // Use default values
      this.viewModel.ysdUserId = "";
      this.viewModel.ysdToken = "";
    }
    this.ysdTokenReceived();
    this.checkComplete();
  }
}
