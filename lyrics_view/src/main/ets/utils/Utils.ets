import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { LogUtils } from './LogUtils';

/**
 * Utility class
 * Provides common utility methods including file operations, string processing, encoding conversion, etc.
 */
export class Utils {
  // ========== String Processing Tools ==========

  /**
   * Generate a random string of specified length
   * @param length String length
   * @param charset Character set, defaults to uppercase letters and numbers
   * @returns Random string
   */
  static generateRandomString(length: number, charset?: string): string {
    // Default charset: uppercase letters and numbers (suitable for generating device IDs, etc.)
    const defaultCharset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const chars = charset || defaultCharset;

    if (length <= 0) {
      return '';
    }

    if (chars.length === 0) {
      throw new Error('Charset cannot be empty');
    }

    let result = '';
    for (let i = 0; i < length; i++) {
      const randomIndex = Math.floor(Math.random() * chars.length);
      result += chars.charAt(randomIndex);
    }

    return result;
  }

  /**
   * Generate a 32-character random device ID
   * @returns 32-character device ID composed of uppercase letters and numbers
   */
  static generateDeviceId(): string {
    return Utils.generateRandomString(32);
  }

  /**
   * Generate a hexadecimal random string of specified length
   * @param length String length
   * @returns Hexadecimal random string
   */
  static generateRandomHex(length: number): string {
    return Utils.generateRandomString(length, '0123456789ABCDEF');
  }

  /**
   * Remove BOM marker from the beginning of a string
   * @param str Input string
   * @returns String with BOM removed
   */
  static removeStringBom(str: string): string {
    if (str.charCodeAt(0) === 0xFEFF) {
      return str.slice(1);
    }
    return str;
  }

  /**
   * Remove quotes from both ends of a string
   * @param str Input string
   * @returns String with quotes removed
   */
  static removeQuotes(str: string): string {
    if (!str) {
      return str;
    }
    if ((str.startsWith('"') && str.endsWith('"')) ||
      (str.startsWith("'") && str.endsWith("'"))) {
      return str.slice(1, -1);
    }
    return str;
  }

  // ========== Encoding Conversion Tools ==========

  /**
   * Convert Uint8Array to string (UTF-8 decoding)
   * @param uint8Array Byte array
   * @param encoding Encoding format (default utf-8)
   * @returns Converted string
   */
  static uint8ArrayToString(uint8Array: Uint8Array, encoding: string = 'utf-8'): string {
    try {
      return Utils.decodeUTF8(uint8Array);
    } catch (error) {
      LogUtils.e(`uint8ArrayToString error: ${error}`);
      // Fallback: byte-by-byte conversion (may have garbled characters)
      let result = '';
      for (let i = 0; i < uint8Array.length; i++) {
        result += String.fromCharCode(uint8Array[i]);
      }
      return result;
    }
  }

  /**
   * Convert string to Uint8Array (UTF-8 encoding)
   * @param str Input string
   * @param encoding Encoding format (default utf-8)
   * @returns Converted byte array
   */
  static stringToUint8Array(str: string, encoding: string = 'utf-8'): Uint8Array {
    try {
      return Utils.encodeUTF8(str);
    } catch (error) {
      LogUtils.e(`stringToUint8Array error: ${error}`);
      // Fallback: simple character code conversion
      const bytes = new Uint8Array(str.length);
      for (let i = 0; i < str.length; i++) {
        bytes[i] = str.charCodeAt(i) & 0xFF;
      }
      return bytes;
    }
  }

  /**
   * UTF-8 decoding method
   * Properly handles multi-byte UTF-8 characters
   */
  private static decodeUTF8(uint8Array: Uint8Array): string {
    let result = '';
    let i = 0;

    while (i < uint8Array.length) {
      let byte1 = uint8Array[i++];

      if (byte1 < 0x80) {
        // Single-byte character (ASCII)
        result += String.fromCharCode(byte1);
      } else if ((byte1 & 0xE0) === 0xC0) {
        // Two-byte character
        if (i >= uint8Array.length) {
          break;
        }
        let byte2 = uint8Array[i++];
        let codePoint = ((byte1 & 0x1F) << 6) | (byte2 & 0x3F);
        result += String.fromCharCode(codePoint);
      } else if ((byte1 & 0xF0) === 0xE0) {
        // Three-byte character
        if (i + 1 >= uint8Array.length) {
          break;
        }
        let byte2 = uint8Array[i++];
        let byte3 = uint8Array[i++];
        let codePoint = ((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F);
        result += String.fromCharCode(codePoint);
      } else if ((byte1 & 0xF8) === 0xF0) {
        // Four-byte character
        if (i + 2 >= uint8Array.length) {
          break;
        }
        let byte2 = uint8Array[i++];
        let byte3 = uint8Array[i++];
        let byte4 = uint8Array[i++];
        let codePoint = ((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F);

        // Handle characters beyond the Basic Multilingual Plane
        if (codePoint > 0xFFFF) {
          codePoint -= 0x10000;
          result += String.fromCharCode(0xD800 + (codePoint >> 10));
          result += String.fromCharCode(0xDC00 + (codePoint & 0x3FF));
        } else {
          result += String.fromCharCode(codePoint);
        }
      } else {
        // Invalid UTF-8 byte, skip
        continue;
      }
    }

    return result;
  }

  /**
   * UTF-8 encoding method
   * Encode string to UTF-8 byte array
   */
  private static encodeUTF8(str: string): Uint8Array {
    const bytes: number[] = [];
    for (let i = 0; i < str.length; i++) {
      const charCode = str.charCodeAt(i);

      if (charCode < 0x80) {
        // ASCII characters (0-127)
        bytes.push(charCode);
      } else if (charCode < 0x800) {
        // 2-byte UTF-8
        bytes.push(0xC0 | (charCode >> 6));
        bytes.push(0x80 | (charCode & 0x3F));
      } else if (charCode < 0xD800 || charCode >= 0xE000) {
        // 3-byte UTF-8 (non-surrogate pair)
        bytes.push(0xE0 | (charCode >> 12));
        bytes.push(0x80 | ((charCode >> 6) & 0x3F));
        bytes.push(0x80 | (charCode & 0x3F));
      } else {
        // 4-byte UTF-8 (surrogate pair)
        if (i + 1 < str.length) {
          const nextCharCode = str.charCodeAt(i + 1);
          if (charCode >= 0xD800 && charCode <= 0xDBFF && nextCharCode >= 0xDC00 && nextCharCode <= 0xDFFF) {
            const codePoint = 0x10000 + ((charCode & 0x3FF) << 10) + (nextCharCode & 0x3FF);
            bytes.push(0xF0 | (codePoint >> 18));
            bytes.push(0x80 | ((codePoint >> 12) & 0x3F));
            bytes.push(0x80 | ((codePoint >> 6) & 0x3F));
            bytes.push(0x80 | (codePoint & 0x3F));
            i++; // Skip next character (low surrogate)
          } else {
            // Invalid surrogate pair, use replacement character
            bytes.push(0xEF, 0xBF, 0xBD);
          }
        } else {
          // Invalid surrogate character at end of string
          bytes.push(0xEF, 0xBF, 0xBD);
        }
      }
    }

    return new Uint8Array(bytes);
  }


  /**
   * Core implementation for synchronous file reading
   */
  static getFileBytes(filePath: string): Uint8Array | null {
    // Check if file path is valid
    if (!filePath || filePath.trim().length === 0) {
      LogUtils.e('readFileSync: filePath is empty');
      return null;
    }

    // Check if file exists
    if (!fs.accessSync(filePath)) {
      LogUtils.e(`readFileSync: file does not exist: ${filePath}`);
      return null;
    }

    // Get file status information
    const stat = fs.statSync(filePath);
    if (!stat.isFile()) {
      LogUtils.e(`readFileSync: path is not a file: ${filePath}`);
      return null;
    }

    // Check file size
    const fileSize = stat.size;
    if (fileSize <= 0) {
      LogUtils.w(`readFileSync: file is empty: ${filePath}`);
      return new Uint8Array(0);
    }

    // Open file
    const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);

    try {
      // Create buffer and read file content
      const buffer = new ArrayBuffer(fileSize);
      const readSize = fs.readSync(file.fd, buffer);

      if (readSize !== fileSize) {
        LogUtils.w(`readFileSync: read size (${readSize}) != file size (${fileSize})`);
      }

      const uint8Array = new Uint8Array(buffer, 0, readSize);
      LogUtils.d(`readFileSync: successfully read ${readSize} bytes from ${filePath}`);
      return uint8Array;

    } finally {
      // Ensure file is closed
      fs.closeSync(file.fd);
    }
  }

  /**
   * Core implementation for asynchronous file reading
   */
  static async getFileBytesAsync(filePath: string): Promise<Uint8Array | null> {
    // Check if file path is valid
    if (!filePath || filePath.trim().length === 0) {
      LogUtils.e('getFileBytesAsync: filePath is empty');
      return null;
    }

    // Check if file exists
    const exists = await fs.access(filePath).then(() => true).catch(() => false);
    if (!exists) {
      LogUtils.e(`getFileBytesAsync: file does not exist: ${filePath}`);
      return null;
    }

    // Get file status information
    const stat = await fs.stat(filePath);
    if (!stat.isFile()) {
      LogUtils.e(`getFileBytesAsync: path is not a file: ${filePath}`);
      return null;
    }

    // Check file size
    const fileSize = stat.size;
    if (fileSize <= 0) {
      LogUtils.w(`getFileBytesAsync: file is empty: ${filePath}`);
      return new Uint8Array(0);
    }

    // Open file
    const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);

    try {
      // Create buffer and read file content
      const buffer = new ArrayBuffer(fileSize);
      const readSize = await fs.read(file.fd, buffer);

      if (readSize !== fileSize) {
        LogUtils.w(`getFileBytesAsync: read size (${readSize}) != file size (${fileSize})`);
      }

      const uint8Array = new Uint8Array(buffer, 0, readSize);
      LogUtils.d(`getFileBytesAsync: successfully read ${readSize} bytes from ${filePath}`);
      return uint8Array;

    } finally {
      // Ensure file is closed
      await fs.close(file.fd);
    }
  }

  /**
   * Read local file content as string (asynchronous)
   * @param filePath File path
   * @returns Promise<string | null> File content string, returns null on failure
   */
  static async getFileStringAsync(filePath: string): Promise<string | null> {
    try {
      const bytes = await Utils.getFileBytesAsync(filePath);
      if (!bytes) {
        return null;
      }
      return Utils.uint8ArrayToString(bytes);
    } catch (error) {
      LogUtils.e(`getFileStringAsync error for path ${filePath}: ${error}`);
      return null;
    }
  }

  /**
   * Load file content from rawfile directory as string
   * @param context Application context
   * @param fileName File name
   * @returns File content string, returns null on failure
   */
  static async loadRawFileAsString(context: common.UIAbilityContext, fileName: string): Promise<string | null> {
    try {
      const fileData = await Utils.loadRawFileAsBytes(context, fileName);
      if (!fileData) {
        return null;
      }

      const content = Utils.uint8ArrayToString(fileData);
      LogUtils.d(`loadAsString success: ${fileName}, length: ${content.length}`);
      return content;
    } catch (error) {
      LogUtils.e(`loadAsString failed: ${fileName}, error: ${error}`);
      return null;
    }
  }

  /**
   * Load file content from rawfile directory as Uint8Array
   * @param context Application context
   * @param fileName File name
   * @returns File content byte array, returns null on failure
   */
  static async loadRawFileAsBytes(context: common.UIAbilityContext, fileName: string): Promise<Uint8Array | null> {
    try {
      const resourceMgr = context.resourceManager;
      const fileData = await resourceMgr.getRawFileContent(fileName);

      LogUtils.d(`loadAsBytes success: ${fileName}, length: ${fileData.length}`);
      return fileData;
    } catch (error) {
      LogUtils.e(`loadAsBytes failed: ${fileName}, error: ${error}`);
      return null;
    }
  }
}
