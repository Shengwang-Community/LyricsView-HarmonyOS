/**
 * HarmonyOS Native AI算法接口类型声明
 * 对应NAPI导出的所有函数
 */

/**
 * 将pitch值转换为音调值
 */
export const pitchToTone: (pitch: number) => number;

/**
 * 计算评分
 */
export const calculatedScore: (
  voicePitch: number,
  stdPitch: number,
  scoreLevel: number,
  scoreCompensationOffset: number
) => number;

/**
 * 处理音调补偿
 */
export const handlePitch: (
  stdPitch: number,
  voicePitch: number,
  stdMaxPitch: number
) => number;

/**
 * 重置算法状态
 */
export const reset: () => void;

/**
 * 测试函数
 */
export const add: (a: number, b: number) => number;