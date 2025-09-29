export class Constants {
  public static readonly DOMAIN = 0x1001;
  public static readonly TAG = 'LyricsView';
  public static readonly LOG_FILE_NAME = 'agora.AgoraLyricsView';
  //seconds
  public static readonly HTTP_TIMEOUT = 60;
  public static readonly UTF_8 = "UTF-8";
  public static readonly LYRICS_FILE_DOWNLOAD_DIR = "lyrics";
  public static readonly LYRICS_FILE_TEMP_DIR = Constants.LYRICS_FILE_DOWNLOAD_DIR + "/temp";
  public static readonly FILE_EXTENSION_ZIP = "zip";
  public static readonly FILE_EXTENSION_XML = "xml";
  public static readonly FILE_EXTENSION_LRC = "lrc";
  public static readonly FILE_EXTENSION_KRC = "krc";
  public static readonly ERROR_NONE = 0;
  public static readonly ERROR_GENERAL = -1;
  public static readonly ERROR_UNZIP_ERROR = -4;
  public static readonly ERROR_HTTP_TIMEOUT = -1001;
  public static readonly ERROR_HTTP_UNKNOWN_HOST = -1003;
  public static readonly ERROR_HTTP_NOT_CONNECT = -1004;
  //ms
  public static readonly INTERVAL_AUDIO_PCM = 40;
}
