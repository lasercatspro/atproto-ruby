# frozen_string_literal: true

module AtProto
  # Handles HTTP requests for the AT Protocol client
  # Throw the errors needed for the flow (Dpop and TokenInvalid)
  class Request
    # @return [URI] The URI for the request
    # @return [Symbol] The HTTP method to use
    # @return [Hash] Headers to be sent with the request
    # @return [String, nil] The request body
    attr_accessor :uri, :method, :headers, :body

    # Creates a new Request instance
    #
    # @param method [Symbol] The HTTP method (:get, :post, :put, :delete)
    # @param uri [String] The URI for the request
    # @param headers [Hash] Optional headers to include
    # @param body [String, nil] Optional request body
    # @return [Request] A new Request instance
    def initialize(method, uri, headers = {}, body = nil)
      @uri = URI(uri)
      @method = method
      @headers = headers
      @body = body
    end

    # Executes the HTTP request
    #
    # Makes the HTTP request with configured parameters and handles the response.
    # Automatically sets Content-Type and Accept headers to application/json.
    #
    # @return [Hash] Parsed JSON response body
    # @raise [Net::HTTPClientException] On bad request
    # @raise [TokenExpiredError] When the authentication token has expired
    # @raise [AuthError] When authentication fails
    # @raise [APIError] When the API returns an unexpected error
    def run
      request_class = HTTP_METHODS[method]
      req = request_class.new(uri).tap do |request|
        headers.each { |k, v| request[k] = v }
        request['Content-Type'] = 'application/json'
        request['Accept'] = 'application/json'
        request.body = body
      end
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(req)
      end
      handle_response(response)
    end

    private

    HTTP_METHODS = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put,
      delete: Net::HTTP::Delete
    }.freeze

    def handle_response(response)
      case response.code.to_i
      when 400
        body = JSON.parse(response.body)
        response.error! if body['error'] == 'use_dpop_nonce'
      when 401
        body = JSON.parse(response.body)
        raise TokenExpiredError if body['error'] == 'TokenExpiredError'

        raise AuthError, "Unauthorized: #{body['error']}"
      when 200..299
        JSON.parse(response.body)
      else
        raise APIError, "Request failed: #{response.code} - #{response.body}"
      end
    end
  end
end
