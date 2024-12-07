require 'spec_helper'
require 'jwt'
require 'openssl'
require 'base64'

RSpec.describe AtProto::DpopHandler do
  let(:private_key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:handler) { described_class.new(private_key) }
  let(:http_method) { 'POST' }
  let(:url) { 'https://example.com/api' }

  describe '#initialize' do
    it 'creates a new handler with a generated private key' do
      handler = described_class.new
      expect(handler.instance_variable_get(:@private_key)).to be_a(OpenSSL::PKey::EC)
    end

    it 'creates a new handler with a provided private key' do
      handler = described_class.new(private_key)
      expect(handler.instance_variable_get(:@private_key)).to eq(private_key)
    end
  end

  describe '#generate_token' do
    let(:token) { handler.generate_token(http_method, url) }
    let(:decoded_token) { JWT.decode(token, private_key, true, { algorithm: 'ES256' }).first }

    it 'generates a valid JWT token' do
      expect { decoded_token }.not_to raise_error
    end

    it 'includes required claims in the token' do
      expect(decoded_token).to include(
        'htm' => http_method,
        'htu' => url
      )
      expect(decoded_token['jti']).to be_a(String)
      expect(decoded_token['iat']).to be_a(Integer)
      expect(decoded_token['exp']).to be_a(Integer)
    end

    context 'with access token' do
      let(:access_token) { 'test-access-token-123' }
      let(:handler) { described_class.new(private_key, access_token) }
      let(:token) { handler.generate_token(http_method, url) }
      let(:decoded_token) { JWT.decode(token, private_key, true, { algorithm: 'ES256' }).first }

      it 'includes correct ath claim' do
        expected_ath = Base64.urlsafe_encode64(
          OpenSSL::Digest.new('SHA256').digest(access_token),
          padding: false
        )
        expect(decoded_token['ath']).to eq(expected_ath)
      end
    end

    context 'without access token' do
      it 'does not include ath claim' do
        expect(decoded_token).not_to have_key('ath')
      end
    end

    context 'with nonce' do
      let(:nonce) { 'test-nonce-123' }
      let(:token_with_nonce) { handler.generate_token(http_method, url, nonce) }
      let(:decoded_token_with_nonce) do
        JWT.decode(token_with_nonce, private_key, true, { algorithm: 'ES256' }).first
      end

      it 'includes nonce in the token when provided' do
        expect(decoded_token_with_nonce['nonce']).to eq(nonce)
      end
    end
  end

  describe '#update_nonce' do
    let(:mock_response) { double('response', to_hash: { 'dpop-nonce' => ['new-nonce-123'] }) }

    it 'updates the current nonce from response headers' do
      handler.update_nonce(mock_response)
      expect(handler.instance_variable_get(:@current_nonce)).to eq('new-nonce-123')
    end
  end

  describe '#make_request' do
    let(:mock_response) { double('response', code: '200', body: 'success') }
    let(:mock_request) { double('request') }

    before do
      allow(AtProto::Request).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:run).and_return(mock_response)
      allow(mock_request).to receive(:body=)
    end

    it 'makes a request with DPoP token in headers' do
      expect(AtProto::Request).to receive(:new).with(
        'POST',
        url,
        hash_including('DPoP' => kind_of(String))
      )

      handler.make_request(url, 'POST')
    end

    it 'allows setting custom headers' do
      custom_headers = { 'Content-Type' => 'image/jpeg' }
      expect(AtProto::Request).to receive(:new).with(
        'POST',
        url,
        hash_including(custom_headers)
      )

      handler.make_request(url, 'POST', headers: custom_headers)
    end

    it 'allows setting a binary body' do
      binary_data = File.binread('spec/fixtures/cat.jpg')
      expect { handler.make_request(url, 'POST', body: binary_data) }.not_to raise_error
    end

    context 'with retry on nonce error' do
      let(:error_response) { double('error_response', to_hash: { 'dpop-nonce' => ['retry-nonce'] }) }
      let(:error) { Net::HTTPClientException.new('error', error_response) }

      it 'retries once with new nonce on failure' do
        allow(mock_request).to receive(:run).and_raise(error).once
        allow(error_response).to receive(:code).and_return('401')
        allow(error_response).to receive(:body).and_return('error')

        expect(mock_request).to receive(:run).and_return(mock_response)

        handler.make_request(url, 'POST')
      end
    end
  end
end
