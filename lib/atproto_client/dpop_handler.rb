module AtProto
  # Handler for DPoP (Demonstrating Proof-of-Possession) protocol implementation
  class DpopHandler
    attr_accessor :private_key, :access_token

    # Initialize a new DPoP handler
    # @param private_key [OpenSSL::PKey::EC, nil] Optional private key for signing tokens
    # @param access_token [String] Optional access_token
    def initialize(private_key = nil, access_token = nil)
      @private_key = private_key || generate_private_key
      @current_nonce = nil
      @nonce_mutex = Mutex.new
      @token_mutex = Mutex.new
      @access_token = access_token
    end

    # Generates a DPoP token for a request
    # @param http_method [String] The HTTP method of the request
    # @param url [String] The target URL of the request
    # @param nonce [String, nil] Optional nonce value
    # @return [String] The generated DPoP token
    def generate_token(http_method, url, nonce = @current_nonce)
      @token_mutex.synchronize do
        create_dpop_token(http_method, url, nonce)
      end
    end

    # Updates the current nonce from response headers
    # @param response [Net::HTTPResponse] Response containing dpop-nonce header
    def update_nonce(response)
      new_nonce = response.to_hash.dig('dpop-nonce', 0)
      @nonce_mutex.synchronize do
        @current_nonce = new_nonce if new_nonce
      end
    end

    # Makes an HTTP request with DPoP handling,
    # when no nonce is used for the first try, takes it from the response and retry
    # @param uri [String] The target URI
    # @param method [String] The HTTP method
    # @param headers [Hash] Optional request headers
    # @param body [Hash, nil] Optional request body
    # @return [Net::HTTPResponse] The HTTP response
    # @raise [APIError] If the request fails
    def make_request(uri, method, headers: {}, body: nil)
      retried = false
      begin
        dpop_token = generate_token(method.to_s.upcase, uri.to_s)
        request = Request.new(method, uri, headers.merge('DPoP' => dpop_token))
        request.body = body.is_a?(Hash) ? body.to_json : body if body
        request.run
      rescue Net::HTTPClientException => e
        unless retried
          update_nonce(e.response)
          retried = true
          retry
        end
        raise APIError, "Request failed: #{e.response.code} - #{e.response.body}"
      end
    end

    private

    def generate_private_key
      OpenSSL::PKey::EC.generate('prime256v1').tap(&:check_key)
    end

    def create_dpop_token(http_method, target_uri, nonce = nil)
      jwk = JWT::JWK.new(@private_key).export
      payload = {
        jti: SecureRandom.hex(16),
        htm: http_method,
        htu: target_uri,
        iat: Time.now.to_i,
        exp: Time.now.to_i + 120
      }
      payload[:ath] = generate_ath if @access_token
      payload[:nonce] = nonce if nonce

      JWT.encode(payload, @private_key, 'ES256', { typ: 'dpop+jwt', alg: 'ES256', jwk: jwk })
    end

    def generate_ath
      hash_bytes = OpenSSL::Digest.new('SHA256').digest(@access_token)
      Base64.urlsafe_encode64(hash_bytes, padding: false)
    end
  end
end
