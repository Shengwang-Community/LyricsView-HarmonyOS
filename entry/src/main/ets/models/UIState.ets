/**
 * UI state model
 * Manages interface-related state information
 */
@ObservedV2
export class UIState {
  /** Callback information display */
  @Trace callBackInfo: string = '';
  /** Loading state */
  @Trace isLoading: boolean = false;
  /** Error message */
  @Trace errorMessage: string = '';
  /** Whether to show error */
  @Trace hasError: boolean = false;

  /**
   * Set loading state
   */
  setLoading(loading: boolean, message?: string): void {
    this.isLoading = loading;
    if (message) {
      this.callBackInfo = message;
    }
  }

  /**
   * Set success information
   */
  setSuccess(message: string): void {
    this.callBackInfo = message;
    this.hasError = false;
    this.errorMessage = '';
    this.isLoading = false;
  }

  /**
   * Set error information
   */
  setError(error: string): void {
    this.errorMessage = error;
    this.hasError = true;
    this.callBackInfo = `错误: ${error}`;
    this.isLoading = false;
  }

  /**
   * Clear error state
   */
  clearError(): void {
    this.hasError = false;
    this.errorMessage = '';
  }

  /**
   * Reset all states
   */
  reset(): void {
    this.callBackInfo = '';
    this.isLoading = false;
    this.errorMessage = '';
    this.hasError = false;
  }
}
