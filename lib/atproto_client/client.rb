module AtProto
  # The Client class handles authenticated HTTP requests to the AT Protocol services
  # with DPoP token support and automatic token refresh capabilities.
  #
  # @attr_reader [String] access_token The current access token for authentication
  # @attr_reader [String] refresh_token The current refresh token for renewing access
  # @attr_reader [DpopHandler] dpop_handler The handler for DPoP token operations
  class Client
    attr_reader :access_token, :refresh_token, :dpop_handler

    # Initializes a new AT Protocol client
    #
    # @param access_token [String] The initial access token for authentication
    # @param refresh_token [String] The refresh token for renewing access tokens
    # @param private_key [OpenSSL::PKey::EC] The EC private key used for DPoP token signing (required)
    # @param refresh_token_url [String] The base URL for token refresh requests
    #
    # @raise [ArgumentError] If private_key is not provided or not an OpenSSL::PKey::EC instance
    def initialize(access_token:, refresh_token:, private_key:, refresh_token_url: 'https://bsky.social')
      @access_token = access_token
      @refresh_token = refresh_token
      @refresh_token_url = refresh_token_url
      @dpop_handler = DpopHandler.new(private_key)
      @token_mutex = Mutex.new
    end

    # Sets a new private key for DPoP token signing
    #
    # @param private_key [OpenSSL::PKey::EC] The EC private key to use for signing DPoP tokens (required)
    # @raise [ArgumentError] If private_key is not an OpenSSL::PKey::EC instance
    def private_key=(private_key)
      @dpop_handler = @dpop_handler.new(private_key)
    end

    # Makes an authenticated HTTP request with automatic token refresh
    #
    # @param method [Symbol] The HTTP method to use (:get, :post, etc.)
    # @param url [String] The URL to send the request to
    # @param params [Hash] Optional query parameters
    # @param body [Hash, nil] Optional request body
    #
    # @return [Net::HTTPResponse] The HTTP response
    #
    # @raise [TokenExpiredError] When token refresh fails
    # @raise [RefreshTokenError] When unable to refresh the access token
    def request(method, url, params: {}, body: nil)
      retries = 0
      begin
        uri = URI(url)
        uri.query = URI.encode_www_form(params) if params.any?
        @dpop_handler.make_request(
          uri.to_s,
          method,
          headers: { 'Authorization' => "DPoP #{@access_token}" },
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

    # Refreshes the access token using the refresh token
    #
    # @private
    #
    # @raise [RefreshTokenError] When the token refresh request fails
    def refresh_access_token!
      @token_mutex.synchronize do
        response = @dpop_handler.make_request(
          "#{@refresh_token_url}/xrpc/com.atproto.server.refreshSession",
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
  end
end
