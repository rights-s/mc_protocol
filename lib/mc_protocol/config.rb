require "active_support/configurable"

module McProtocol
  def self.configure(&block)
    yield @config ||= McProtocol::Configuration.new
  end

  def self.config
    @config
  end

  class Configuration
    include ActiveSupport::Configurable
    config_accessor :timeout
  end

  configure do |config|
    config.timeout = 2.0
  end
end
