/**
 * SimpleDeflate - Pure ArkTS zlib compression implementation
 * Uses uncompressed block format (RFC 1951)
 */

import { ExampleLogUtils } from '../utils/ExmapleLogUtils';
import { ExampleConstants } from '../utils/ExampleConstants';

const TAG = ExampleConstants.APP_TAG + '-SimpleDeflate';

export class SimpleDeflate {
  /**
   * Compress data in zlib format
   * @param data - Input data
   * @returns Compressed data (zlib format: header + deflate + adler32)
   */
  static deflate(data: Uint8Array): Uint8Array {
    try {

      const zlibHeader = new Uint8Array([0x78, 0x9C]);
      const deflatedData = SimpleDeflate.deflateUncompressed(data);
      const adler32 = SimpleDeflate.adler32(data);
      const checksum = new Uint8Array([
        (adler32 >> 24) & 0xFF,
        (adler32 >> 16) & 0xFF,
        (adler32 >> 8) & 0xFF,
        adler32 & 0xFF
      ]);

      const result = new Uint8Array(
        zlibHeader.length + deflatedData.length + checksum.length
      );
      result.set(zlibHeader, 0);
      result.set(deflatedData, zlibHeader.length);
      result.set(checksum, zlibHeader.length + deflatedData.length);

      return result;
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      ExampleLogUtils.logError(TAG, `deflate error: ${msg}`);
      throw new Error(`Deflate error: ${msg}`);
    }
  }

  /**
   * Create uncompressed deflate block
   * Block format: BFINAL(1) + BTYPE(00) + LEN(2) + NLEN(2) + data
   */
  private static deflateUncompressed(data: Uint8Array): Uint8Array {
    const MAX_BLOCK_SIZE = 65535;
    const blocks: Uint8Array[] = [];

    let offset = 0;
    while (offset < data.length) {
      const isLast = (offset + MAX_BLOCK_SIZE >= data.length);
      const blockSize = Math.min(MAX_BLOCK_SIZE, data.length - offset);

      const header = new Uint8Array(5);
      header[0] = isLast ? 0x01 : 0x00;
      header[1] = blockSize & 0xFF;
      header[2] = (blockSize >> 8) & 0xFF;

      const nlen = (~blockSize) & 0xFFFF;
      header[3] = nlen & 0xFF;
      header[4] = (nlen >> 8) & 0xFF;

      const block = new Uint8Array(5 + blockSize);
      block.set(header, 0);
      block.set(data.slice(offset, offset + blockSize), 5);

      blocks.push(block);
      offset += blockSize;
    }

    const totalLength = blocks.reduce((sum, block) => sum + block.length, 0);
    const result = new Uint8Array(totalLength);
    let pos = 0;
    for (const block of blocks) {
      result.set(block, pos);
      pos += block.length;
    }

    return result;
  }

  /**
   * Calculate Adler-32 checksum
   * @param data - Input data
   * @returns Adler-32 checksum value
   */
  private static adler32(data: Uint8Array): number {
    const MOD_ADLER = 65521;
    let a = 1;
    let b = 0;

    for (let i = 0; i < data.length; i++) {
      a = (a + data[i]) % MOD_ADLER;
      b = (b + a) % MOD_ADLER;
    }

    return (b << 16) | a;
  }
}
