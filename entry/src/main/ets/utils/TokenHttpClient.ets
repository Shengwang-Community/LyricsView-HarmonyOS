import http from '@ohos.net.http';

/**
 * HTTP response interface
 */
export interface TokenHttpResponse {
  success: boolean;
  data?: string;
  error?: string;
}

/**
 * Token HTTP client
 * HTTP request utility specifically for token generation
 */
export class TokenHttpClient {
  private static readonly TAG: string = 'TokenHttpClient';

  /**
   * Send POST request to generate token
   */
  public static async postForToken(
    url: string,
    headers: Record<string, string>,
    body: string
  ): Promise<TokenHttpResponse> {
    let httpRequest: http.HttpRequest | null = null;

    try {
      console.log(`${TokenHttpClient.TAG} POST request to: ${url}`);
      console.log(`${TokenHttpClient.TAG} Headers:`, JSON.stringify(headers));
      console.log(`${TokenHttpClient.TAG} Body:`, body);

      httpRequest = http.createHttp();

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000, // 15 seconds connection timeout
        readTimeout: 15000     // 15 seconds read timeout
      });

      console.log(`${TokenHttpClient.TAG} Response code: ${response.responseCode}`);
      console.log(`${TokenHttpClient.TAG} Response data:`, response.result);

      if (response.responseCode === 200) {
        const result: TokenHttpResponse = {
          success: true,
          data: response.result as string
        };
        return result;
      } else {
        const result: TokenHttpResponse = {
          success: false,
          error: `HTTP ${response.responseCode}: ${response.result}`
        };
        return result;
      }

    } catch (error) {
      console.error(`${TokenHttpClient.TAG} Request failed:`, JSON.stringify(error));
      const result: TokenHttpResponse = {
        success: false,
        error: `Network error: ${JSON.stringify(error)}`
      };
      return result;
    } finally {
      if (httpRequest) {
        httpRequest.destroy();
      }
    }
  }

  /**
   * Send GET request
   */
  public static async get(
    url: string,
    headers?: Record<string, string>
  ): Promise<TokenHttpResponse> {
    let httpRequest: http.HttpRequest | null = null;

    try {
      console.log(`${TokenHttpClient.TAG} GET request to: ${url}`);

      httpRequest = http.createHttp();

      const requestHeaders = headers || ({} as Record<string, string>);
      requestHeaders['Accept'] = 'application/json';

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: requestHeaders,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 15000
      });

      console.log(`${TokenHttpClient.TAG} Response code: ${response.responseCode}`);

      if (response.responseCode === 200) {
        const result: TokenHttpResponse = {
          success: true,
          data: response.result as string
        };
        return result;
      } else {
        const result: TokenHttpResponse = {
          success: false,
          error: `HTTP ${response.responseCode}: ${response.result}`
        };
        return result;
      }

    } catch (error) {
      console.error(`${TokenHttpClient.TAG} Request failed:`, JSON.stringify(error));
      const result: TokenHttpResponse = {
        success: false,
        error: `Network error: ${JSON.stringify(error)}`
      };
      return result;
    } finally {
      if (httpRequest) {
        httpRequest.destroy();
      }
    }
  }
}