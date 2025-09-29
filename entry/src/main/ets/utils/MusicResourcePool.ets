import { MusicContentCenterVendorId } from '@shengwang/rtc-full';

/**
 * Music resource data model
 */
export class MusicResource {
  index: number;
  songCode: string;
  songName: string;
  vendorId: number;
  songType: number;
  songOptionJson: string;

  constructor(
    index: number,
    songCode: string,
    songName: string,
    vendorId: number,
    songType: number,
    songOptionJson: string
  ) {
    this.index = index;
    this.songCode = songCode;
    this.songName = songName;
    this.vendorId = vendorId;
    this.songType = songType;
    this.songOptionJson = songOptionJson;
  }
}

/**
 * Music resource pool
 * Manages music resources from different vendors
 */
export class MusicResourcePool {
  /**
   * Get Vendor1 (default vendor) music list
   * @returns Vendor1 music resource list
   */
  static getVendor1MusicList(): MusicResource[] {
    const list: MusicResource[] = [];

    list.push(new MusicResource(
      0,
      "7162848775797850",
      "爱情转移",
      MusicContentCenterVendorId.DEFAULT,
      4,
      ""
    ));

    list.push(new MusicResource(
      1,
      "7104926139658410",
      "说爱你",
      MusicContentCenterVendorId.DEFAULT,
      4,
      ""
    ));

    list.push(new MusicResource(
      2,
      "7162848696618210",
      "Love Story",
      MusicContentCenterVendorId.DEFAULT,
      4,
      ""
    ));

    list.push(new MusicResource(
      3,
      "6246262727302510",
      "测试歌曲",
      MusicContentCenterVendorId.DEFAULT,
      4,
      ""
    ));

    return list;
  }

  /**
   * Get Vendor2 (third-party vendor) music list
   * @returns Vendor2 music resource list
   */
  static getVendor2MusicList(): MusicResource[] {
    const list: MusicResource[] = [];

    list.push(new MusicResource(
      0,
      "89488966",
      "在你的身边",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      "{\"format\":{\"highPart\":1}}"
    ));

    list.push(new MusicResource(
      1,
      "310937426",
      "怀抱",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      2,
      "621162805",
      "梦回花事了",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      3,
      "288308118",
      "还是分开",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      4,
      "130598261",
      "火力全开",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    // Test songs
    list.push(new MusicResource(
      5,
      "613544010",
      "测试歌曲1",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      6,
      "332492815",
      "测试歌曲2",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      7,
      "32144422",
      "测试歌曲3",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    return list;
  }

  /**
   * Get music list by vendor ID
   * @param vendorId - Vendor ID
   * @returns Music resource list for the corresponding vendor
   */
  static getMusicListByVendor(vendorId: MusicContentCenterVendorId): MusicResource[] {
    switch (vendorId) {
      case MusicContentCenterVendorId.DEFAULT:
        return MusicResourcePool.getVendor1MusicList();
      case MusicContentCenterVendorId.VENDOR_2:
        return MusicResourcePool.getVendor2MusicList();
      default:
        return MusicResourcePool.getVendor1MusicList();
    }
  }

  /**
   * Get all music resources
   * @returns All music resource list
   */
  static getAllMusicList(): MusicResource[] {
    const allList: MusicResource[] = [];
    allList.push(...MusicResourcePool.getVendor1MusicList());
    allList.push(...MusicResourcePool.getVendor2MusicList());
    return allList;
  }
}
