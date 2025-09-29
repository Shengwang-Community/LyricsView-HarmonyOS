import fs from '@ohos.file.fs';
import { ILogger } from './ILogger';
import { LogLevelUtils } from './LogLevel';

/**
 * File logger implementation - HarmonyOS version
 * Based on Agora-LoggingService FileLogger implementation
 * Supports file size limits and circular saving
 */
export class FileLogger implements ILogger {
  private readonly logFilePath: string;
  private readonly filePrefixName: string;
  private readonly maxFileSizeOfBytes: number;
  private readonly maxFileCount: number;
  private readonly supportTags: string[];
  // 1MB in bytes
  private static readonly ONE_MB = 1024 * 1024;

  constructor(
    logFilePath: string,
    filePrefixName: string,
    maxFileSizeOfBytes: number,
    maxFileCount: number,
    supportTags?: string[]
  ) {
    if (!logFilePath || logFilePath.trim().length === 0) {
      throw new Error('FileLogger init failed, logFilePath is empty');
    }
    if (!filePrefixName || filePrefixName.trim().length === 0) {
      throw new Error('FileLogger init failed, filePrefixName is empty');
    }
    if (maxFileSizeOfBytes === 0) {
      throw new Error('FileLogger init failed, maxFileSizeOfBytes is 0');
    }
    if (maxFileCount === 0) {
      throw new Error('FileLogger init failed, maxFileCount is 0');
    }

    this.logFilePath = logFilePath;
    this.filePrefixName = filePrefixName;
    this.maxFileSizeOfBytes = maxFileSizeOfBytes;
    this.maxFileCount = maxFileCount;
    this.supportTags = supportTags || [];
  }

  /**
   * Add supported tag
   */
  addSupportTag(tag: string): void {
    if (!this.supportTags.includes(tag)) {
      this.supportTags.push(tag);
    }
  }

  /**
   * Remove supported tag
   */
  removeSupportTag(tag: string): void {
    const index = this.supportTags.indexOf(tag);
    if (index > -1) {
      this.supportTags.splice(index, 1);
    }
  }

  onLog(level: number, tag: string, message: string): void {
    try {
      if (!this.isStorageSpaceEnough(this.logFilePath)) {
        console.info('FileLogger', 'onLog: storage space is less than 1MB');
        return;
      }

      if (this.supportTags.length > 0 && !this.supportTags.includes(tag)) {
        return;
      }

      // Build log message
      const lineMessage = this.buildLogMessage(level, tag, message);

      // Ensure log directory exists
      this.ensureLogDirectoryExists();

      // Get sorted log files list
      let logFiles = this.getSortedLogFiles();

      // If no log files exist, create new file
      if (logFiles.length === 0) {
        this.createNewLogFile();
        logFiles = this.getSortedLogFiles();
      }

      // Check first log file
      if (this.checkFirstLogFile(logFiles)) {
        logFiles = this.getSortedLogFiles();
      }

      const firstLogFile = logFiles[0];
      const currentFileSize = this.getFileSize(firstLogFile);

      // If current file plus new message exceeds size limit, need to rotate
      if (currentFileSize + lineMessage.length > this.maxFileSizeOfBytes) {
        this.renameLogFile(logFiles);
        this.createNewLogFile();
        logFiles = this.getSortedLogFiles();
      }

      // Write log to first file
      this.appendToFile(logFiles[0], lineMessage);

      // Delete extra log files
      this.deleteExtraLogFiles();

    } catch (error) {
      console.error('FileLogger', `Error writing log: ${error}`);
    }
  }

  /**
   * Build log message
   */
  private buildLogMessage(level: number, tag: string, message: string): string {
    const now = new Date();
    const timestamp = this.formatTimestamp(now);
    const levelName = LogLevelUtils.getLevelName(level);

    return `[${timestamp}][${tag}][${levelName}]${message}\n`;
  }

  /**
   * Format timestamp
   */
  private formatTimestamp(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    const milliseconds = String(date.getMilliseconds()).padStart(3, '0');

    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}.${milliseconds}`;
  }

  /**
   * Ensure log directory exists
   */
  private ensureLogDirectoryExists(): void {
    try {
      if (!fs.accessSync(this.logFilePath)) {
        fs.mkdirSync(this.logFilePath, true);
      }
    } catch (error) {
      console.error('FileLogger', `Failed to create log directory: ${error}`);
    }
  }

  /**
   * Get sorted log files list
   */
  private getSortedLogFiles(): string[] {
    try {
      const files = fs.listFileSync(this.logFilePath);
      const logFiles = files
        .filter(file => file.startsWith(this.filePrefixName))
        .map(file => `${this.logFilePath}/${file}`);

      // Sort by file name (prefix.log, prefix.1.log, prefix.2.log...)
      logFiles.sort((file1, file2) => {
        const name1 = this.extractFileName(file1);
        const name2 = this.extractFileName(file2);

        const num1 = this.extractFileNumber(name1);
        const num2 = this.extractFileNumber(name2);

        return num1 - num2;
      });

      return logFiles;
    } catch (error) {
      console.error('FileLogger', `Failed to list log files: ${error}`);
      return [];
    }
  }

  /**
   * Extract file name from path
   */
  private extractFileName(filePath: string): string {
    const parts = filePath.split('/');
    return parts[parts.length - 1];
  }

  /**
   * Extract number from file name
   */
  private extractFileNumber(fileName: string): number {
    try {
      // Remove .log suffix
      const nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));

      if (nameWithoutExt.length > this.filePrefixName.length) {
        const numberPart = nameWithoutExt.substring(this.filePrefixName.length + 1);
        return parseInt(numberPart);
      } else {
        return 0; // prefix.log file number is 0
      }
    } catch (error) {
      return 0;
    }
  }

  /**
   * Check first log file
   */
  private checkFirstLogFile(files: string[]): boolean {
    if (files.length === 0) {
      return false;
    }

    const firstLogFile = files[0];
    const fileName = this.extractFileName(firstLogFile);
    const currentLogFileName = `${this.filePrefixName}.log`;

    if (fileName !== currentLogFileName) {
      // Rename files
      for (let i = files.length - 1; i >= 0; i--) {
        const oldFile = files[i];
        let newFileName: string;
        if (i === 0) {
          newFileName = currentLogFileName;
        } else {
          newFileName = `${this.filePrefixName}.${i}.log`;
        }
        const newFile = `${this.logFilePath}/${newFileName}`;
        try {
          fs.renameSync(oldFile, newFile);
        } catch (error) {
          console.error('FileLogger', `Failed to rename file: ${error}`);
        }
      }
      return true;
    }
    return false;
  }

  /**
   * Create new log file
   */
  private createNewLogFile(): void {
    const newFileName = `${this.logFilePath}/${this.filePrefixName}.log`;
    try {
      // Create empty file
      const file = fs.openSync(newFileName, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.closeSync(file);
    } catch (error) {
      console.error('FileLogger', `Failed to create new log file: ${error}`);
    }
  }

  /**
   * Rename log files
   */
  private renameLogFile(files: string[]): void {
    for (let i = files.length - 1; i >= 0; i--) {
      const oldFile = files[i];
      const newFileName = `${this.filePrefixName}.${i + 1}.log`;
      const newFile = `${this.logFilePath}/${newFileName}`;
      try {
        fs.renameSync(oldFile, newFile);
      } catch (error) {
        console.error('FileLogger', `Failed to rename file: ${error}`);
      }
    }
  }

  /**
   * Delete extra log files
   */
  private deleteExtraLogFiles(): void {
    const logFiles = this.getSortedLogFiles();
    if (logFiles.length > this.maxFileCount) {
      for (let i = this.maxFileCount; i < logFiles.length; i++) {
        try {
          fs.unlinkSync(logFiles[i]);
        } catch (error) {
          console.error('FileLogger', `Failed to delete extra log file: ${error}`);
        }
      }
    }
  }

  /**
   * Get file size
   */
  private getFileSize(filePath: string): number {
    try {
      const stat = fs.statSync(filePath);
      return stat.size;
    } catch (error) {
      return 0;
    }
  }

  /**
   * Append content to file
   */
  private appendToFile(filePath: string, content: string): void {
    try {
      const file = fs.openSync(filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.APPEND);
      fs.writeSync(file.fd, content, { encoding: 'utf-8' });
      fs.closeSync(file);
    } catch (error) {
      console.error('FileLogger', `Failed to append to file: ${error}`);
    }
  }

  /**
   * Check if storage space is enough
   */
  private isStorageSpaceEnough(logFilePath: string): boolean {
    try {
      // In HarmonyOS, we simplify storage space check
      // Here we assume there is enough space, in actual projects more complex checks can be implemented as needed
      return fs.accessSync(logFilePath) || true;
    } catch (error) {
      return false;
    }
  }
}
