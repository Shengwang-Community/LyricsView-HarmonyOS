/**
 * Particle renderer
 */

import { LogUtils } from '../../utils/LogUtils';
import { Particle, ParticleSystem } from './ParticleSystem';

/**
 * Particle rendering component
 * Uses HarmonyOS UI component system to render particles
 */
@Component
export struct ParticleRenderer {
  @Prop particleSystem: ParticleSystem | null = null;
  @State particles: Particle[] = [];
  @Prop particleColors: string[] = [
    '#FFD700', // Gold
    '#FF6B35', // Orange
    '#F7931E', // Orange-yellow
    '#FFE135', // Yellow
    '#C5E063', // Yellow-green
    '#9BC53D', // Green
    '#5BA8F2', // Blue
    '#9B59B6'// Purple
  ];
  @Prop particleSize: number = 20; // Increase base particle size for testing
  private updateTimer: number = -1;

  build() {
    Stack() {
      // Use ForEach to render all particles
      ForEach(this.particles, (particle: Particle, index: number) => {
        this.buildParticle(particle)
      }, (particle: Particle) => particle.id)
    }
    .width('100%')
    .height('100%')
    .onAppear(() => {
      LogUtils.d('ParticleRenderer: Component appeared, starting update loop');
      this.startUpdateLoop();
    })
    .onDisAppear(() => {
      LogUtils.d('ParticleRenderer: Component disappearing, stopping update loop');
      this.stopUpdateLoop();
    })
  }

  /**
   * Build a single particle
   */
  @Builder
  buildParticle(particle: Particle) {
    // Use different shapes to represent different types of particles
    if (particle.particleType % 3 === 0) {
      // Circular particle
      Circle({ width: this.particleSize * particle.scale, height: this.particleSize * particle.scale })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .opacity(particle.alpha)
        .rotate({ angle: particle.rotation })
        .position({
          x: particle.x - (this.particleSize * particle.scale) / 2,
          y: particle.y - (this.particleSize * particle.scale) / 2
        })
    } else if (particle.particleType % 3 === 1) {
      // Rectangular particle
      Rect()
        .width(this.particleSize * particle.scale)
        .height(this.particleSize * particle.scale)
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .opacity(particle.alpha)
        .rotate({ angle: particle.rotation })
        .borderRadius(2)
        .position({
          x: particle.x - (this.particleSize * particle.scale) / 2,
          y: particle.y - (this.particleSize * particle.scale) / 2
        })
    } else {
      // Star particle (simulated using polygons)
      this.buildStarParticle(particle)
    }
  }

  /**
   * Build star particle
   */
  @Builder
  buildStarParticle(particle: Particle) {
    // Use multiple small circles to create star effect
    Stack() {
      // Center circle
      Circle({ width: this.particleSize * particle.scale * 0.6, height: this.particleSize * particle.scale * 0.6 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])

      // Four directional small circles
      Circle({ width: this.particleSize * particle.scale * 0.3, height: this.particleSize * particle.scale * 0.3 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .position({ x: this.particleSize * particle.scale * 0.4, y: 0 })

      Circle({ width: this.particleSize * particle.scale * 0.3, height: this.particleSize * particle.scale * 0.3 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .position({ x: -this.particleSize * particle.scale * 0.4, y: 0 })

      Circle({ width: this.particleSize * particle.scale * 0.3, height: this.particleSize * particle.scale * 0.3 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .position({ x: 0, y: this.particleSize * particle.scale * 0.4 })

      Circle({ width: this.particleSize * particle.scale * 0.3, height: this.particleSize * particle.scale * 0.3 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .position({ x: 0, y: -this.particleSize * particle.scale * 0.4 })
    }
    .opacity(particle.alpha)
    .rotate({ angle: particle.rotation })
    .position({
      x: particle.x - (this.particleSize * particle.scale) / 2,
      y: particle.y - (this.particleSize * particle.scale) / 2
    })
  }

  /**
   * Start update loop
   */
  private startUpdateLoop(): void {
    if (this.updateTimer !== -1) {
      return;
    }

    const updateLoop = () => {
      if (this.particleSystem) {
        // Get latest particle data from particle system
        const newParticles = this.particleSystem.getParticles();
        const oldCount = this.particles.length;
        this.particles = [...newParticles];
      } else {
        this.particles = [];
      }

      // Continue next frame update
      this.updateTimer = setTimeout(updateLoop, 16); // 60fps
    };

    updateLoop();
  }

  /**
   * Stop update loop
   */
  private stopUpdateLoop(): void {
    if (this.updateTimer !== -1) {
      clearTimeout(this.updateTimer);
      this.updateTimer = -1;
    }
  }
}

/**
 * Simplified particle renderer - for performance-sensitive scenarios
 */
@Component
export struct SimpleParticleRenderer {
  @Prop particleSystem: ParticleSystem | null = null;
  @State particles: Particle[] = [];
  @Prop particleColor: string = '#FFD700'; // Unified particle color
  @Prop particleSize: number = 8;
  private updateTimer: number = -1;

  build() {
    Stack() {
      ForEach(this.particles, (particle: Particle, index: number) => {
        Circle({ width: this.particleSize * particle.scale, height: this.particleSize * particle.scale })
          .fill(this.particleColor)
          .opacity(particle.alpha)
          .position({
            x: particle.x - (this.particleSize * particle.scale) / 2,
            y: particle.y - (this.particleSize * particle.scale) / 2
          })
      }, (particle: Particle) => particle.id)
    }
    .width('100%')
    .height('100%')
    .onAppear(() => {
      this.startUpdateLoop();
    })
    .onDisAppear(() => {
      this.stopUpdateLoop();
    })
  }

  private startUpdateLoop(): void {
    if (this.updateTimer !== -1) {
      return;
    }

    const updateLoop = () => {
      if (this.particleSystem) {
        this.particles = [...this.particleSystem.getParticles()];
      } else {
        this.particles = [];
      }
      this.updateTimer = setTimeout(updateLoop, 16);
    };

    updateLoop();
  }

  private stopUpdateLoop(): void {
    if (this.updateTimer !== -1) {
      clearTimeout(this.updateTimer);
      this.updateTimer = -1;
    }
  }
}
