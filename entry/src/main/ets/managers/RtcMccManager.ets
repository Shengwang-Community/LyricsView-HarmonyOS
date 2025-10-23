import { common } from '@kit.AbilityKit';
import {
  CacheStatistics,
  ChannelMediaOptions,
  Constants,
  IAgoraMusicContentCenter,
  IAgoraMusicPlayer,
  IMediaPlayerObserver,
  IMusicContentCenterEventHandler,
  IRtcEngineEventHandler,
  IScoreEventHandler,
  LineScoreData,
  LyricInfo,
  Music,
  MusicChartInfo,
  MusicContentCenterConfiguration,
  MusicContentCenterVendorId,
  PlayerPlaybackStats,
  PlayerUpdatedInfo,
  RawScoreData,
  RtcEngine,
  RtcEngineConfig,
  RtcStats,
  ScoreLevel,
  SrcInfo
} from '@shengwang/rtc-full';
import { Utils } from '@shengwang/lyrics-view';
import { IMccCallback } from '../interfaces/IMccCallback';
import { ExampleConstants } from '../utils/ExampleConstants';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';

/**
 * YinSuDa API response data structure
 */
interface YSDApiData {
  yinsuda_uid: string;
  token: string;
}

interface YSDApiResponse {
  error: number;
  data: YSDApiData;
}

/**
 * Vendor1 configuration interface
 */
interface IVendor1Config {
  appId: string;
  token: string;
  userId: string;
  domain: string,
  channelId: string;
  channelUserId: string;
}

/**
 * Vendor2 configuration interface
 */
interface IVendor2Config {
  appId: string;
  appKey: string;
  token: string;
  userId: string;
  deviceId: string;
  urlTokenExpireTime: number;
  chargeMode: number;
  channelId: string;
  channelUserId: string;
}

/**
 * RTC MCC (Music Content Center) Manager
 * Responsible for managing RTC engine, music content center and music player
 */
export class RtcMccManager {
  private static readonly TAG = ExampleConstants.APP_TAG + "-RtcMccManager";
  // Core components
  private rtcEngine: RtcEngine | null = null;
  private musicCenter: IAgoraMusicContentCenter | null = null;
  private musicPlayer: IAgoraMusicPlayer | null = null;
  private config: MusicContentCenterConfiguration | null = null;
  // Configuration information
  private appId: string = "";
  private rtcToken: string = "";
  private rtmToken: string = "";
  private channelId: string = "";
  private userId: string = "";
  private ysdAppId: string = "";
  private ysdAppKey: string = "";
  private ysdUserId: string = "";
  private ysdToken: string = "";
  private localUid: number = 0;
  // Callback interface
  private callback: IMccCallback | null = null;
  // Status flags
  private isJoined: boolean = false;
  // scoring level (1-5)
  private scoreLevel: number = 5;
  /**
   * MCC event handler
   */
  private mccEventHandler: IMusicContentCenterEventHandler = {
    onPreLoadEvent: (requestId: string, internalSongCode: bigint, percent: number, payload: string,
      state: Constants.MusicContentCenterState, reason: Constants.MusicContentCenterStateReason) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `onPreLoadEvent requestId:${requestId} songCode:${internalSongCode} percent:${percent} payload:${payload} state:${state} reason:${reason}`);

      if (state === Constants.MusicContentCenterState.PRELOAD_OK && percent === 100) {
        this.handleLyricResult(internalSongCode, payload);
      }
      Promise.resolve().then(() => {
        this.callback?.onMusicPreloadResult?.(internalSongCode, percent);
      });
    },

    onMusicCollectionResult: (requestId: string, page: number, pageSize: number, total: number, list: Music[],
      reason: Constants.MusicContentCenterStateReason) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `onMusicCollectionResult requestId:${requestId} page:${page} total:${total} reason:${reason}`);
    },

    onMusicChartsResult: (requestId: string, list: MusicChartInfo[],
      reason: Constants.MusicContentCenterStateReason) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG, `onMusicChartsResult requestId:${requestId} reason:${reason}`);
    },

    onLyricResult: (requestId: string, internalSongCode: bigint, payload: string,
      reason: Constants.MusicContentCenterStateReason) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `onLyricResult requestId:${requestId} songCode:${internalSongCode} payload:${payload} reason:${reason}`);
      this.handleLyricResult(internalSongCode, payload);
      Promise.resolve().then(() => {
        this.callback?.onMusicPreloadResult?.(internalSongCode, 100);
      });
    },

    onLyricInfoResult: (requestId: string, internalSongCode: bigint, lyricInfo: LyricInfo,
      reason: Constants.MusicContentCenterStateReason) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `onLyricInfoResult requestId:${requestId} songCode:${internalSongCode} reason:${reason}`);
    },

    onSongSimpleInfoResult: (requestId: string, songCode: bigint, simpleInfo: string,
      reason: Constants.MusicContentCenterStateReason) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `onSongSimpleInfoResult requestId:${requestId} songCode:${songCode} simpleInfo:${simpleInfo} reason:${reason}`);
    },

    onStartScoreResult: (internalSongCode: bigint, state: Constants.MusicContentCenterState,
      reason: Constants.MusicContentCenterStateReason) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `onStartScoreResult songCode:${internalSongCode} state:${state} reason:${reason}`);

      if (state === Constants.MusicContentCenterState.START_SCORE_COMPLETED &&
        reason === Constants.MusicContentCenterStateReason.OK) {
        // Set score level using configured value
        const level = this.getScoreLevelEnum(this.scoreLevel);
        this.musicCenter?.setScoreLevel(level);
        ExampleLogUtils.logDebug(RtcMccManager.TAG, `Set score level to: ${this.scoreLevel} (${level})`);
        // Open music player
        this.openMusicBySongCode(internalSongCode);
      }
    }
  };
  private mccScoreEventHandler: IScoreEventHandler = {
    onPitch: (internalSongCode: bigint, rawScoreData: RawScoreData) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `onPitch songCode:${internalSongCode} rawScoreData.speakerPitch:${rawScoreData.speakerPitch} rawScoreData.pitchScore:${rawScoreData.pitchScore}`);
      Promise.resolve().then(() => {
        this.callback?.onMusicPitchScore?.(internalSongCode, rawScoreData.speakerPitch, rawScoreData.pitchScore,
          Number(rawScoreData.progressInMs));
      })
    },

    onLineScore: (internalSongCode: bigint, lineScoreData: LineScoreData) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `onLineScore songCode:${internalSongCode} lineScoreData:${lineScoreData}`);
      Promise.resolve().then(() => {
        this.callback?.onMusicLineScore?.(
          internalSongCode,
          lineScoreData.pitchScore,
          lineScoreData.cumulativePitchScore,
          lineScoreData.index,
          lineScoreData.totalLines
        );
      });
    }
  };
  /**
   * Media player observer
   */
  private mediaPlayerObserver: IMediaPlayerObserver = {
    onPlayerStateChanged: (state: Constants.MediaPlayerState, reason: Constants.MediaPlayerReason) => {
      ExampleLogUtils.logDebug(RtcMccManager.TAG, `onPlayerStateChanged state:${state} reason:${reason}`);

      switch (state) {
        case Constants.MediaPlayerState.OPEN_COMPLETED:
          Promise.resolve().then(() => {
            this.callback?.onMusicPlaying?.();
            this.musicPlayer?.play();
          });
          break;
        case Constants.MediaPlayerState.PLAYING:
          break;
        case Constants.MediaPlayerState.PAUSED:
          Promise.resolve().then(() => {
            ExampleLogUtils.logDebug(RtcMccManager.TAG, "onPlayerStateChanged: PAUSED");
            this.callback?.onMusicPause?.();
          });
          break;
        case Constants.MediaPlayerState.STOPPED:
          Promise.resolve().then(() => {
            ExampleLogUtils.logDebug(RtcMccManager.TAG, "onPlayerStateChanged: STOPPED");
            this.callback?.onMusicStop?.();
          });
          break;
        case Constants.MediaPlayerState.PLAYBACK_ALL_LOOPS_COMPLETED:
          Promise.resolve().then(() => {
            this.callback?.onMusicStop?.();
          });
          break;
        case Constants.MediaPlayerState.FAILED:
          Promise.resolve().then(() => {
            this.callback?.onMusicError?.(reason);
          });
          break;
      }
    },

    onPositionChanged: (positionMs: number, timestampMs: number) => {
    },

    onPlayerEvent: (eventCode: Constants.MediaPlayerEvent, elapsedTime: number, message: string) => {
      // Player event handling
    },

    onMetaData: (type: Constants.MediaPlayerMetadataType, data: ArrayBuffer) => {
      // Metadata handling
    },

    onPlayBufferUpdated: (playCachedBuffer: number) => {
      // Buffer update handling
    },

    onPreloadEvent: (src: string, event: Constants.MediaPlayerPreloadEvent) => {
      // Preload event handling
    },

    onPlayerSrcInfoChanged: (from: SrcInfo, to: SrcInfo) => {
      // Source info change handling
    },

    onPlayerInfoUpdated: (info: PlayerUpdatedInfo) => {
      // Player info update handling
    },

    onPlayerCacheStats: (stats: CacheStatistics) => {
      // Cache statistics handling
    },

    onPlayerPlaybackStats: (stats: PlayerPlaybackStats) => {
      // Playback statistics handling
    },

    onAudioVolumeIndication: (volume: number) => {
      // Audio volume indication handling
    }
  };

  /**
   * Initialize RTC MCC manager
   * @param context - Application context
   * @param appId - Agora App ID
   * @param token - RTC Token
   * @param userId - User ID
   * @param callback - Callback interface
   */
  async init(context: common.UIAbilityContext, appId: string, channelId: string, rtcToken: string, rtmToken: string,
    userId: string,
    ysdAppId: string,
    ysdAppKey: string,
    ysdUserId: string, ysdToken: string, callback: IMccCallback): Promise<void> {
    this.appId = appId;
    this.channelId = channelId;
    this.rtcToken = rtcToken;
    this.rtmToken = rtmToken;
    this.userId = userId;
    this.ysdAppId = ysdAppId;
    this.ysdAppKey = ysdAppKey;
    this.ysdUserId = ysdUserId;
    this.ysdToken = ysdToken;
    this.callback = callback;

    ExampleLogUtils.logDebug(RtcMccManager.TAG,
      `init - appId:${appId}, userId:${userId}, ysdUserId:${ysdUserId}`);

    try {
      await this.initRtcEngine(context, appId);
      await this.initMusicContentCenter();
      ExampleLogUtils.logDebug(RtcMccManager.TAG, `init Rtc completed successfully`);
    } catch (error) {
      console.error(`${RtcMccManager.TAG} init failed:`, JSON.stringify(error));
      throw Error(JSON.stringify(error));
    }
  }

  /**
   * Initialize RTC engine
   */
  private async initRtcEngine(context: common.UIAbilityContext, appId: string): Promise<void> {
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `RtcEngine version: ${RtcEngine.getSdkVersion()}`);

    const rtcEngineConfig: RtcEngineConfig = new RtcEngineConfig();
    rtcEngineConfig.mContext = context;
    rtcEngineConfig.mAppId = appId;
    const eventHandler: IRtcEngineEventHandler = {
      onJoinChannelSuccess: (channel: string, uid: number, elapsed: number) => {
        ExampleLogUtils.logDebug(RtcMccManager.TAG,
          `onJoinChannelSuccess channel:${channel} uid:${uid} elapsed:${elapsed}`);
        this.localUid = uid;
        this.isJoined = true;

        // After successfully joining the channel, use Promise.resolve() to ensure execution in the next event loop
        // This avoids directly calling RTC interfaces in the RTC callback thread
        Promise.resolve().then(() => {
          this.addMccVendors();
        });
      },

      onLeaveChannel: (stats: RtcStats | null) => {
        ExampleLogUtils.logDebug(RtcMccManager.TAG, `onLeaveChannel`);
        this.isJoined = false;
      },

      onUserJoined: (uid: number, elapsed: number) => {
        ExampleLogUtils.logDebug(RtcMccManager.TAG, `onUserJoined uid:${uid} elapsed:${elapsed}`);
      },

      onUserOffline: (uid: number, reason: number) => {
        ExampleLogUtils.logDebug(RtcMccManager.TAG, `onUserOffline uid:${uid} reason:${reason}`);
      }
    };
    rtcEngineConfig.mEventHandler = eventHandler;

    this.rtcEngine = RtcEngine.create(rtcEngineConfig);
    this.rtcEngine.enableAudio();
    this.rtcEngine.setDefaultAudioRoutetoSpeakerphone(true);
  }

  /**
   * Initialize music content center
   */
  private async initMusicContentCenter(): Promise<void> {
    this.musicCenter = IAgoraMusicContentCenter.create();

    this.config = new MusicContentCenterConfiguration();
    this.config.eventHandler = this.mccEventHandler;
    this.config.scoreEventHandler = this.mccScoreEventHandler;

    const ret: number = this.musicCenter.initialize(this.config);
    if (ret !== 0) {
      throw Error(`MCC initialize failed with code: ${ret}`);
    }

    // Create music player
    this.musicPlayer = this.musicCenter.createMusicPlayer();
    this.musicPlayer?.registerPlayerObserver(this.mediaPlayerObserver);

    ExampleLogUtils.logDebug(RtcMccManager.TAG, `MCC initialized successfully`);
  }

  /**
   * Add MCC vendors
   * Only called after successfully joining the channel
   */
  private async addMccVendors(): Promise<void> {
    if (!this.musicCenter) {
      ExampleLogUtils.logError(RtcMccManager.TAG, 'MCC not initialized, cannot add vendors');
      return;
    }

    if (!this.isJoined) {
      ExampleLogUtils.logError(RtcMccManager.TAG, 'Not joined channel yet, cannot add vendors');
      return;
    }

    ExampleLogUtils.logDebug(RtcMccManager.TAG, 'Adding MCC vendors after join channel success');

    // YinSuDa data has been passed through init method, no need to fetch again
    ExampleLogUtils.logDebug(RtcMccManager.TAG,
      `Using YSD data - userId:${this.ysdUserId}, token:${this.ysdToken?.substring(0, 10)}...`);

    // Add Vendor1 (default vendor)
    const vendor1Config: IVendor1Config = {
      appId: this.appId,
      token: this.rtmToken,
      userId: this.userId,
      domain: 'api.agora.io',
      channelId: this.channelId,
      channelUserId: this.userId
    };

    let addVendorRet: number =
      this.musicCenter.addVendor(MusicContentCenterVendorId.DEFAULT, JSON.stringify(vendor1Config));
    ExampleLogUtils.logDebug(RtcMccManager.TAG,
      `add vendor1 ret:${addVendorRet} config:${JSON.stringify(vendor1Config)}`);

    // Add Vendor2 (third-party vendor) - using passed YSD data
    const vendor2Config: IVendor2Config = {
      appId: this.ysdAppId,
      appKey: this.ysdAppKey,
      token: this.ysdToken,
      userId: this.ysdUserId,
      deviceId: Utils.generateDeviceId(),
      urlTokenExpireTime: 15 * 60,
      chargeMode: 2,
      channelId: this.channelId,
      channelUserId: this.userId
    };

    addVendorRet = this.musicCenter.addVendor(MusicContentCenterVendorId.VENDOR_2, JSON.stringify(vendor2Config));
    ExampleLogUtils.logDebug(RtcMccManager.TAG,
      `add vendor2 ret:${addVendorRet} config:${JSON.stringify(vendor2Config)}`);

    ExampleLogUtils.logDebug(RtcMccManager.TAG, 'MCC vendors added successfully');
  }

  /**
   * Handle lyric result
   */
  private handleLyricResult(internalSongCode: bigint, payload: string): void {
    try {
      const jsonObject: Record<string, Object> = JSON.parse(payload);
      const lyricPath = (jsonObject.lyricPath as string) || "";
      const pitchPath = (jsonObject.pitchPath as string) || "";
      const songOffsetBegin = (jsonObject.songOffsetBegin as number) || 0;
      const songOffsetEnd = (jsonObject.songOffsetEnd as number) || 0;
      const lyricOffset = (jsonObject.lyricOffset as number) || 0;

      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `handleLyricResult songCode:${internalSongCode} lyricPath:${lyricPath}`);

      // Use Promise.resolve() to ensure callback execution in the next event loop, avoiding direct interface calls in RTC callback thread
      Promise.resolve().then(() => {
        this.callback?.onMusicLyricRequest?.(
          internalSongCode,
          lyricPath,
          pitchPath,
          songOffsetBegin,
          songOffsetEnd,
          lyricOffset
        );
      });
    } catch (error) {
      ExampleLogUtils.logError(RtcMccManager.TAG, `handleLyricResult error:` + JSON.stringify(error))
    }
  }

  /**
   * Join channel
   */
  joinChannel(): void {
    if (!this.rtcEngine) {
      console.error(`${RtcMccManager.TAG} RTC Engine not initialized`);
      return;
    }

    const option: ChannelMediaOptions = new ChannelMediaOptions();
    option.autoSubscribeAudio = true;
    option.autoSubscribeVideo = true;
    option.channelProfile = Constants.ChannelProfile.LIVE_BROADCASTING;
    option.clientRoleType = Constants.ClientRole.BROADCASTER;
    option.publishMicrophoneTrack = true;

    this.rtcEngine.setAudioScenario(Constants.AudioScenarioType.DEFAULT);
    this.rtcEngine.setDefaultAudioRoutetoSpeakerphone(true);

    const ret: number =
      this.rtcEngine.joinChannelWithOptions(this.rtcToken, this.channelId, parseInt(this.userId), option);
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `joinChannel ret:${ret} channel:${this.channelId}`);
  }

  /**
   * Leave channel
   */
  leaveChannel(): void {
    if (!this.rtcEngine) {
      console.error(`${RtcMccManager.TAG} RTC Engine not initialized`);
      return;
    }

    this.rtcEngine.leaveChannel();
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `leaveChannel called`);
  }

  /**
   * Preload music
   */
  preloadMusic(songCode: string, vendorId: MusicContentCenterVendorId, songOptionJson: string,
    lyricType: number): void {
    if (!this.musicCenter) {
      console.error(`${RtcMccManager.TAG} MCC not initialized`);
      return;
    }

    ExampleLogUtils.logDebug(RtcMccManager.TAG,
      `preloadMusic songCode:${songCode} vendorId:${vendorId} songOptionJson：${songOptionJson} lyricType:${lyricType}`);

    try {
      const internalSongCode: bigint = this.musicCenter.getInternalSongCode(vendorId, songCode, songOptionJson);
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `preloadMusic internalSongCode:${internalSongCode} songCode:${songCode}`);

      const isPreloaded: number = this.musicCenter.isPreloaded(internalSongCode);
      ExampleLogUtils.logDebug(RtcMccManager.TAG, `preload state:${isPreloaded}`);

      // if (isPreloaded == 0) {
      // ExampleLogUtils.logDebug(RtcMccManager.TAG,
      // `preloadMusic songCode:${songCode} preloaded getLyric request with lyricType:${lyricType}`) ;
      // this.musicCenter.getLyric(internalSongCode, lyricType)                                      ;
      // } else {
      const requestId: string = this.musicCenter.preload(internalSongCode);
      ExampleLogUtils.logDebug(RtcMccManager.TAG, `preload requestId:${requestId}`);
      // }
    } catch (error) {
      console.error(`${RtcMccManager.TAG} preloadMusic error:`, JSON.stringify(error));
    }
  }

  /**
   * Start scoring
   */
  startScore(vendorId: MusicContentCenterVendorId, songCode: string, jsonOption: string): void {
    if (!this.musicCenter) {
      console.error(`${RtcMccManager.TAG} MCC not initialized`);
      return;
    }

    try {
      const internalSongCode: bigint = this.musicCenter.getInternalSongCode(vendorId, songCode, jsonOption);
      if (internalSongCode === BigInt(0)) {
        console.error(`${RtcMccManager.TAG} getInternalSongCode failed songCode:${songCode}`);
        return;
      }

      const ret: number = this.musicCenter.startScore(internalSongCode);
      ExampleLogUtils.logDebug(RtcMccManager.TAG, `startScore ret:${ret} internalSongCode:${internalSongCode}`);
    } catch (error) {
      console.error(`${RtcMccManager.TAG} startScore error:`, JSON.stringify(error));
    }
  }

  /**
   * Open music by song code
   */
  private openMusicBySongCode(internalSongCode: bigint): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    const ret: number = this.musicPlayer.openWithSongCode(internalSongCode, 0);
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `openMusicBySongCode ret:${ret} songCode:${internalSongCode}`);
  }

  /**
   * Play music
   */
  play(): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.play();
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `play called`);
  }

  /**
   * Pause music
   */
  pause(): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.pause();
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `pause called`);
  }

  /**
   * Stop music
   */
  stop(): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.stop();
    this.musicCenter?.stopScore();
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `stop called`);
  }

  /**
   * Resume playback
   */
  resume(): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.resume();
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `resume called`);
  }

  /**
   * Seek to specified position
   */
  seek(time: number): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.seek(time);
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `seek to:${time}`);
  }

  /**
   * Get play position
   */
  getPlayPosition(): number {
    if (!this.musicPlayer) {
      return 0;
    }

    return this.musicPlayer.getPlayPosition();
  }

  /**
   * Set play mode
   */
  setPlayMode(playMode: Constants.MusicPlayMode): number {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return -1;
    }

    const ret: number = this.musicPlayer.setPlayMode(playMode);
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `setPlayMode:${playMode} ret:${ret}`);
    return ret;
  }

  /**
   * Adjust playout volume
   */
  adjustPlayoutVolume(volume: number): number {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return -1;
    }

    const ret: number = this.musicPlayer.adjustPlayoutVolume(volume);
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `adjustPlayoutVolume:${volume} ret:${ret}`);
    return ret;
  }

  /**
   * Get playout volume
   */
  getPlayoutVolume(): number {
    if (!this.musicPlayer) {
      return 0;
    }

    return this.musicPlayer.getPlayoutVolume();
  }

  /**
   * Remove cache
   */
  removeCache(internalSongCode: bigint): number {
    if (!this.musicCenter) {
      console.error(`${RtcMccManager.TAG} MCC not initialized`);
      return -1;
    }

    const ret: number = this.musicCenter.removeCache(internalSongCode);
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `removeCache ret:${ret} songCode:${internalSongCode}`);
    return ret;
  }

  /**
   * Clear all cache
   */
  clearCache(): void {
    if (!this.musicCenter) {
      console.error(`${RtcMccManager.TAG} MCC not initialized`);
      return;
    }

    const caches = this.musicCenter.getCaches(); // API may not exist
    for (const cache of caches) {
      this.musicCenter.removeCache(cache.songCode); // API may not exist
      ExampleLogUtils.logDebug(RtcMccManager.TAG,
        `would remove cache: ${cache.songCode}`); // Temporarily commented to avoid API errors
    }
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `clearCache completed`);
  }

  /**
   * Destroy manager
   */
  destroy(): void {
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `destroy called`);

    // Unregister observer
    this.musicPlayer?.unRegisterPlayerObserver(); // API may not exist

    // Destroy music player
    if (this.musicPlayer && this.musicCenter) {
      this.musicCenter.destroyMusicPlayer(this.musicPlayer);
      this.musicPlayer = null;
    }

    // Destroy MCC
    if (this.musicCenter) {
      IAgoraMusicContentCenter.destroy();
      this.musicCenter = null;
    }

    // Destroy RTC engine
    if (this.rtcEngine) {
      if (this.isJoined) {
        this.rtcEngine.leaveChannel();
      }
      RtcEngine.destroy();
      this.rtcEngine = null;
    }

    // Clear configuration
    this.config = null;
    this.callback = null;
    this.isJoined = false;

    ExampleLogUtils.logDebug(RtcMccManager.TAG, `destroy completed`);
  }

  /**
   * Get channel ID
   */
  getChannelId(): string {
    return this.channelId;
  }

  /**
   * Get local user ID
   */
  getLocalUid(): number {
    return this.localUid;
  }

  /**
   * Check if channel is joined
   */
  isChannelJoined(): boolean {
    return this.isJoined;
  }

  /**
   * Set score level
   * @param level - Score level (1-5)
   */
  setScoreLevel(level: number): void {
    if (level < ScoreLevel.LEVEL_1 || level > ScoreLevel.LEVEL_5) {
      ExampleLogUtils.logWarn(RtcMccManager.TAG, `Invalid score level: ${level}, must be 1-5`);
      return;
    }
    this.scoreLevel = level;
    ExampleLogUtils.logDebug(RtcMccManager.TAG, `Score level set to: ${level}`);
  }

  /**
   * Get score level enum from number
   * @param level - Score level (1-5)
   * @returns ScoreLevel enum
   */
  private getScoreLevelEnum(level: number): ScoreLevel {
    switch (level) {
      case 1:
        return ScoreLevel.LEVEL_1;
      case 2:
        return ScoreLevel.LEVEL_2;
      case 3:
        return ScoreLevel.LEVEL_3;
      case 4:
        return ScoreLevel.LEVEL_4;
      case 5:
      default:
        return ScoreLevel.LEVEL_5;
    }
  }
}
