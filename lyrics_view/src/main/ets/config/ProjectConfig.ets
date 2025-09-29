/** Project name */
export const PROJECT_NAME = 'Agora LyricsView HarmonyOS';

/** Version number */
export const VERSION = '1.0.0';

/** Project description */
export const DESCRIPTION = 'HarmonyOS LyricsView component with karaoke functionality';

/** Author */
export const AUTHOR = 'Agora';

/** License */
export const LICENSE = 'Apache-2.0';

/** Repository URL */
export const REPOSITORY = 'https://github.com/AgoraIO-Community/Agora-LyricsView-HarmonyOS';

// ========== SDK Configuration ==========
/** SDK mode switch */
export const SDK_MODE = false;

/** Whether it is SDK mode */
export const IS_SDK_MODE = false;

/** Whether it is source code mode */
export const IS_SOURCE_MODE = true;

// ========== Build Configuration ==========
/** HAR package name */
export const HAR_NAME = 'Agora-LyricsView-HarmonyOS';

/** Output directory */
export const OUTPUT_DIR = 'lyrics_view/build/default/outputs/default';

/** Whether signing is enabled */
export const SIGNING_ENABLED = false;

// ========== Computed Properties ==========
/** Full version name */
export const VERSION_NAME = `${PROJECT_NAME}-${VERSION}`;

/** Full HAR package name */
export const FULL_HAR_NAME = `${HAR_NAME}-${VERSION}`;

// ========== Utility Methods ==========
/**
 * Get mode description
 */
export function getModeDescription(): string {
  return IS_SDK_MODE ? 'HAR Package Mode' : 'Source Code Mode';
}

/**
 * Check if using SDK mode
 */
export function isUsingSdk(): boolean {
  return IS_SDK_MODE;
}

/**
 * Get configuration summary
 */
export function getConfigSummary(): string {
  return `${PROJECT_NAME} v${VERSION} (${getModeDescription()})`;
}

/**
 * Get version information
 */
export function getVersionInfo(): string {
  return JSON.stringify({
    name: PROJECT_NAME,
    version: VERSION,
    versionName: VERSION_NAME,
    description: DESCRIPTION,
    author: AUTHOR,
    license: LICENSE,
    repository: REPOSITORY
  });
}

/**
 * Get SDK configuration information
 */
export function getSdkInfo(): string {
  return JSON.stringify({
    mode: SDK_MODE,
    isSdkMode: IS_SDK_MODE,
    isSourceMode: IS_SOURCE_MODE,
    description: getModeDescription()
  });
}

/**
 * Get build configuration information
 */
export function getBuildInfo(): string {
  return JSON.stringify({
    harName: HAR_NAME,
    fullHarName: FULL_HAR_NAME,
    outputDir: OUTPUT_DIR,
    signingEnabled: SIGNING_ENABLED
  });
}

/**
 * Project configuration class
 * Provides unified configuration access interface
 */
export class ProjectConfig {
  // Project information
  static readonly PROJECT_NAME = PROJECT_NAME;
  static readonly VERSION = VERSION;
  static readonly DESCRIPTION = DESCRIPTION;
  static readonly AUTHOR = AUTHOR;
  static readonly LICENSE = LICENSE;
  static readonly REPOSITORY = REPOSITORY;
  // SDK configuration
  static readonly SDK_MODE = SDK_MODE;
  static readonly IS_SDK_MODE = IS_SDK_MODE;
  static readonly IS_SOURCE_MODE = IS_SOURCE_MODE;
  // Build configuration
  static readonly HAR_NAME = HAR_NAME;
  static readonly OUTPUT_DIR = OUTPUT_DIR;
  static readonly SIGNING_ENABLED = SIGNING_ENABLED;
  // Computed properties
  static readonly VERSION_NAME = VERSION_NAME;
  static readonly FULL_HAR_NAME = FULL_HAR_NAME;

  // Utility methods
  static getModeDescription(): string {
    return getModeDescription();
  }

  static isUsingSdk(): boolean {
    return isUsingSdk();
  }

  static getConfigSummary(): string {
    return getConfigSummary();
  }

  static getVersionInfo(): string {
    return getVersionInfo();
  }

  static getSdkInfo(): string {
    return getSdkInfo();
  }

  static getBuildInfo(): string {
    return getBuildInfo();
  }
}

/**
 * Default export
 */
export default ProjectConfig;
