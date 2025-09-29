import { common } from '@kit.AbilityKit';
import { Constants, MusicContentCenterVendorId } from '@shengwang/rtc-full';
import { IMccCallback } from '../interfaces/IMccCallback';
import { ExampleConstants } from '../utils/ExampleConstants';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';
import { MusicResource, MusicResourcePool } from '../utils/MusicResourcePool';
import { RtcMccManager } from './RtcMccManager';

/**
 * Playback status enumeration
 */
export enum PlaybackStatus {
  IDLE = 0,
  LOADING = 1,
  OPENED = 2,
  PLAYING = 3,
  PAUSED = 4,
  STOPPED = 5,
  COMPLETED = 6,
  ERROR = 7
}

/**
 * Music playback manager
 * Responsible for coordinating music playback status, lyrics synchronization and UI updates
 */
export class MusicManager implements IMccCallback {
  private static readonly TAG = ExampleConstants.APP_TAG + "-MusicManager";
  private static readonly MUSIC_POSITION_UPDATE_INTERVAL = 20; // 20ms update interval

  // Core components
  private rtcMccManager: RtcMccManager | null = null;
  // Playback status
  private status: PlaybackStatus = PlaybackStatus.IDLE;
  private playPosition: number = 0;
  private lyricsCurrentProgress: number = 0;
  private songOffsetBegin: number = 0;
  // Music configuration
  private lyricType: Constants.LyricSourceType = 0; // LYRIC_SOURCE_XML = 0
  private musicPlayMode: Constants.MusicPlayMode = Constants.MusicPlayMode.ORIGINAL;
  private isOriginal: boolean = true;
  // Music resources
  private musicResources: MusicResource[] = [];
  private currentSongIndex: number = 0;
  // Timer
  private positionUpdateTimer: number | null = null;
  // Callback interface
  private callback: IMccCallback | null = null;

  /**
   * Initialize music manager
   * @param context - Application context
   * @param appId - Agora App ID
   * @param rtcToken - RTC Token
   * @param rtmToken - RTM Token
   * @param userId - User ID
   * @param ysdAppId - YinSuDa App ID
   * @param ysdAppKey - YinSuDa App Key
   * @param ysdUserId - YinSuDa User ID
   * @param ysdToken - YinSuDa Token
   * @param callback - Callback interface
   */
  async init(context: common.UIAbilityContext, appId: string, channelId: string, rtcToken: string, rtmToken: string,
    userId: string,
    ysdAppId: string, ysdAppKey: string, ysdUserId: string, ysdToken: string, callback: IMccCallback): Promise<void> {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager init - userId: ${userId}, ysdUserId: ${ysdUserId}`);
    this.callback = callback;
    this.initData();

    this.rtcMccManager = new RtcMccManager();
    await this.rtcMccManager.init(context, appId, channelId, rtcToken, rtmToken, userId, ysdAppId, ysdAppKey, ysdUserId,
      ysdToken,
      this);

    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager init completed`);
  }

  /**
   * Initialize data
   */
  private initData(): void {
    this.musicResources = MusicResourcePool.getVendor1MusicList();
    this.currentSongIndex = 0;
    this.status = PlaybackStatus.IDLE;
  }

  /**
   * Update music service type
   * @param serviceType - Service type
   */
  updateMusicVendor(vendorId: MusicContentCenterVendorId): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `updateMusicVendor:${vendorId}`);

    this.currentSongIndex = 0;

    switch (vendorId) {
      case MusicContentCenterVendorId.DEFAULT:
        this.lyricType = Constants.LyricSourceType.XML;
        this.musicPlayMode = Constants.MusicPlayMode.ORIGINAL;
        this.musicResources = MusicResourcePool.getVendor1MusicList();
        break;
      case MusicContentCenterVendorId.VENDOR_2:
        this.lyricType = Constants.LyricSourceType.KRC;
        this.musicPlayMode = Constants.MusicPlayMode.ORIGINAL;
        this.musicResources = MusicResourcePool.getVendor2MusicList();
        break;
    }
    this.playMusic();
  }

  /**
   * Join channel
   */
  joinChannel(): void {
    this.rtcMccManager?.joinChannel();
  }

  /**
   * Leave channel
   */
  leaveChannel(): void {
    this.rtcMccManager?.leaveChannel();
  }

  /**
   * Play music
   */
  playMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager playMusic`);

    if (this.status === PlaybackStatus.PAUSED || this.status === PlaybackStatus.PLAYING) {
      this.pauseOrResumeMusic();
      return;
    }


    if (this.musicResources.length === 0) {
      console.error(`${MusicManager.TAG} no music resources available`);
      return;
    }

    this.isOriginal = true;
    this.lyricsCurrentProgress = 0;
    this.setPlayMode(Constants.MusicPlayMode.ORIGINAL);

    const currentMusic = this.musicResources[this.currentSongIndex];

    // Set lyrics type based on vendor
    if (currentMusic.vendorId === MusicContentCenterVendorId.VENDOR_2) {
      //TODO LyricType 0: xml 1: lrc 2: lrc with pitches 3: krc
      this.lyricType = Constants.LyricSourceType.KRC; // LYRIC_SOURCE_KRC = 1
    }

    this.status = PlaybackStatus.LOADING;

    this.rtcMccManager?.preloadMusic(
      currentMusic.songCode,
      currentMusic.vendorId,
      currentMusic.songOptionJson
    );
  }

  /**
   * Start playing (through scoring system)
   */
  private openMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager openMusic`);

    if (this.musicResources.length === 0) {
      console.error(`${MusicManager.TAG} no music resources available`);
      return;
    }

    const currentMusic = this.musicResources[this.currentSongIndex];

    this.rtcMccManager?.startScore(
      currentMusic.vendorId,
      currentMusic.songCode,
      currentMusic.songOptionJson
    );
  }

  /**
   * Stop music
   */
  stopMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager stopMusic`);

    if (this.status === PlaybackStatus.IDLE) {
      return;
    }

    this.lyricsCurrentProgress = 0;
    this.status = PlaybackStatus.IDLE;
    this.stopDisplayLrc();

    this.rtcMccManager?.stop();
  }

  /**
   * Pause music
   */
  private pauseMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager pauseMusic`);

    if (this.status !== PlaybackStatus.PLAYING) {
      return;
    }

    this.status = PlaybackStatus.PAUSED;
    this.rtcMccManager?.pause();
  }

  /**
   * Resume music
   */
  private resumeMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager resumeMusic`);

    if (this.status !== PlaybackStatus.PAUSED) {
      return;
    }

    this.status = PlaybackStatus.PLAYING;
    this.rtcMccManager?.resume();
  }

  /**
   * Pause or resume music
   */
  pauseOrResumeMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager pauseOrResumeMusic status:${this.status}`);

    if (this.status === PlaybackStatus.PLAYING) {
      this.pauseMusic();
    } else if (this.status === PlaybackStatus.PAUSED) {
      this.resumeMusic();
    }
  }

  /**
   * Seek music position
   * @param position - Target position (ms)
   */
  seekMusic(position: number): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager seekMusic:${position}`);
    this.lyricsCurrentProgress = position;
    this.rtcMccManager?.seek(position);
    this.updateMusicPosition(position);
  }

  /**
   * Switch between original and accompaniment
   */
  switchPlayOriginal(): void {
    if (this.isOriginal) {
      this.isOriginal = false;
      this.setPlayMode(Constants.MusicPlayMode.ACCOMPANY);
    } else {
      this.isOriginal = true;
      this.setPlayMode(Constants.MusicPlayMode.ORIGINAL);
    }
  }

  /**
   * Switch to next song
   */
  switchMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager switchMusic`);

    this.lyricsCurrentProgress = 0;
    this.rtcMccManager?.stop();

    this.currentSongIndex++;
    if (this.currentSongIndex >= this.musicResources.length) {
      this.currentSongIndex = 0;
    }

    this.playMusic();
  }

  /**
   * Set play mode
   */
  private setPlayMode(playMode: Constants.MusicPlayMode): void {
    const ret = this.rtcMccManager?.setPlayMode(playMode);
    if (ret === 0) {
      this.musicPlayMode = playMode;
    }
  }

  /**
   * Start displaying lyrics (start position update timer)
   */
  private startDisplayLrc(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager startDisplayLrc`);

    this.playPosition = -1;

    this.positionUpdateTimer = setInterval(() => {
      if (this.status === PlaybackStatus.PLAYING) {
        this.playPosition = this.rtcMccManager?.getPlayPosition() || 0;
        this.playPosition += this.songOffsetBegin;

        // if (this.playPosition === -1 || this.playPosition % 1000 < MusicManager.MUSIC_POSITION_UPDATE_INTERVAL) {
        //   this.playPosition = this.rtcMccManager?.getPlayPosition() || 0;
        //   this.playPosition += this.songOffsetBegin;
        //   this.playPosition += MusicManager.MUSIC_POSITION_UPDATE_INTERVAL;
        // } else {
        //   this.playPosition += MusicManager.MUSIC_POSITION_UPDATE_INTERVAL;
        // }

        this.callback?.onMusicPositionChange?.(this.playPosition);
      }
    }, MusicManager.MUSIC_POSITION_UPDATE_INTERVAL);
  }

  /**
   * Stop displaying lyrics (clear position update timer)
   */
  private stopDisplayLrc(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager stopDisplayLrc`);

    if (this.positionUpdateTimer !== null) {
      clearInterval(this.positionUpdateTimer);
      this.positionUpdateTimer = null;
    }
  }

  /**
   * Update music position
   */
  private updateMusicPosition(position: number): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager updateMusicPosition:${position}`);
    if (this.status === PlaybackStatus.PLAYING) {
      this.playPosition = position;
    }
  }

  /**
   * Reset status
   */
  private reset(): void {
    this.status = PlaybackStatus.IDLE;
    this.stopDisplayLrc();
  }

  /**
   * Clear cache
   */
  clearCache(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager clearCache`);
    this.rtcMccManager?.clearCache();
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
    ExampleLogUtils.logDebug(MusicManager.TAG, `onMusicLyricRequest songCode:${songCode} lyricUrl:${lyricUrl}`);

    this.songOffsetBegin = songOffsetBegin;

    // Forward to external callback
    this.callback?.onMusicLyricRequest?.(songCode, lyricUrl, pitchUrl, songOffsetBegin, songOffsetEnd, lyricOffset);
  }

  /**
   * Music preload result callback
   */
  onMusicPreloadResult(songCode: bigint, percent: number): void {
    this.callback?.onMusicPreloadResult?.(songCode, percent);

    // Start playing after preload is complete
    if (percent === 100) {
      this.openMusic();
    }
  }

  /**
   * Music position change callback
   */
  onMusicPositionChange(position: number): void {
    // Handled by timer, no implementation needed here
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
    this.callback?.onMusicPitchScore?.(internalSongCode, voicePitch, pitchScore, progressInMs);
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
    this.callback?.onMusicLineScore?.(
      internalSongCode,
      linePitchScore,
      cumulativeTotalLinePitchScores,
      performedLineIndex,
      performedTotalLines
    );
  }

  /**
   * Music start playing callback
   */
  onMusicPlaying(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `onMusicPlaying`);

    this.status = PlaybackStatus.PLAYING;
    this.startDisplayLrc();

    this.callback?.onMusicPlaying?.();
  }

  onMusicPause(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `onMusicPaused`);

    this.status = PlaybackStatus.PAUSED;

    this.callback?.onMusicPause?.();
  }

  /**
   * Music stop playing callback
   */
  onMusicStop(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `onMusicStop`);

    if (this.status !== PlaybackStatus.IDLE) {
      this.status = PlaybackStatus.STOPPED;
    }

    this.stopDisplayLrc();
    this.callback?.onMusicStop?.();
  }

  /**
   * Music playback error callback
   */
  onMusicError(error: number): void {
    console.error(`${MusicManager.TAG} MusicManager onMusicError:${error}`);

    this.status = PlaybackStatus.ERROR;
    this.stopDisplayLrc();

    this.callback?.onMusicError?.(error);
  }

  /**
   * Check if music is playing
   */
  isPlaying(): boolean {
    return this.status === PlaybackStatus.PLAYING;
  }

  /**
   * Check if music is paused
   */
  isPaused(): boolean {
    return this.status === PlaybackStatus.PAUSED;
  }

  /**
   * Check if in original mode
   */
  isOriginalMode(): boolean {
    return this.isOriginal;
  }

  isChannelJoined(): boolean {
    return this.rtcMccManager?.isChannelJoined() || false;
  }

  /**
   * Get current music information
   */
  getCurrentMusicInfo(): MusicResource | null {
    if (this.currentSongIndex >= 0 && this.currentSongIndex < this.musicResources.length) {
      return this.musicResources[this.currentSongIndex];
    }
    return null;
  }

  /**
   * Get playback status
   */
  getPlaybackStatus(): PlaybackStatus {
    return this.status;
  }

  /**
   * Get lyrics current progress
   */
  getLyricsCurrentProgress(): number {
    return this.lyricsCurrentProgress;
  }

  /**
   * Set lyrics current progress
   */
  setLyricsCurrentProgress(progress: number): void {
    this.lyricsCurrentProgress = progress;
  }

  /**
   * Get lyric type
   */
  getLyricType(): Constants.LyricSourceType {
    return this.lyricType;
  }

  /**
   * Set lyric type
   */
  setLyricType(lyricType: Constants.LyricSourceType): void {
    this.lyricType = lyricType;
  }

  /**
   * Get channel ID
   */
  getChannelId(): string {
    return this.rtcMccManager?.getChannelId() || "";
  }

  /**
   * Destroy manager
   */
  destroy(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager destroy`);

    this.stopDisplayLrc();
    this.rtcMccManager?.destroy();
    this.rtcMccManager = null;
    this.callback = null;
    this.reset();
  }
}
