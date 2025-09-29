#!/usr/bin/env node

/**
 * 工程配置管理工具
 * 用于读取和更新 project-config.json 中的配置
 */

const fs = require('fs');
const path = require('path');

class ConfigManager {
  constructor() {
    this.configPath = path.join(__dirname, '..', 'project-config.json');
    this.config = this.loadConfig();
  }

  /**
   * 加载配置文件
   */
  loadConfig() {
    try {
      const configContent = fs.readFileSync(this.configPath, 'utf8');
      return JSON.parse(configContent);
    } catch (error) {
      console.error('❌ 加载配置文件失败:', error.message);
      process.exit(1);
    }
  }

  /**
   * 保存配置文件
   */
  saveConfig() {
    try {
      fs.writeFileSync(this.configPath, JSON.stringify(this.config, null, 2) + '\n');
    } catch (error) {
      console.error('❌ 保存配置文件失败:', error.message);
      process.exit(1);
    }
  }

  /**
   * 获取配置值
   */
  get(path) {
    const keys = path.split('.');
    let value = this.config;
    
    for (const key of keys) {
      if (value && typeof value === 'object' && key in value) {
        value = value[key];
      } else {
        return undefined;
      }
    }
    
    return value;
  }

  /**
   * 设置配置值
   */
  set(path, value) {
    const keys = path.split('.');
    let current = this.config;
    
    for (let i = 0; i < keys.length - 1; i++) {
      const key = keys[i];
      if (!current[key] || typeof current[key] !== 'object') {
        current[key] = {};
      }
      current = current[key];
    }
    
    current[keys[keys.length - 1]] = value;
  }

  /**
   * 获取项目信息
   */
  getProjectInfo() {
    return {
      name: this.get('project.name'),
      version: this.get('project.version'),
      description: this.get('project.description'),
      author: this.get('project.author'),
      license: this.get('project.license'),
      repository: this.get('project.repository')
    };
  }

  /**
   * 获取SDK配置
   */
  getSdkConfig() {
    return {
      mode: this.get('sdk.mode'),
      description: this.get('sdk.description')
    };
  }

  /**
   * 获取构建配置
   */
  getBuildConfig() {
    return {
      harName: this.get('build.harName'),
      outputDir: this.get('build.outputDir'),
      signing: this.get('build.signing')
    };
  }

  /**
   * 设置SDK模式
   */
  setSdkMode(mode) {
    this.set('sdk.mode', mode);
    this.saveConfig();
  }

  /**
   * 设置版本号
   */
  setVersion(version) {
    this.set('project.version', version);
    this.saveConfig();
  }

  /**
   * 获取版本号
   */
  getVersion() {
    return this.get('project.version');
  }

  /**
   * 获取HAR包名称
   */
  getHarName() {
    const projectName = this.get('project.name');
    const version = this.get('project.version');
    const harName = this.get('build.harName');
    return `${harName}-${version}`;
  }

  /**
   * 获取完整版本名称
   */
  getVersionName() {
    const projectName = this.get('project.name');
    const version = this.get('project.version');
    return `${projectName}-${version}`;
  }

  /**
   * 打印配置信息
   */
  printConfig() {
    console.log('📋 工程配置信息:');
    console.log(JSON.stringify(this.config, null, 2));
  }
}

// 命令行接口
if (require.main === module) {
  const args = process.argv.slice(2);
  const configManager = new ConfigManager();

  if (args.length === 0) {
    configManager.printConfig();
  } else if (args[0] === 'get' && args[1]) {
    const value = configManager.get(args[1]);
    console.log(value !== undefined ? value : 'undefined');
  } else if (args[0] === 'set' && args[1] && args[2]) {
    configManager.set(args[1], args[2]);
    console.log(`✅ 已设置 ${args[1]} = ${args[2]}`);
  } else if (args[0] === 'version') {
    console.log(configManager.getVersion());
  } else if (args[0] === 'sdk-mode') {
    console.log(configManager.getSdkConfig().mode);
  } else if (args[0] === 'set-sdk-mode' && args[1]) {
    const mode = args[1] === 'true';
    configManager.setSdkMode(mode);
    console.log(`✅ 已设置 SDK 模式: ${mode ? 'HAR 包模式' : '源码模式'}`);
  } else {
    console.log('用法:');
    console.log('  node config-manager.js                    # 显示所有配置');
    console.log('  node config-manager.js get <path>         # 获取配置值');
    console.log('  node config-manager.js set <path> <value> # 设置配置值');
    console.log('  node config-manager.js version            # 获取版本号');
    console.log('  node config-manager.js sdk-mode           # 获取SDK模式');
    console.log('  node config-manager.js set-sdk-mode <true|false> # 设置SDK模式');
  }
}

module.exports = ConfigManager;
