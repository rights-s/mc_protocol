module McProtocol
  class Device
    attr_accessor :prefix, :number, :category, :numeration, :code

    def initialize(device_name)
      @settings = settings

      _device_name = device_name.upcase

      @prefix = @settings.keys.select do |key|
        true if (_device_name =~ /^#{key}/).present?
      end.first

      raise "[#{device_name}] is not support device name." if @prefix.blank?

      setting     = @settings[@prefix.to_sym]
      @category   = setting[:category]
      @numeration = setting[:numeration]
      @code       = setting[:code][:binary]
      @number     = _device_name[@prefix.size..-1]

      raise "[#{device_name}] is not support device name." if @prefix.blank? || @number.blank?
    end

    def name
      "#{@prefix}#{@number}"
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

    def decimal_device?
      @numeration == :decimal
    end

    def hex_device?
      @numeration == :hex
    end

    def bit_device?
      @category == :bit
    end

    def word_device?
      @category == :word
    end

    def settings
      # TODO: refactor
      {
        SM: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "SM",
            binary: 0x91
          },
        },
        SD: {
          category: :word,
          numeration: :decimal,
          code: {
            ascii: "SD",
            binary: 0xa9
          },
        },
        X: {
          category: :bit,
          numeration: :hex,
          code: {
            ascii: "X*",
            binary: 0x9c
          },
        },
        Y: {
          category: :bit,
          numeration: :hex,
          code: {
            ascii: "Y*",
            binary: 0x9d
          },
        },
        M: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "M*",
            binary: 0x90
          },
        },
        L: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "L*",
            binary: 0x92
          },
        },
        F: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "F*",
            binary: 0x93
          },
        },
        V: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "V*",
            binary: 0x94
          },
        },
        B: {
          category: :bit,
          numeration: :hex,
          code: {
            ascii: "B*",
            binary: 0xa0
          },
        },
        D: {
          category: :word,
          numeration: :decimal,
          code: {
            ascii: "D*",
            binary: 0xa8
          },
        },
        W: {
          category: :word,
          numeration: :hex,
          code: {
            ascii: "W*",
            binary: 0xb4
          },
        },
        TS: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "TS",
            binary: 0xc1
          },
        },
        TC: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "TS",
            binary: 0xc0
          },
        },
        TN: {
          category: :word,
          numeration: :decimal,
          code: {
            ascii: "TS",
            binary: 0xc2
          },
        },
        STS: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "SS",
            binary: 0xc7
          },
        },
        STC: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "SC",
            binary: 0xc6
          },
        },
        STN: {
          category: :word,
          numeration: :decimal,
          code: {
            ascii: "SN",
            binary: 0xc8
          },
        },
        CS: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "CS",
            binary: 0xc4
          },
        },
        CC: {
          category: :bit,
          numeration: :decimal,
          code: {
            ascii: "CC",
            binary: 0xc3
          },
        },
        CN: {
          category: :word,
          numeration: :decimal,
          code: {
            ascii: "CN",
            binary: 0xc5
          },
        },
        SB: {
          category: :bit,
          numeration: :hex,
          code: {
            ascii: "SB",
            binary: 0xa1
          },
        },
        SW: {
          category: :word,
          numeration: :hex,
          code: {
            ascii: "SW",
            binary: 0xb5
          },
        },
        DX: {
          category: :bit,
          numeration: :hex,
          code: {
            ascii: "DX",
            binary: 0xa2
          },
        },
        DY: {
          category: :bit,
          numeration: :hex,
          code: {
            ascii: "DY",
            binary: 0xa3
          },
        },
        Z: {
          category: :word,
          numeration: :decimal,
          code: {
            ascii: "Z*",
            binary: 0xcc
          },
        },
        R: {
          category: :word,
          numeration: :decimal,
          code: {
            ascii: "R*",
            binary: 0xaf
          },
        },
        ZR: {
          category: :word,
          numeration: :hex,
          code: {
            ascii: "ZR",
            binary: 0xb0
          },
        },
      }
    end
  end
end
