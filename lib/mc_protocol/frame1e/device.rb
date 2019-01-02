require "mc_protocol/device"

module McProtocol::Frame1e
  class Device < McProtocol::Device
    attr_accessor :prefix, :number, :category, :numeration, :code, :code_1e

    def initialize(device_name)
      _device_name = device_name.upcase

      @prefix = settings.keys.select do |key|
        true if (_device_name =~ /^#{key}/).present?
      end.first

      raise "[#{device_name}] is not support device name." if @prefix.blank?

      setting     = settings[@prefix.to_sym]
      @category   = setting[:category]
      @numeration = setting[:numeration]
      @code       = setting[:code]
      @number     = _device_name[@prefix.size..-1]

      raise "[#{device_name}] is not support device name." if @prefix.blank? || @number.blank?
    end

    def number_int
      if decimal_device?
        number.to_i
      elsif hex_device?
        number.hex
      end
    end

    def next_device
      offset_device 1
    end

    def offset_device(offset)
      if decimal_device?
        @number = (number_int + offset).to_s
      elsif hex_device?
        @number = (number_int  + offset).to_s(16)
      end
    end

    private

    def settings
      {
        X: {
          category:   :bit,
          numeration: :hex,
          code:       "X ",
        },
        UY: {
          category:   :bit,
          numeration: :hex,
          code:       "Y ",
        },
        M: {
          category:   :bit,
          numeration: :decimal,
          code:       "M ",
        },
        F: {
          category:   :bit,
          numeration: :decimal,
          code:       "F ",
        },
        B: {
          category:   :bit,
          numeration: :hex,
          code:       "B ",
        },
        TN: {
          category:   :word,
          numeration: :decimal,
          code:       "TN",
        },
        TS: {
          category:   :bit,
          numeration: :decimal,
          code:       "TS",
        },
        TC: {
          category:   :bit,
          numeration: :decimal,
          code:       "TC",
        },
        CN: {
          category:   :word,
          numeration: :decimal,
          code:       "CN",
        },
        CS: {
          category:   :bit,
          numeration: :decimal,
          code:       "CS",
        },
        CC: {
          category:   :bit,
          numeration: :decimal,
          code:       "CC",
        },
        D: {
          category:   :word,
          numeration: :decimal,
          code:       "D ",
        },
        W: {
          category:   :word,
          numeration: :hex,
          code:       "W ",
        },
        R: {
          category:   :word,
          numeration: :decimal,
          code:       "R ",
        },
      }
    end
  end
end

