module AtProto
  class Configuration
    attr_accessor :base_url

    def initialize
      @base_url = 'https://bsky.social'
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
