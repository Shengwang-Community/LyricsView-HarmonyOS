import cryptoFramework from '@ohos.security.cryptoFramework';
import util from '@ohos.util';
import { SimpleDeflate } from './SimpleDeflate';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';
import { ExampleConstants } from '../utils/ExampleConstants';

const TAG = ExampleConstants.APP_TAG + '-AccessToken2';

export function getVersion(): string {
  return '007';
}

export function packUint16(value: number): Uint8Array {
  const buffer = new ArrayBuffer(2);
  const view = new DataView(buffer);
  view.setUint16(0, value, true);
  return new Uint8Array(buffer);
}

export function packUint32(value: number): Uint8Array {
  const buffer = new ArrayBuffer(4);
  const view = new DataView(buffer);
  view.setUint32(0, value, true);
  return new Uint8Array(buffer);
}

export function packString(data: Uint8Array): Uint8Array {
  const lengthBytes = packUint16(data.length);
  const result = new Uint8Array(lengthBytes.length + data.length);
  result.set(lengthBytes, 0);
  result.set(data, lengthBytes.length);
  return result;
}

export function packMapUint32(map: Map<number, number>): Uint8Array {
  const sortedKeys = Array.from(map.keys()).sort((a, b) => a - b);
  const parts: Uint8Array[] = [packUint16(sortedKeys.length)];

  for (const key of sortedKeys) {
    parts.push(packUint16(key));
    parts.push(packUint32(map.get(key)!));
  }

  const totalLength = parts.reduce((sum, arr) => sum + arr.length, 0);
  const result = new Uint8Array(totalLength);
  let offset = 0;
  for (const part of parts) {
    result.set(part, offset);
    offset += part.length;
  }
  return result;
}

export class Service {
  private serviceType: number;
  private privileges: Map<number, number> = new Map();

  constructor(serviceType: number) {
    this.serviceType = serviceType;
  }

  private packType(): Uint8Array {
    return packUint16(this.serviceType);
  }

  private packPrivileges(): Uint8Array {
    return packMapUint32(this.privileges);
  }

  addPrivilege(privilege: number, expire: number): void {
    this.privileges.set(privilege, expire);
  }

  getServiceType(): number {
    return this.serviceType;
  }

  pack(): Uint8Array {
    const typeBytes = this.packType();
    const privBytes = this.packPrivileges();
    const result = new Uint8Array(typeBytes.length + privBytes.length);
    result.set(typeBytes, 0);
    result.set(privBytes, typeBytes.length);
    return result;
  }
}

export class ServiceRtc extends Service {
  static readonly SERVICE_TYPE = 1;
  static readonly PRIVILEGE_JOIN_CHANNEL = 1;
  static readonly PRIVILEGE_PUBLISH_AUDIO_STREAM = 2;
  static readonly PRIVILEGE_PUBLISH_VIDEO_STREAM = 3;
  static readonly PRIVILEGE_PUBLISH_DATA_STREAM = 4;
  private channelName: Uint8Array;
  private uid: Uint8Array;

  constructor(channelName: string = '', uid: number | string = 0) {
    super(ServiceRtc.SERVICE_TYPE);
    this.channelName = this.stringToUtf8Bytes(channelName);

    if (typeof uid === 'number') {
      this.uid = uid === 0 ? new Uint8Array(0) : this.stringToUtf8Bytes(String(uid));
    } else {
      this.uid = this.stringToUtf8Bytes(uid);
    }
  }

  pack(): Uint8Array {
    const baseBytes = super.pack();
    const channelNameBytes = packString(this.channelName);
    const uidBytes = packString(this.uid);
    const result = new Uint8Array(baseBytes.length + channelNameBytes.length + uidBytes.length);
    result.set(baseBytes, 0);
    result.set(channelNameBytes, baseBytes.length);
    result.set(uidBytes, baseBytes.length + channelNameBytes.length);
    return result;
  }

  private stringToUtf8Bytes(str: string): Uint8Array {
    const bytes: number[] = [];
    for (let i = 0; i < str.length; i++) {
      const code = str.charCodeAt(i);
      if (code < 0x80) {
        bytes.push(code);
      } else if (code < 0x800) {
        bytes.push(0xC0 | (code >> 6));
        bytes.push(0x80 | (code & 0x3F));
      } else if (code < 0x10000) {
        bytes.push(0xE0 | (code >> 12));
        bytes.push(0x80 | ((code >> 6) & 0x3F));
        bytes.push(0x80 | (code & 0x3F));
      }
    }
    return new Uint8Array(bytes);
  }
}

export class ServiceRtm extends Service {
  static readonly SERVICE_TYPE = 2;
  static readonly PRIVILEGE_LOGIN = 1;
  private userId: Uint8Array;

  constructor(userId: string = '') {
    super(ServiceRtm.SERVICE_TYPE);
    this.userId = this.stringToUtf8Bytes(userId);
  }

  pack(): Uint8Array {
    const baseBytes = super.pack();
    const userIdBytes = packString(this.userId);
    const result = new Uint8Array(baseBytes.length + userIdBytes.length);
    result.set(baseBytes, 0);
    result.set(userIdBytes, baseBytes.length);
    return result;
  }

  private stringToUtf8Bytes(str: string): Uint8Array {
    const bytes: number[] = [];
    for (let i = 0; i < str.length; i++) {
      const code = str.charCodeAt(i);
      if (code < 0x80) {
        bytes.push(code);
      } else if (code < 0x800) {
        bytes.push(0xC0 | (code >> 6));
        bytes.push(0x80 | (code & 0x3F));
      } else if (code < 0x10000) {
        bytes.push(0xE0 | (code >> 12));
        bytes.push(0x80 | ((code >> 6) & 0x3F));
        bytes.push(0x80 | (code & 0x3F));
      }
    }
    return new Uint8Array(bytes);
  }
}

export class AccessToken {
  private appId: string;
  private appCert: string;
  private issueTs: number;
  private expire: number;
  private salt: number;
  private services: Record<number, Service> = {};

  constructor(appId: string = '', appCertificate: string = '', issueTs: number = 0, expire: number = 900) {
    this.appId = appId;
    this.appCert = appCertificate;
    this.issueTs = issueTs !== 0 ? issueTs : Math.floor(Date.now() / 1000);
    this.expire = expire;
    this.salt = Math.floor(Math.random() * 99999998) + 1;
  }

  private async signing(): Promise<Uint8Array> {
    const appCertBytes = this.stringToUtf8Bytes(this.appCert);
    const issueTsBytes = packUint32(this.issueTs);

    let signing = await this.hmacSha256(issueTsBytes, appCertBytes);

    const saltBytes = packUint32(this.salt);
    signing = await this.hmacSha256(saltBytes, signing);

    return signing;
  }

  private buildCheck(): boolean {
    const isUuid = (data: string): boolean => {
      if (data.length !== 32) {
        return false;
      }
      for (let i = 0; i < data.length; i++) {
        const c = data.charAt(i);
        if (!'0123456789abcdefABCDEF'.includes(c)) {
          return false;
        }
      }
      return true;
    };

    if (!isUuid(this.appId) || !isUuid(this.appCert)) {
      return false;
    }
    if (Object.keys(this.services).length === 0) {
      return false;
    }
    return true;
  }

  addService(service: Service): void {
    this.services[service.getServiceType()] = service;
  }

  async build(): Promise<string> {
    if (!this.buildCheck()) {
      ExampleLogUtils.logError(TAG, `build: Build check failed`);
      return '';
    }

    try {
      const appIdBytes = this.stringToUtf8Bytes(this.appId);

      const signing = await this.signing();

      const parts: Uint8Array[] = [];
      parts.push(packString(appIdBytes));
      parts.push(packUint32(this.issueTs));
      parts.push(packUint32(this.expire));
      parts.push(packUint32(this.salt));
      parts.push(packUint16(Object.keys(this.services).length));

      const sortedKeys = Object.keys(this.services).map(k => parseInt(k)).sort((a, b) => a - b);
      for (const serviceType of sortedKeys) {
        parts.push(this.services[serviceType].pack());
      }

      const signingInfo = this.concatUint8Arrays(parts);

      const signature = await this.hmacSha256(signing, signingInfo);

      const sigPacked = packString(signature);
      const tokenData = this.concatUint8Arrays([sigPacked, signingInfo]);

      const compressed = this.zlibCompress(tokenData);

      const base64Token = this.base64Encode(compressed);
      const finalToken = getVersion() + base64Token;

      return finalToken;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      ExampleLogUtils.logError(TAG, `build: Error: ${errorMsg}`);
      throw new Error(`Build failed: ${errorMsg}`);
    }
  }

  private async hmacSha256(key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
    try {
      const mac = cryptoFramework.createMac('SHA256');
      const keyBlob: cryptoFramework.DataBlob = { data: key };
      const symKeyGenerator = cryptoFramework.createSymKeyGenerator('HMAC');
      const symKey = await symKeyGenerator.convertKey(keyBlob);
      await mac.init(symKey);
      const dataBlob: cryptoFramework.DataBlob = { data: data };
      await mac.update(dataBlob);
      const result = await mac.doFinal();
      return result.data;
    } catch (error) {
      ExampleLogUtils.logError(TAG, `HMAC error: ${JSON.stringify(error)}`);
      throw new Error(`HMAC error: ${JSON.stringify(error)}`);
    }
  }

  private zlibCompress(data: Uint8Array): Uint8Array {
    try {
      const compressed: Uint8Array = SimpleDeflate.deflate(data);
      return compressed;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      ExampleLogUtils.logError(TAG, `SimpleDeflate error: ${errorMsg}`);
      throw new Error(`Compression failed: ${errorMsg}`);
    }
  }

  private base64Encode(data: Uint8Array): string {
    const base64Helper = new util.Base64Helper();
    return base64Helper.encodeToStringSync(data);
  }

  private stringToUtf8Bytes(str: string): Uint8Array {
    const bytes: number[] = [];
    for (let i = 0; i < str.length; i++) {
      const code = str.charCodeAt(i);
      if (code < 0x80) {
        bytes.push(code);
      } else if (code < 0x800) {
        bytes.push(0xC0 | (code >> 6));
        bytes.push(0x80 | (code & 0x3F));
      } else if (code < 0x10000) {
        bytes.push(0xE0 | (code >> 12));
        bytes.push(0x80 | ((code >> 6) & 0x3F));
        bytes.push(0x80 | (code & 0x3F));
      }
    }
    return new Uint8Array(bytes);
  }

  private concatUint8Arrays(arrays: Uint8Array[]): Uint8Array {
    const totalLength = arrays.reduce((sum, arr) => sum + arr.length, 0);
    const result = new Uint8Array(totalLength);
    let offset = 0;
    for (const arr of arrays) {
      result.set(arr, offset);
      offset += arr.length;
    }
    return result;
  }
}
