require "mc_protocol/version"
require "mc_protocol/client"
require "mc_protocol/frame1e/client"
require "mc_protocol/device"
require "mc_protocol/config"
require "active_support/all"
require "i18n"

# I18n
I18n.enforce_available_locales = true if I18n.respond_to?(:enforce_available_locales=)
I18n.load_path += Dir[File.join(File.expand_path(File.dirname(__FILE__)), 'mc_protocol', 'config', 'locales', '**/*.yml')]
I18n.reload! if I18n.backend.initialized?

module McProtocol
end
