module McProtocol
  class ConnectionNotOpened < StandardError; end

  class ProtocolError < StandardError
    attr_accessor :code

    def initialize(code)
      @code = code
      message = I18n.t "#{self.class.name.deconstantize.underscore}.errors.#{@code}", default: "unknown error."

      super("[#{code}] - #{message}")
    end
  end
end
