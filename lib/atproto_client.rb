require 'atproto_client/version'
require 'jwt'
require 'openssl'
require 'securerandom'
require 'base64'
require 'json'
require 'net/http'
require 'uri'

module AtProto
  class Error < StandardError; end

  class AuthError < Error; end

  class TokenExpiredError < AuthError; end

  class RefreshTokenError < AuthError; end

  class APIError < Error; end
end

require 'atproto_client/configuration'
require 'atproto_client/client'
require 'atproto_client/dpop_handler'
require 'atproto_client/request'
