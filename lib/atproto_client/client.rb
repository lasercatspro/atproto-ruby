module AtProto
  class Client
    attr_reader :access_token, :refresh_token, :dpop_handler

    def initialize(access_token, refresh_token, dpop_handler = nil)
      @access_token = access_token
      @refresh_token = refresh_token
      @dpop_handler = dpop_handler || DpopHandler.new
      @token_mutex = Mutex.new
    end

    def make_api_request(method, url, params: {}, body: nil)
      retries = 0
      begin
        uri = URI(url)
        uri.query = URI.encode_www_form(params) if params.any?
        @dpop_handler.make_request(
          uri.to_s,
          method,
          headers: { 'Authorization' => "Bearer #{@access_token}" },
          body: body
        )
      rescue TokenExpiredError => e
        raise e unless retries.zero? && @refresh_token

        retries += 1
        refresh_access_token!
        retry
      end
    end

    private

    def refresh_access_token!
      @token_mutex.synchronize do
        response = @dpop_handler.make_request(
          "#{base_url}/xrpc/com.atproto.server.refreshSession",
          :post,
          headers: {},
          body: { refresh_token: @refresh_token }
        )

        unless response.is_a?(Net::HTTPSuccess)
          raise RefreshTokenError, "Failed to refresh token: #{response.code} - #{response.body}"
        end

        data = JSON.parse(response.body)
        @access_token = data['access_token']
        @refresh_token = data['refresh_token']
      end
    end

    def base_url
      AtProto.configuration.base_url
    end
  end
end
