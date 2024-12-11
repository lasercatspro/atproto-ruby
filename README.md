# ATProto Client

Ruby client for the AT Protocol, with support for oauth/dpop authentication.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'atproto_client'
```

## Usage

```ruby

# Initialize with your private key and existing access token
client = AtProto::Client.new(private_key:, access_token:)

# Then request
client.request(
  :get,
  "https://boletus.us-west.host.bsky.network/xrpc/app.bsky.feed.getPostThread",
  params: { uri: "at://did:plc:sdy3olcdgcxvy3enfgsujz43/app.bsky.feed.post/3lbr6ey544s2k"}
)

# Body and params are optionals
# Body will be stringified to json if it's a hash
client.request(
  :post,
  "#{pds_endpoint}/xrpc/com.atproto.repo.createRecord",
  body: {
    repo: did,
    collection: "app.bsky.feed.post",
    record: {
      text: "Posting from ruby",
      createdAt: Time.now.iso8601,
    }
  }
)

# Can make requests with headers and custom body type 
client.request(
  :post,
  "#{pds_endpoint}/xrpc/com.atproto.repo.uploadBlob",
  body: image_data,
  headers: {
    "Content-Type": content_type,
    "Content-Length": content_length
  }
)

# Refresh token when needed
# Tokens are returned so they can be stored
client.refresh_token!(refresh_token:, jwk:, client_id:, site:, endpoint: )

# Get initial access_token
# (to be used in oauth flow -- see https://github.com/lasercatspro/omniauth-atproto)
client = AtProto::Client.new(private_key: key)
client.get_token!(code:, jwk:, client_id:, site:, endpoint:, code_verifier)

```
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lasercats/atproto-ruby.

## License

The gem is available as open source under the terms of the MIT License.
