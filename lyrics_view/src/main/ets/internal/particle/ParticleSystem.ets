/**
 * Particle system for implementing particle animation effects in ScoringView
 */

import { LogUtils } from '../../utils/LogUtils';

/**
 * Data structure for a single particle
 */
export interface Particle {
  id: string;
  x: number;
  y: number;
  vx: number; // X-direction velocity
  vy: number; // Y-direction velocity
  rotation: number;
  rotationSpeed: number;
  scale: number;
  alpha: number;
  life: number; // Lifecycle (0-1)
  maxLife: number; // Maximum lifecycle (ms)
  particleType: number; // Particle type index
  startTime: number;
}

/**
 * Range interface
 */
export interface Range {
  min: number;
  max: number;
}

/**
 * Particle system configuration
 */
export interface ParticleConfig {
  particlesPerSecond: number; // Number of particles emitted per second
  maxParticles: number; // Maximum number of particles
  particleLifetime: number; // Particle lifetime (ms)
  speedRange: Range; // Speed range
  angleRange: Range; // Emission angle range (degrees)
  rotationSpeedRange: Range; // Rotation speed range
  scaleRange: Range; // Scale range
  fadeOutDuration: number; // Fade out duration (ms)
  gravity: number; // Gravity acceleration
}

/**
 * Particle system class - corresponds to Android's ParticleSystem
 */
export class ParticleSystem {
  private particles: Particle[] = [];
  private isEmitting: boolean = false;
  private emitX: number = 0;
  private emitY: number = 0;
  private config: ParticleConfig;
  private lastEmitTime: number = 0;
  private particleCounter: number = 0;
  private animationId: number = -1;
  // Delayed stop related
  private stopDelayTimer: number = -1;
  private shouldStopEmitting: boolean = false;
  private readonly STOP_DELAY_MS: number =
    300; // Extended to 500ms to ensure continuous particle generation during continuous coloring
  // Default configuration - corresponds to Android version settings
  private static readonly DEFAULT_CONFIG: ParticleConfig = ParticleSystem.createDefaultConfig();

  private static createDefaultConfig(): ParticleConfig {
    const speedRange: Range = { min: 0.10, max: 0.20 };
    const angleRange: Range = { min: 130, max: 230 };
    const rotationSpeedRange: Range = { min: 90, max: 180 };
    const scaleRange: Range = { min: 0.7, max: 1.6 };

    const config: ParticleConfig = {
      particlesPerSecond: 12,
      maxParticles: 24, // particles.length * 3
      particleLifetime: 900, // 900ms
      speedRange: speedRange, // Corresponds to Android's 0.10f, 0.20f
      angleRange: angleRange, // Corresponds to Android's 130, 230 degrees
      rotationSpeedRange: rotationSpeedRange, // Corresponds to Android's 90, 180
      scaleRange: scaleRange, // Corresponds to Android's 0.7f, 1.6f
      fadeOutDuration: 300, // Corresponds to Android's 300ms fade out
      gravity: 0.0002 // Gravity effect
    };

    return config;
  }

  constructor(config?: Partial<ParticleConfig>) {
    this.config = this.mergeConfig(ParticleSystem.DEFAULT_CONFIG, config);
    LogUtils.d(`ParticleSystem: Initialized with config: ${JSON.stringify(this.config)}`);
  }

  private mergeConfig(defaultConfig: ParticleConfig, userConfig?: Partial<ParticleConfig>): ParticleConfig {
    if (!userConfig) {
      return defaultConfig;
    }

    const merged: ParticleConfig = {
      particlesPerSecond: userConfig.particlesPerSecond ?? defaultConfig.particlesPerSecond,
      maxParticles: userConfig.maxParticles ?? defaultConfig.maxParticles,
      particleLifetime: userConfig.particleLifetime ?? defaultConfig.particleLifetime,
      speedRange: userConfig.speedRange ?? defaultConfig.speedRange,
      angleRange: userConfig.angleRange ?? defaultConfig.angleRange,
      rotationSpeedRange: userConfig.rotationSpeedRange ?? defaultConfig.rotationSpeedRange,
      scaleRange: userConfig.scaleRange ?? defaultConfig.scaleRange,
      fadeOutDuration: userConfig.fadeOutDuration ?? defaultConfig.fadeOutDuration,
      gravity: userConfig.gravity ?? defaultConfig.gravity
    };

    return merged;
  }

  /**
   * Start emitting particles at specified position - corresponds to Android's emit method
   */
  emit(x: number, y: number, particlesPerSecond?: number): void {
    this.emitX = x;
    this.emitY = y;
    if (particlesPerSecond !== undefined) {
      this.config.particlesPerSecond = particlesPerSecond;
    }
    this.isEmitting = true;

    // Create first particle immediately without waiting for emission interval
    if (this.particles.length < this.config.maxParticles) {
      this.createParticle();
    }

    this.lastEmitTime = Date.now();

    if (this.animationId === -1) {
      this.startAnimation();
    }
  }

  /**
   * Update emission point position - corresponds to Android's updateEmitPoint method
   */
  updateEmitPoint(x: number, y: number): void {
    this.emitX = x;
    this.emitY = y;
  }

  /**
   * Resume emission - corresponds to Android's resumeEmitting method
   */
  resumeEmitting(): void {
    // Clear delayed stop timer and flag
    if (this.stopDelayTimer !== -1) {
      clearTimeout(this.stopDelayTimer);
      this.stopDelayTimer = -1;
    }
    this.shouldStopEmitting = false;

    if (!this.isEmitting) {
      this.isEmitting = true;
      // Create first particle immediately without waiting for emission interval
      if (this.particles.length < this.config.maxParticles) {
        this.createParticle();
      }
      this.lastEmitTime = Date.now();

      // Ensure animation loop is running
      if (this.animationId === -1) {
        this.startAnimation();
      }
    } else {
      // If already emitting but few particles, also create a particle immediately
      if (this.particles.length < 3 && this.particles.length < this.config.maxParticles) {
        this.createParticle();
      }
      this.lastEmitTime = Date.now();
    }
  }

  /**
   * Stop emission - corresponds to Android's stopEmitting method
   * Uses delayed stop mechanism to avoid particle emission being interrupted too quickly
   */
  stopEmitting(): void {
    // If already not emitting or stop flag is already set, return directly
    if (!this.isEmitting || this.shouldStopEmitting) {
      return;
    }

    // Set delayed stop flag
    this.shouldStopEmitting = true;

    // Clear previous delay timer
    if (this.stopDelayTimer !== -1) {
      clearTimeout(this.stopDelayTimer);
    }

    // Set delayed stop timer
    this.stopDelayTimer = setTimeout(() => {
      this.isEmitting = false;
      this.shouldStopEmitting = false;
      this.stopDelayTimer = -1;
    }, this.STOP_DELAY_MS);
  }

  /**
   * Cancel particle system - corresponds to Android's cancel method
   */
  cancel(): void {
    this.isEmitting = false;
    this.particles = [];

    // Clear delayed stop timer
    if (this.stopDelayTimer !== -1) {
      clearTimeout(this.stopDelayTimer);
      this.stopDelayTimer = -1;
    }
    this.shouldStopEmitting = false;

    if (this.animationId !== -1) {
      clearTimeout(this.animationId);
      this.animationId = -1;
    }
    LogUtils.d('ParticleSystem: Cancelled');
  }

  /**
   * Get all currently active particles
   */
  getParticles(): Particle[] {
    return this.particles;
  }

  /**
   * Set particle system configuration
   */
  setConfig(config: Partial<ParticleConfig>): void {
    this.config = this.mergeConfig(this.config, config);
  }

  /**
   * Set rotation speed range - corresponds to Android's setRotationSpeedRange
   */
  setRotationSpeedRange(min: number, max: number): ParticleSystem {
    const range: Range = { min: min, max: max };
    this.config.rotationSpeedRange = range;
    return this;
  }

  /**
   * Set scale range - corresponds to Android's setScaleRange
   */
  setScaleRange(min: number, max: number): ParticleSystem {
    const range: Range = { min: min, max: max };
    this.config.scaleRange = range;
    return this;
  }

  /**
   * Set speed module and angle range - corresponds to Android's setSpeedModuleAndAngleRange
   */
  setSpeedModuleAndAngleRange(minSpeed: number, maxSpeed: number, minAngle: number, maxAngle: number): ParticleSystem {
    const speedRange: Range = { min: minSpeed, max: maxSpeed };
    const angleRange: Range = { min: minAngle, max: maxAngle };
    this.config.speedRange = speedRange;
    this.config.angleRange = angleRange;
    return this;
  }

  /**
   * Set fade out effect - corresponds to Android's setFadeOut
   */
  setFadeOut(duration: number): ParticleSystem {
    this.config.fadeOutDuration = duration;
    return this;
  }

  /**
   * Start animation loop
   */
  private startAnimation(): void {
    const animate = () => {
      if (this.particles.length === 0 && !this.isEmitting) {
        this.animationId = -1;
        return;
      }

      this.updateParticles();
      this.animationId = setTimeout(animate, 16); // 60fps
    };
    animate();
  }

  /**
   * Update particle states
   */
  private updateParticles(): void {
    const now = Date.now();
    const deltaTime = 16; // 16ms per frame

    // Emit new particles
    if (this.isEmitting && this.particles.length < this.config.maxParticles) {
      const timeSinceLastEmit = now - this.lastEmitTime;
      const emitInterval = 1000 / this.config.particlesPerSecond;

      if (timeSinceLastEmit >= emitInterval) {
        this.createParticle();
        this.lastEmitTime = now;
      }
    }

    // Update existing particles
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const particle = this.particles[i];
      const age = now - particle.startTime;

      // Check if particle should be removed
      if (age >= particle.maxLife) {
        this.particles.splice(i, 1);
        continue;
      }

      // Update particle position
      particle.x += particle.vx * deltaTime;
      particle.y += particle.vy * deltaTime;

      // Apply gravity
      particle.vy += this.config.gravity * deltaTime;

      // Update rotation
      particle.rotation += particle.rotationSpeed * deltaTime;

      // Update lifecycle and alpha
      particle.life = age / particle.maxLife;

      // Fade out effect
      const fadeOutStart = 1 - (this.config.fadeOutDuration / particle.maxLife);
      if (particle.life > fadeOutStart) {
        const fadeProgress = (particle.life - fadeOutStart) / (1 - fadeOutStart);
        particle.alpha = 1 - fadeProgress;
      } else {
        particle.alpha = 1;
      }
    }
  }

  /**
   * Create new particle
   */
  private createParticle(): void {
    const angle = this.randomBetween(this.config.angleRange.min, this.config.angleRange.max);
    const speed = this.randomBetween(this.config.speedRange.min, this.config.speedRange.max);
    const angleRad = (angle * Math.PI) / 180;

    const particle: Particle = {
      id: `particle_${this.particleCounter++}`,
      x: this.emitX,
      y: this.emitY,
      vx: Math.cos(angleRad) * speed,
      vy: Math.sin(angleRad) * speed,
      rotation: 0,
      rotationSpeed: this.randomBetween(this.config.rotationSpeedRange.min, this.config.rotationSpeedRange.max),
      scale: this.randomBetween(this.config.scaleRange.min, this.config.scaleRange.max),
      alpha: 1,
      life: 0,
      maxLife: this.config.particleLifetime,
      particleType: Math.floor(Math.random() * 8), // 8 different particle types
      startTime: Date.now()
    };

    this.particles.push(particle);
  }

  /**
   * Generate random number within specified range
   */
  private randomBetween(min: number, max: number): number {
    return min + Math.random() * (max - min);
  }
}
