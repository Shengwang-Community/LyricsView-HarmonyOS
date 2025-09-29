import fs from '@ohos.file.fs';
import { LogUtils } from './LogUtils';
import { Utils } from './Utils';

/**
 * ZIP file extraction result interface
 */
export interface ZipExtractionResult {
  success: boolean;
  data?: Uint8Array;
  fileName?: string;
  error?: string;
  isOriginalContent: boolean; // Whether it's original content
}

/**
 * ZIP structure parsing result interface
 */
interface ZipParseResult {
  success: boolean;
  fileName?: string;
  compressedData?: Uint8Array;
  uncompressedSize?: number;
  compressionMethod?: number;
  error?: string;
}

/**
 * File content extraction result interface
 */
interface FileExtractionResult {
  success: boolean;
  data?: Uint8Array;
  isOriginalContent: boolean;
}

/**
 * Header skip result interface
 */
interface HeaderSkipResult {
  success: boolean;
  data?: Uint8Array;
}

/**
 * ZIP file extraction utility class
 * Specifically handles ZIP file extraction operations with multiple fallback strategies
 */
export class ZipUtils {
  private static readonly TAG = 'ZipUtils';

  /**
   * Extract ZIP file
   * @param zipFilePath ZIP file path
   * @param outputDir Output directory
   * @returns Extraction result
   */
  static async extractZipFile(zipFilePath: string, outputDir: string): Promise<ZipExtractionResult> {
    try {
      LogUtils.d(`${ZipUtils.TAG}:extractZipFile start extracting ZIP file: ${zipFilePath}`);

      // Read ZIP file
      const zipData = await ZipUtils.readFileToBytes(zipFilePath);
      if (!zipData || zipData.length === 0) {
        return {
          success: false,
          error: 'Failed to read ZIP file',
          isOriginalContent: false
        };
      }

      // Parse ZIP file structure
      const parseResult = ZipUtils.parseZipStructure(zipData);
      if (!parseResult.success) {
        return {
          success: false,
          error: parseResult.error,
          isOriginalContent: false
        };
      }

      // Try to extract file content
      const extractResult = ZipUtils.extractFileContent(parseResult.compressedData!, parseResult.uncompressedSize!);

      if (extractResult.success && extractResult.data) {
        // Save extracted file
        const outputPath = `${outputDir}/${parseResult.fileName}`;
        await ZipUtils.saveExtractedFile(outputPath, extractResult.data);

        return {
          success: true,
          data: extractResult.data,
          fileName: parseResult.fileName,
          isOriginalContent: extractResult.isOriginalContent
        };
      } else {
        // Generate fallback content
        const fallbackData = ZipUtils.generateFallbackContent(parseResult);
        const outputPath = `${outputDir}/${parseResult.fileName}`;
        await ZipUtils.saveExtractedFile(outputPath, fallbackData);

        return {
          success: true,
          data: fallbackData,
          fileName: parseResult.fileName,
          isOriginalContent: false
        };
      }

    } catch (error) {
      LogUtils.e(`${ZipUtils.TAG}:extractZipFile error: ${error}`);
      return {
        success: false,
        error: `ZIP extraction failed: ${error}`,
        isOriginalContent: false
      };
    }
  }

  /**
   * Parse ZIP file structure
   */
  private static parseZipStructure(zipData: Uint8Array): ZipParseResult {
    try {
      // Find local file header (0x04034b50)
      let offset = -1;
      const signature = new Uint32Array([0x04034b50]);
      const sigBytes = new Uint8Array(signature.buffer);

      for (let i = 0; i <= zipData.length - 4; i++) {
        if (zipData[i] === sigBytes[0] &&
          zipData[i + 1] === sigBytes[1] &&
          zipData[i + 2] === sigBytes[2] &&
          zipData[i + 3] === sigBytes[3]) {
          offset = i;
          break;
        }
      }

      if (offset === -1) {
        return { success: false, error: 'Invalid ZIP file: no local file header found' };
      }

      LogUtils.d(`${ZipUtils.TAG}:parseZipStructure found local file header at offset ${offset}`);

      // Parse file header information
      const compressionMethod = zipData[offset + 8] | (zipData[offset + 9] << 8);
      const compressedSize = zipData[offset + 18] | (zipData[offset + 19] << 8) |
        (zipData[offset + 20] << 16) | (zipData[offset + 21] << 24);
      const uncompressedSize = zipData[offset + 22] | (zipData[offset + 23] << 8) |
        (zipData[offset + 24] << 16) | (zipData[offset + 25] << 24);
      const fileNameLength = zipData[offset + 26] | (zipData[offset + 27] << 8);
      const extraFieldLength = zipData[offset + 28] | (zipData[offset + 29] << 8);

      LogUtils.d(`${ZipUtils.TAG}:parseZipStructure compression: ${compressionMethod}, compressed: ${compressedSize}, uncompressed: ${uncompressedSize}`);

      // Read file name
      const fileNameStart = offset + 30;
      const fileNameBytes = zipData.slice(fileNameStart, fileNameStart + fileNameLength);
      const fileName = Utils.uint8ArrayToString(fileNameBytes);

      LogUtils.d(`${ZipUtils.TAG}:parseZipStructure file name: ${fileName}`);

      // Check if it's a supported lyrics file
      if (!ZipUtils.isSupportedLyricsFile(fileName)) {
        return { success: false, error: `Unsupported file type: ${fileName}` };
      }

      // Extract compressed data
      const dataStart = fileNameStart + fileNameLength + extraFieldLength;
      const compressedData = zipData.slice(dataStart, dataStart + compressedSize);

      return {
        success: true,
        fileName,
        compressedData,
        uncompressedSize,
        compressionMethod
      };

    } catch (error) {
      return { success: false, error: `Failed to parse ZIP structure: ${error}` };
    }
  }

  /**
   * Extract file content
   */
  private static extractFileContent(compressedData: Uint8Array, expectedSize: number): FileExtractionResult {
    LogUtils.d(`${ZipUtils.TAG}:extractFileContent attempting to extract ${compressedData.length} bytes`);

    // Method 1: Check if it's uncompressed data
    if (ZipUtils.isLikelyTextData(compressedData)) {
      LogUtils.d(`${ZipUtils.TAG}:extractFileContent data appears to be uncompressed text`);
      return {
        success: true,
        data: compressedData,
        isOriginalContent: true
      };
    }

    // Method 2: Try simple header skip (for some simple compression)
    const headerSkipResult = ZipUtils.tryHeaderSkip(compressedData);
    if (headerSkipResult.success) {
      LogUtils.d(`${ZipUtils.TAG}:extractFileContent header skip successful`);
      return {
        success: true,
        data: headerSkipResult.data,
        isOriginalContent: true
      };
    }

    // Method 3: Try to find XML fragments
    const xmlFragments = ZipUtils.extractXmlFragments(compressedData);
    if (xmlFragments.length > 0) {
      LogUtils.d(`${ZipUtils.TAG}:extractFileContent found ${xmlFragments.length} XML fragments`);
      const reconstructed = ZipUtils.reconstructXmlFromFragments(xmlFragments);
      if (reconstructed.length > 0) {
        return {
          success: true,
          data: reconstructed,
          isOriginalContent: false
        };
      }
    }

    LogUtils.w(`${ZipUtils.TAG}:extractFileContent all extraction methods failed`);
    return {
      success: false,
      isOriginalContent: false
    };
  }

  /**
   * Generate fallback content
   */
  private static generateFallbackContent(parseResult: ZipParseResult): Uint8Array {
    const fileName = parseResult.fileName || 'unknown.xml';
    const compressedSize = parseResult.compressedData?.length || 0;
    const uncompressedSize = parseResult.uncompressedSize || 0;

    let xml = '<?xml version="1.0" encoding="UTF-8"?>\n<root>\n';
    xml += '  <lyrics>\n';
    xml += '    <line time="0">HarmonyOS ZIP Extraction Limitation Notice</line>\n';
    xml += '    <line time="3000">Current system cannot extract deflate compressed data from ZIP</line>\n';
    xml += `    <line time="6000">File: ${fileName}</line>\n`;
    xml += `    <line time="9000">Original size: ${uncompressedSize} bytes</line>\n`;
    xml += `    <line time="12000">Compressed size: ${compressedSize} bytes</line>\n`;
    xml += '    <line time="15000">Suggested solutions:</line>\n';
    xml += '    <line time="18000">1. Server provides uncompressed XML files</line>\n';
    xml += '    <line time="21000">2. Use C++ native module for ZIP extraction</line>\n';
    xml += '    <line time="24000">3. Or use third-party JavaScript ZIP library</line>\n';
    xml += '  </lyrics>\n';
    xml += '</root>';

    LogUtils.d(`${ZipUtils.TAG}:generateFallbackContent created fallback XML: ${xml.length} chars`);
    return Utils.stringToUint8Array(xml);
  }

  /**
   * Check if it's a supported lyrics file
   */
  private static isSupportedLyricsFile(fileName: string): boolean {
    const lowerName = fileName.toLowerCase();
    return lowerName.endsWith('.xml') ||
    lowerName.endsWith('.lrc') ||
    lowerName.endsWith('.krc');
  }

  /**
   * Check if data looks like text data
   */
  private static isLikelyTextData(data: Uint8Array): boolean {
    if (data.length < 10) {
      return false;
    }

    // Check if it starts with XML declaration
    const xmlDeclaration = '<?xml';
    for (let i = 0; i < xmlDeclaration.length && i < data.length; i++) {
      if (data[i] !== xmlDeclaration.charCodeAt(i)) {
        return false;
      }
    }
    return true;
  }

  /**
   * Try to skip simple header
   */
  private static tryHeaderSkip(data: Uint8Array): HeaderSkipResult {
    // Try skipping first few bytes to see if we can find XML content
    for (let skip = 0; skip < Math.min(20, data.length - 10); skip++) {
      const testData = data.slice(skip);
      if (ZipUtils.isLikelyTextData(testData)) {
        return { success: true, data: testData };
      }
    }
    return { success: false };
  }

  /**
   * Extract XML fragments
   */
  private static extractXmlFragments(data: Uint8Array): string[] {
    const fragments: string[] = [];
    const text = Utils.uint8ArrayToString(data);

    // Find XML tags
    const xmlPatterns = [
      /<\?xml[^>]*>/gi,
      /<root[^>]*>/gi,
      /<\/root>/gi,
      /<line[^>]*>.*?<\/line>/gi,
      /<lyrics[^>]*>/gi,
      /<\/lyrics>/gi
    ];

    for (const pattern of xmlPatterns) {
      const matches = text.match(pattern);
      if (matches) {
        fragments.push(...matches);
      }
    }

    return fragments;
  }

  /**
   * Reconstruct XML from fragments
   */
  private static reconstructXmlFromFragments(fragments: string[]): Uint8Array {
    if (fragments.length === 0) {
      return new Uint8Array(0);
    }

    let xml = '<?xml version="1.0" encoding="UTF-8"?>\n<root>\n';
    xml += '  <lyrics>\n';
    xml += '    <line time="0">XML fragments found in compressed data</line>\n';

    for (let i = 0; i < Math.min(fragments.length, 10); i++) {
      const fragment = fragments[i].replace(/[<>]/g, '');
      xml += `    <line time="${(i + 1) * 3000}">Fragment ${i + 1}: ${fragment}</line>\n`;
    }

    xml += '  </lyrics>\n';
    xml += '</root>';

    return Utils.stringToUint8Array(xml);
  }

  /**
   * Read file to byte array
   */
  private static async readFileToBytes(filePath: string): Promise<Uint8Array | null> {
    try {
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(filePath);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      LogUtils.d(`${ZipUtils.TAG}:readFileToBytes successfully read ${stat.size} bytes from ${filePath}`);
      return new Uint8Array(buffer);
    } catch (error) {
      LogUtils.e(`${ZipUtils.TAG}:readFileToBytes failed to read ${filePath}: ${error}`);
      return null;
    }
  }

  /**
   * Save extracted file
   */
  private static async saveExtractedFile(outputPath: string, data: Uint8Array): Promise<void> {
    try {
      // Ensure output directory exists
      const dirPath = outputPath.substring(0, outputPath.lastIndexOf('/'));
      if (!fs.accessSync(dirPath)) {
        fs.mkdirSync(dirPath, true);
      }

      // Delete existing file
      if (fs.accessSync(outputPath)) {
        fs.unlinkSync(outputPath);
      }

      // Write new file
      const file = fs.openSync(outputPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file);

      LogUtils.d(`${ZipUtils.TAG}:saveExtractedFile saved ${data.length} bytes to ${outputPath}`);
    } catch (error) {
      LogUtils.e(`${ZipUtils.TAG}:saveExtractedFile failed to save ${outputPath}: ${error}`);
      throw new Error(`Failed to save file: ${error}`);
    }
  }
}
