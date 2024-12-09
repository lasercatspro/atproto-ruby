module AtProto
  # The Client class handles authenticated HTTP requests to the AT Protocol services
  # with DPoP token support and token request capabilities.
  #
  # @attr_accessor [String] access_token The current access token for authentication
  # @attr_accessor [String] private_key The private key corresponding to the public jwk of the app
  # @attr_reader [DpopHandler] dpop_handler The handler for DPoP token operations
  class Client
    attr_accessor :access_token, :dpop_handler

    # Initializes a new AT Protocol client
    #
    # @param private_key [OpenSSL::PKey::EC] The EC private key used for DPoP token signing (required)
    # @param access_token [String, nil] Optional access token for authentication
    #
    # @raise [ArgumentError] If private_key is not provided or not an OpenSSL::PKey::EC instance
    def initialize(private_key:, access_token: nil)
      @private_key = private_key
      @access_token = access_token
      @dpop_handler = DpopHandler.new(private_key, access_token)
    end

    # Sets a new private key for DPoP token signing
    #
    # @param private_key [OpenSSL::PKey::EC] The EC private key to use for signing DPoP tokens (required)
    # @raise [ArgumentError] If private_key is not an OpenSSL::PKey::EC instance
    def private_key=(private_key)
      @dpop_handler = @dpop_handler.new(private_key, @access_token)
    end

    # Makes an authenticated HTTP request
    #
    # @param method [Symbol] The HTTP method to use (:get, :post, etc.)
    # @param url [String] The URL to send the request to
    # @param params [Hash] Optional query parameters to be added to the URL
    # @param body [Hash, nil] Optional request body for POST/PUT requests
    #
    # @return [Hash] The parsed JSON response
    # @raise [TokenExpiredError] When the access token has expired
    # @raise [AuthError] When forbidden by the server for other reasons
    # @raise [APIError] On other errors from the server
    def request(method, url, params: {}, body: nil, headers: {})
      uri = URI(url)
      uri.query = URI.encode_www_form(params) if params.any?
      @dpop_handler.make_request(
        uri.to_s,
        method,
        headers: { 'Authorization' => "DPoP #{@access_token}" }.merge(headers),
        body: body
      )
    end

    # Gets a new access token using an authorization code
    #
    # @param code [String] The authorization code
    # @param jwk [Hash] The JWK for signing
    # @param client_id [String] The client ID
    # @param site [String] The token audience
    # @param endpoint [String] The token endpoint URL
    #
    # @return [Hash] The token response
    # @raise [AuthError] When forbidden by the server
    # @raise [APIError] On other errors from the server
    def get_token!(code:, jwk:, client_id:, site:, endpoint:)
      response = DpopHandler.new(@private_key).make_request(
        endpoint,
        :post,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        },
        body: token_params(
          code: code,
          jwk: jwk,
          client_id: client_id,
          site: site
        )
      )
      @access_token = response['access_token']
      response
    end

    # Refreshes the access token using a refresh token
    #
    # @param refresh_token [String] The refresh token
    # @param jwk [Hash] The JWK for signing
    # @param client_id [String] The client ID
    # @param site [String] The token audience
    # @param endpoint [String] The token endpoint URL
    #
    # @return [Hash] The token response
    # @raise [AuthError] When forbidden by the server
    # @raise [APIError] On other errors from the server
    def refresh_token!(refresh_token:, jwk:, client_id:, site:, endpoint:)
      response = DpopHandler.new(@private_key).make_request(
        endpoint,
        :post,
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        },
        body: refresh_token_params(
          refresh_token: refresh_token,
          jwk: jwk,
          client_id: client_id,
          site: site
        )
      )
      @access_token = response['access_token']
      @dpop_handler.access_token = @access_token
      response
    end

    private

    def token_params(code:, jwk:, client_id:, site:)
      {
        grant_type: 'authorization_code',
        code: code,
        **base_token_params(jwk: jwk, client_id: client_id, site: site)
      }
    end

    def refresh_token_params(refresh_token:, jwk:, client_id:, site:)
      {
        grant_type: 'refresh_token',
        refresh_token: refresh_token,
        **base_token_params(jwk: jwk, client_id: client_id, site: site)
      }
    end

    def base_token_params(jwk:, client_id:, site:)
      {
        client_id: client_id,
        client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
        client_assertion: generate_client_assertion(jwk: jwk, client_id: client_id, site: site)
      }
    end

    def generate_client_assertion(jwk:, client_id:, site:)
      jwt_payload = {
        iss: client_id,
        sub: client_id,
        aud: site,
        jti: SecureRandom.uuid,
        iat: Time.current.to_i,
        exp: Time.current.to_i + 300
      }

      JWT.encode(
        jwt_payload,
        @private_key,
        'ES256',
        {
          typ: 'jwt',
          alg: 'ES256',
          kid: jwk[:kid]
        }
      )
    end
  end
end
