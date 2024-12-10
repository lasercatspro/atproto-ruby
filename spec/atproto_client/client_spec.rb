require 'spec_helper'

RSpec.describe AtProto::Client do
  let(:access_token) { 'test_access_token' }
  let(:private_key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:client) do
    described_class.new(
      access_token: access_token,
      private_key: private_key
    )
  end

  describe '#initialize' do
    it 'sets access tokens' do
      expect(client.access_token).to eq(access_token)
    end
  end

  describe '#request' do
    let(:url) { 'https://api.example.com/endpoint' }
    let(:method) { :get }
    let(:params) { { foo: 'bar' } }
    let(:body) { { data: 'test' } }

    it 'makes a request with correct parameters' do
      expect(client.dpop_handler).to receive(:make_request)
        .with(
          "#{url}?foo=bar",
          method,
          headers: { 'Authorization' => "DPoP #{access_token}" },
          body: body
        )
        .and_return(double('response'))

      client.request(method, url, params: params, body: body)
    end

    it 'allows setting custom headers' do
      custom_headers = { 'Content-Type' => 'image/jpeg' }
      expect(client.dpop_handler).to receive(:make_request)
        .with(
          "#{url}?foo=bar",
          method,
          headers: hash_including(custom_headers),
          body: body
        )
        .and_return(double('response'))

      client.request(method, url, params: params, body: body, headers: custom_headers)
    end

    context 'when token is expired' do
      it 'raises TokenExpiredError' do
        expect(client.dpop_handler).to receive(:make_request)
          .with(
            url,
            method,
            headers: { 'Authorization' => "DPoP #{access_token}" },
            body: nil
          )
          .and_raise(AtProto::TokenExpiredError)
          .ordered

        # The error should be raised to the caller
        expect { client.request(method, url) }
          .to raise_error(AtProto::TokenExpiredError)
      end
    end
  end

  describe '#get_token!' do
    let(:code) { 'auth_code' }
    let(:jwk) { { kid: 'key' } }
    let(:client_id) { 'client' }
    let(:site) { 'https://example.com' }
    let(:endpoint) { 'https://example.com/token' }
    let(:new_access_token) { 'new_access_token' }
    let(:redirect_uri) { 'https://example.com/oauth/callback' }

    let(:token_response) do
      {
        'access_token' => new_access_token,
        'refresh_token' => 'refresh_token'
      }
    end

    before do
      allow(client.dpop_handler).to receive(:make_request).and_return(token_response)
    end

    it 'updates access token after successful request' do
      client.get_token!(
        code: code,
        jwk: jwk,
        client_id: client_id,
        site: site,
        endpoint: endpoint,
        redirect_uri: redirect_uri
      )
      expect(client.access_token).to eq(new_access_token)
    end

    context 'when token request fails' do
      before do
        allow(client.dpop_handler).to receive(:make_request)
          .and_raise(AtProto::AuthError.new('Invalid authorization code'))
      end

      it 'raises AuthError' do
        expect do
          client.get_token!(
            code: code,
            jwk: jwk,
            client_id: client_id,
            site: site,
            endpoint: endpoint,
            redirect_uri: redirect_uri
          )
        end.to raise_error(AtProto::AuthError, 'Invalid authorization code')
      end
    end
  end

  describe '#refresh_token!' do
    let(:refresh_token) { 'refresh_token' }
    let(:jwk) { { kid: 'key' } }
    let(:client_id) { 'client' }
    let(:site) { 'https://example.com' }
    let(:endpoint) { 'https://example.com/token' }
    let(:new_access_token) { 'new_access_token' }
    let(:new_refresh_token) { 'new_refresh_token' }

    let(:refresh_response) do
      {
        access_token: new_access_token,
        refresh_token: new_refresh_token
      }.transform_keys(&:to_s)
    end

    before do
      allow(client.dpop_handler).to receive(:make_request).and_return(refresh_response)
    end

    it 'updates token after successful refresh' do
      client.refresh_token!(
        refresh_token: refresh_token,
        jwk: jwk,
        client_id: client_id,
        site: site,
        endpoint: endpoint
      )
      expect(client.access_token).to eq(new_access_token)
    end

    context 'when refresh fails' do
      before do
        allow(client.dpop_handler).to receive(:make_request)
          .and_raise(AtProto::AuthError.new('Invalid refresh token'))
      end

      it 'raises AuthError' do
        expect do
          client.refresh_token!(
            refresh_token: refresh_token,
            jwk: jwk,
            client_id: client_id,
            site: site,
            endpoint: endpoint
          )
        end.to raise_error(AtProto::AuthError, 'Invalid refresh token')
      end
    end
  end
end
