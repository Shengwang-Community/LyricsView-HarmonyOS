import { appTasks } from '@ohos/hvigor-ohos-plugin';
import * as fs from 'fs';
import * as path from 'path';

// 生成 BuildConfig.ets 的函数
function generateBuildConfig() {
  console.log('[GenerateConfig] Generating BuildConfig.ets...');

  const projectRoot = __dirname;
  const localPropertiesPath = path.join(projectRoot, 'local.properties');
  const buildConfigPath = path.join(projectRoot, 'entry/src/main/ets/utils/BuildConfig.ets');

  // 读取 local.properties
  let config: Record<string, string> = {};
  if (fs.existsSync(localPropertiesPath)) {
    const content = fs.readFileSync(localPropertiesPath, 'utf-8');
    const lines = content.split('\n');

    lines.forEach(line => {
      const trimmedLine = line.trim();
      if (trimmedLine && !trimmedLine.startsWith('#')) {
        const equalIndex = trimmedLine.indexOf('=');
        if (equalIndex > 0) {
          const key = trimmedLine.substring(0, equalIndex).trim();
          const value = trimmedLine.substring(equalIndex + 1).trim();
          config[key] = value;
        }
      }
    });
  } else {
    console.warn('[GenerateConfig] local.properties not found, using default values');
    // 默认值
    config = {
      APP_ID: 'your_app_id_here',
      APP_CERTIFICATE: '',
      VENDOR_2_APP_ID: 'your_vendor_app_id',
      VENDOR_2_APP_KEY: 'your_vendor_app_key',
      VENDOR_2_TOKEN_HOST: 'https://your-api-host.com/token'
    };
  }

  // 生成 BuildConfig.ets 内容
  const buildConfigContent = `/**
 * 构建配置文件 - 自动生成，请勿手动修改
 * Generated from local.properties at build time
 */
export class BuildConfig {
  // Agora 配置
  public static readonly APP_ID: string = '${config.APP_ID || ''}';
  public static readonly APP_CERTIFICATE: string = '${config.APP_CERTIFICATE || ''}';

  // Vendor2 配置
  public static readonly VENDOR_2_APP_ID: string = '${config.VENDOR_2_APP_ID || ''}';
  public static readonly VENDOR_2_APP_KEY: string = '${config.VENDOR_2_APP_KEY || ''}';
  public static readonly VENDOR_2_TOKEN_HOST: string = '${config.VENDOR_2_TOKEN_HOST || ''}';

  /**
   * 检查配置是否有效
   */
  public static isConfigValid(): boolean {
    return !!(BuildConfig.APP_ID && BuildConfig.APP_ID.trim() !== '' && BuildConfig.APP_ID !== 'your_app_id_here');
  }

  /**
   * 获取配置信息（用于调试，不显示敏感信息）
   */
  public static getConfigInfo(): Record<string, Object> {
    const configInfo: Record<string, Object> = {} as Record<string, Object>;
    configInfo['appId'] = BuildConfig.APP_ID ? BuildConfig.APP_ID.substring(0, 8) + '...' : 'empty';
    configInfo['hasCertificate'] = !!(BuildConfig.APP_CERTIFICATE && BuildConfig.APP_CERTIFICATE.trim() !== '');
    return configInfo;
  }
}`;

  // 确保目录存在
  const configDir = path.dirname(buildConfigPath);
  if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
  }

  // 写入文件
  fs.writeFileSync(buildConfigPath, buildConfigContent, 'utf-8');
  console.log('[GenerateConfig] BuildConfig.ets generated successfully');

  // 输出配置信息（不显示敏感信息）
  console.log('[GenerateConfig] Configuration loaded:');
  console.log('- APP_ID:', config.APP_ID ? config.APP_ID.substring(0, 8) + '...' : 'empty');
  console.log('- Has Certificate:', !!(config.APP_CERTIFICATE && config.APP_CERTIFICATE.trim() !== ''));
}

// 在导出前生成配置
generateBuildConfig();

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
