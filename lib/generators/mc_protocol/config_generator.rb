module McProtocol
  module Generators
    # rails g mc_protocol:config
    class ConfigGenerator < Rails::Generators::Base
      source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

      desc <<DESC
Description:
    Copies McProtocol configuration file to your application's initializer directory.
DESC

      def copy_config_file
        template 'mc_protocol_config.rb', 'config/initializers/mc_protocol_config.rb'
      end
    end

  end

end
