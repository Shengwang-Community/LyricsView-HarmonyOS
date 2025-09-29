import { LyricModel } from '@shengwang/lyrics-view';

/**
 * Song information model
 * Uses @ObservedV2 for reactive state management
 */
@ObservedV2
export class SongInfo {
  /** Song list */
  @Trace songList: string[] = [];
  /** Current song index */
  @Trace currentIndex: number = 0;
  /** Current song name */
  @Trace name: string = '';
  /** Lyric model */
  @Trace lyricModel: LyricModel | null = null;
  @Trace vendorName: string = ''

  constructor() {
    this.updateCurrentSongName();
  }

  /**
   * Switch to next song
   */
  switchToNext(): void {
    this.currentIndex = (this.currentIndex + 1) % this.songList.length;
    this.updateCurrentSongName();
    this.lyricModel = null; // Clear current lyric data
  }

  /**
   * Switch to previous song
   */
  switchToPrevious(): void {
    this.currentIndex = (this.currentIndex - 1 + this.songList.length) % this.songList.length;
    this.updateCurrentSongName();
    this.lyricModel = null; // Clear current lyric data
  }

  /**
   * Switch to specified song
   */
  switchToSong(index: number): void {
    if (index >= 0 && index < this.songList.length) {
      this.currentIndex = index;
      this.updateCurrentSongName();
      this.lyricModel = null; // Clear current lyric data
    }
  }

  /**
   * Set lyric model
   */
  setLyricModel(model: LyricModel | null): void {
    this.lyricModel = model;
  }

  /**
   * Get song description information
   */
  getDescription(): string {
    return `当前歌曲: ${this.name}`;
  }

  /**
   * Check if lyric data exists
   */
  hasLyrics(): boolean {
    return this.lyricModel !== null;
  }

  /**
   * Update current song name
   */
  private updateCurrentSongName(): void {
    this.name = this.songList[this.currentIndex];
  }
}
