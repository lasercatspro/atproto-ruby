require 'spec_helper'

RSpec.describe AtProto::Client do
  let(:access_token) { 'test_access_token' }
  let(:refresh_token) { 'test_refresh_token' }
  let(:private_key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:client) do
    described_class.new(
      access_token: access_token,
      refresh_token: refresh_token,
      private_key: private_key
    )
  end

  describe '#initialize' do
    it 'sets access and refresh tokens' do
      expect(client.access_token).to eq(access_token)
      expect(client.refresh_token).to eq(refresh_token)
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

    context 'when token is expired' do
      let(:success_response) { double('success_response') }

      it 'retries once after refreshing token' do
        expect(client.dpop_handler).to receive(:make_request)
          .with(
            url,
            method,
            headers: { 'Authorization' => "DPoP #{access_token}" },
            body: nil
          )
          .and_raise(AtProto::TokenExpiredError)
          .ordered

        expect(client).to receive(:refresh_access_token!).ordered

        expect(client.dpop_handler).to receive(:make_request)
          .with(
            url,
            method,
            headers: { 'Authorization' => "DPoP #{access_token}" },
            body: nil
          )
          .and_return(success_response)
          .ordered

        expect(client.request(method, url)).to eq(success_response)
      end

      context 'when no refresh token is available' do
        let(:refresh_token) { nil }

        it 'raises TokenExpiredError without retrying' do
          expect(client.dpop_handler).to receive(:make_request)
            .with(
              url,
              method,
              headers: { 'Authorization' => "DPoP #{access_token}" },
              body: nil
            )
            .and_raise(AtProto::TokenExpiredError)
            .ordered

          # We should not attempt to refresh the token
          expect(client).not_to receive(:refresh_access_token!)

          # The error should be raised to the caller
          expect { client.request(method, url) }
            .to raise_error(AtProto::TokenExpiredError)
        end
      end
    end
  end

  describe '#refresh_access_token!' do
    let(:new_access_token) { 'new_access_token' }
    let(:new_refresh_token) { 'new_refresh_token' }
    let(:refresh_response) do
      instance_double(
        'Net::HTTPSuccess',
        body: {
          access_token: new_access_token,
          refresh_token: new_refresh_token
        }.to_json,
        is_a?: true
      )
    end

    before do
      allow(client.dpop_handler).to receive(:make_request).and_return(refresh_response)
      allow(AtProto.configuration).to receive(:base_url).and_return('https://api.example.com')
    end

    it 'updates tokens after successful refresh' do
      client.send(:refresh_access_token!)
      expect(client.access_token).to eq(new_access_token)
      expect(client.refresh_token).to eq(new_refresh_token)
    end

    context 'when refresh fails' do
      let(:refresh_response) do
        instance_double(
          'Net::HTTPBadRequest',
          body: 'error',
          code: '400',
          is_a?: false
        )
      end

      it 'raises RefreshTokenError' do
        expect { client.send(:refresh_access_token!) }
          .to raise_error(AtProto::RefreshTokenError, /Failed to refresh token/)
      end
    end
  end
end
