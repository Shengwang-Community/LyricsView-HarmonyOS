import http from '@ohos.net.http';

/**
 * HTTP response interface
 */
export interface HttpResponse {
  success: boolean;
  data?: string;
  error?: string;
}

/**
 * Token HTTP client
 * HTTP request utility specifically for token generation
 */
export class HttpClient {
  private static readonly TAG: string = 'HttpClient';

  /**
   * Send POST request to generate token
   */
  public static async postForToken(
    url: string,
    headers: Record<string, string>,
    body: string
  ): Promise<HttpResponse> {
    let httpRequest: http.HttpRequest | null = null;

    try {
      console.log(`${HttpClient.TAG} POST request to: ${url}`);
      console.log(`${HttpClient.TAG} Headers:`, JSON.stringify(headers));
      console.log(`${HttpClient.TAG} Body:`, body);

      httpRequest = http.createHttp();

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000, // 15 seconds connection timeout
        readTimeout: 15000     // 15 seconds read timeout
      });

      console.log(`${HttpClient.TAG} Response code: ${response.responseCode}`);
      console.log(`${HttpClient.TAG} Response data:`, response.result);

      if (response.responseCode === 200) {
        const result: HttpResponse = {
          success: true,
          data: response.result as string
        };
        return result;
      } else {
        const result: HttpResponse = {
          success: false,
          error: `HTTP ${response.responseCode}: ${response.result}`
        };
        return result;
      }

    } catch (error) {
      console.error(`${HttpClient.TAG} Request failed:`, JSON.stringify(error));
      const result: HttpResponse = {
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
  ): Promise<HttpResponse> {
    let httpRequest: http.HttpRequest | null = null;

    try {
      console.log(`${HttpClient.TAG} GET request to: ${url}`);

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

      console.log(`${HttpClient.TAG} Response code: ${response.responseCode}`);

      if (response.responseCode === 200) {
        const result: HttpResponse = {
          success: true,
          data: response.result as string
        };
        return result;
      } else {
        const result: HttpResponse = {
          success: false,
          error: `HTTP ${response.responseCode}: ${response.result}`
        };
        return result;
      }

    } catch (error) {
      console.error(`${HttpClient.TAG} Request failed:`, JSON.stringify(error));
      const result: HttpResponse = {
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