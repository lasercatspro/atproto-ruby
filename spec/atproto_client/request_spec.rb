require 'spec_helper'

RSpec.describe AtProto::Request do
  let(:uri) { 'https://example.com/api' }
  let(:method) { :post }
  let(:headers) { { 'X-Custom' => 'value' } }
  let(:body) { '{"data":"test"}' }
  let(:request) { described_class.new(method, uri, headers, body) }

  describe '#initialize' do
    it 'sets instance variables correctly' do
      expect(request.uri).to be_a(URI)
      expect(request.uri.to_s).to eq(uri)
      expect(request.method).to eq(method)
      expect(request.headers).to eq(headers)
      expect(request.body).to eq(body)
    end
  end

  describe '#run' do
    let(:mock_response) { instance_double(Net::HTTPSuccess) }
    let(:response_body) { '{"result":"success"}' }

    before do
      allow(mock_response).to receive(:code).and_return('200')
      allow(mock_response).to receive(:body).and_return(response_body)
      allow(Net::HTTP).to receive(:start).and_yield(double('http').tap do |http|
        allow(http).to receive(:request).and_return(mock_response)
      end)
    end

    it 'makes HTTP request with correct parameters' do
      expect(Net::HTTP).to receive(:start).with(
        'example.com',
        443,
        use_ssl: true
      )

      request.run
    end

    it 'sets default headers' do
      mock_request = instance_double(Net::HTTP::Post)
      allow(Net::HTTP::Post).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:[]=)
      allow(mock_request).to receive(:body=)

      expect(mock_request).to receive(:[]=).with('Content-Type', 'application/json')
      expect(mock_request).to receive(:[]=).with('Accept', 'application/json')
      expect(mock_request).to receive(:[]=).with('X-Custom', 'value')

      request.run
    end

    context 'when response is successful' do
      it 'returns parsed JSON response' do
        expect(request.run).to eq({ 'result' => 'success' })
      end
    end

    context 'when response indicates token expired' do
      let(:error_response) { '{"error":"invalid_token"}' }

      before do
        allow(mock_response).to receive(:code).and_return('401')
        allow(mock_response).to receive(:body).and_return(error_response)
      end

      it 'raises TokenExpiredError' do
        expect { request.run }.to raise_error(AtProto::TokenExpiredError)
      end
    end

    context 'when response indicates authentication error' do
      let(:error_response) { '{"error":"unauthorized","message":"Invalid credentials"}' }

      before do
        allow(mock_response).to receive(:code).and_return('401')
        allow(mock_response).to receive(:body).and_return(error_response)
      end

      it 'raises AuthError with message' do
        expect { request.run }
          .to raise_error(AtProto::AuthError, 'Unauthorized: unauthorized - Invalid credentials')
      end
    end

    context 'when response is an unexpected error' do
      before do
        allow(mock_response).to receive(:code).and_return('500')
        allow(mock_response).to receive(:body).and_return('Internal Server Error')
      end

      it 'raises APIError' do
        expect { request.run }
          .to raise_error(AtProto::APIError, 'Request failed: 500 - Internal Server Error')
      end
    end
  end
end
