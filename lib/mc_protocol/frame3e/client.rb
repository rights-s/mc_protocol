require "mc_protocol/frame3e/device"

module McProtocol::Frame3e
  BIT_DATA_LENGTH_LIMIT = 7168
  WORD_DATA_LENGTH_LIMIT = 960

  attr_accessor :pc_no,
                :network_no,
                :unit_io_no,
                :unit_station_no

  class Client < McProtocol::Client
    def initialize(host, port, options={})
      super host, port, options

      @pc_no            = options[:pc_no]           || 0xff
      @network_no       = options[:network_no]      || 0x00
      @unit_io_no       = options[:unit_io_no]      || [0xff, 0x03]
      @unit_station_no  = options[:unit_station_no] || 0x00
    end

    def get_words(device_name, count)
      device = Device.new device_name

      response = []

      repeat_set(device, count).each do |res|
        messages = get_words_message(device, res)

        @logger.info "READ: #{device.name}, #{res}"
        write messages

        data = read(res)

        data.each_slice(2) do |pair|
          response << pair.pack("c*").unpack("s<").first
        end

        # response.concat receive

        device.offset_device res
      end

      @logger.debug "= #{response.join(' ')}"

      response
    rescue => e
      @logger.error e
    end

    def set_words(device_name, values)
      device = Device.new device_name

      _values = values.dup

      repeat_set(device, values.size).each do |res|
        messages = set_words_message(device, _values[0, res])

        @logger.info "WRITE: #{device.name}, #{_values}"

        write messages
        response = read(res)

        _values.shift res
        device.offset_device res
      end
    end

    def get_bits(device_name, count)
      device = Device.new device_name

      response = []

      repeat_set(device, count).each do |res|
        messages = get_bits_message(device, res)

        @logger.info "READ: #{device.name}, #{res}"
        write messages

        data = read(res)

        data.each_with_index do |d, i|
          response << (d & 16 > 0)

          next if i == data.size - 1 && res.odd?

          response << (d & 1 > 0)
        end

        device.offset_device res
      end

      @logger.debug "= #{response.join(' ')}"

      response
    rescue => e
      @logger.error e
    end

    def set_bits(device_name, values)
      device = Device.new device_name

      response = []
      _values = values.dup

      # 変換
      _values.map! do |v|
        if v.is_a? Integer
          v > 0
        else
          v
        end
      end

      repeat_set(device, values.size).each do |res|
        messages = set_bits_message(device, _values[0, res])

        @logger.info "WRITE: #{device.name}, #{_values[0, res]}"

        write messages

        _response = read(res)
        response << _response
        # TODO: Writeの場合はレスポンスがない。
        # 終了コードを取得する方が良いか？

        _values.shift res
        device.offset_device res
      end
    end

    def read(count)
      res = []
      len = 0
      begin
        Timeout.timeout(McProtocol.config.timeout) do
          loop do
            c = @socket.read(1)
            next if c.nil? || c == ""

            res << c.bytes.first

            # 応答データ長(8-9byte)を確認
            len = res[7, 2].pack("c*").unpack("v*").first if res.length >= 9
            break if (len + 9 == res.length)
          end
        end

      rescue Timeout::Error
        @logger.debug "< #{dump res}"
        @logger.error "ERROR: Response time out."
      end

      @logger.debug "< #{dump res}"

      # sample
      # "\xD0\x00\x00\xFF\xFF\x03\x00\x16\x00\x00\x00\v\x00\f\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"

      # 応答電文ヘッダチェック D000
      # TODO: 無効なレスポンスの場合、どうなるのか確認
      return [] if res[0] != 0xd0 || res[1] != 0x00

      # 応答電文アクセス経路チェック
      return [] if res[2..6] != message_for_access_route

      # 応答データ長
      length = res[7..8].pack("c*").unpack("v*").first

      # 終了コード(エラーコード)
      end_code = res[9..10].reverse.pack("c*").unpack("H*").first.upcase
      raise ProtocolError.new end_code if end_code != "0000"

      # データ
      data = res[11..-1]
      return data
    end

    def get_bits_message(device, count)
      # | サブヘッダ | アクセス経路             | データ長  | 監視タイマ| 要求データ                                   |
      # | 0x50 0x00  | 0x00 0xff 0xff 0x03 0x00 | 0x10 0x00 | 0x10 0x00 | 0x04 0x00 0x00 0x64 0x00 0x00 0xa8 0x0a 0x00 |

      m1 = monitoring_timer_message
      m2 = message_for_get_bits_request_data(device, count)

      messages = []
      messages.concat sub_header_message                  # サブヘッダメッセージ
      messages.concat message_for_access_route                # アクセス経路メッセージ
      messages.concat message_for_request_data_length(m1, m2) # 要求データ長メッセージ
      messages.concat m1                                      # 監視タイマーメッセージ
      messages.concat m2                                      # 要求データメッセージ

      messages
    end

    def get_words_message(device, count)
      # | サブヘッダ | アクセス経路             | データ長  | 監視タイマ| 要求データ                                   |
      # | 0x50 0x00  | 0x00 0xff 0xff 0x03 0x00 | 0x10 0x00 | 0x10 0x00 | 0x04 0x00 0x00 0x64 0x00 0x00 0xa8 0x0a 0x00 |

      m1 = monitoring_timer_message
      m2 = message_for_get_words_request_data(device, count)

      messages = []
      messages.concat sub_header_message                  # サブヘッダメッセージ
      messages.concat message_for_access_route                # アクセス経路メッセージ
      messages.concat message_for_request_data_length(m1, m2) # 要求データ長メッセージ
      messages.concat m1                                      # 監視タイマーメッセージ
      messages.concat m2                                      # 要求データメッセージ

      messages
    end

    def set_bits_message(device, data)
      # | サブヘッダ | アクセス経路             | データ長  | 監視タイマ| 要求データ                                                            |
      # | 0x50 0x00  | 0x00 0xff 0xff 0x03 0x00 | 0x10 0x00 | 0x10 0x00 | 0x01 0x14 0x00 0x00 0x60 0x00 0x00 0x90 0x02 0x00 0x0a 0x00 0x14 0x00 |

      m1 = monitoring_timer_message
      m2 = message_for_set_bits_request_data(device, data)

      messages = []
      messages.concat sub_header_message                  # サブヘッダメッセージ
      messages.concat message_for_access_route                # アクセス経路メッセージ
      messages.concat message_for_request_data_length(m1, m2) # 要求データ長メッセージ
      messages.concat m1                                      # 監視タイマーメッセージ
      messages.concat m2                                      # 要求データメッセージ

      messages
    end

    def set_words_message(device, data)
      # | サブヘッダ | アクセス経路             | データ長  | 監視タイマ| 要求データ                                                            |
      # | 0x50 0x00  | 0x00 0xff 0xff 0x03 0x00 | 0x10 0x00 | 0x10 0x00 | 0x01 0x14 0x00 0x00 0x60 0x00 0x00 0x90 0x02 0x00 0x0a 0x00 0x14 0x00 |

      m1 = monitoring_timer_message
      m2 = message_for_set_words_request_data(device, data)

      messages = []
      messages.concat sub_header_message                  # サブヘッダメッセージ
      messages.concat message_for_access_route                # アクセス経路メッセージ
      messages.concat message_for_request_data_length(m1, m2) # 要求データ長メッセージ
      messages.concat m1                                      # 監視タイマーメッセージ
      messages.concat m2                                      # 要求データメッセージ

      messages
    end

    def sub_header_message
      # | 要求電文  |
      # | 0x50 0x00 |

      [0x50, 0x00]
    end

    def message_for_access_route
      # | ネットワーク番号 | PC番号 | 要求先ユニットI/O番号 | 要求先ユニット局番号 |
      # | 0x00             | 0xff   | 0xff 0x03             | 0x00                 |

      numbers = []
      numbers << @network_no      # ネットワーク番号      アクセス先のネットワークNo.を指定します。
      numbers << @pc_no           # PC番号                アクセス先のネットワークユニットの局番を指定します。
      numbers << @unit_io_no      # 要求先ユニットI/O番号 マルチドロップ接続局にアクセスする場合に，マルチドロップ接続元ユニットの先頭入 出力番号を指定します。
                                  #                       マルチCPUシステム，二重化システムのCPUユニットを指定します。
      numbers << @unit_station_no # 要求先ユニット局番号  マルチドロップ接続局にアクセスする場合に，アクセス先ユニットの局番を指定します。

      numbers.flatten
    end

    def message_for_request_data_length(m1, m2)
      # | 要求データ長 |
      # | 0x0c 0x00    | (12 byte)

      [m1.size + m2.size].pack("v").unpack("c*")
    end

    def message_for_get_bits_request_data(device, count)
      messages = [0x01, 0x04, 0x01, 0x00]
      messages.concat message_for_request_data_device_name(device)
      messages.concat message_for_request_data_device_count(count)

      messages
    end

    def message_for_get_words_request_data(device, count)
      messages = [0x01, 0x04, 0x00, 0x00]
      messages.concat message_for_request_data_device_name(device)
      messages.concat message_for_request_data_device_count(count)

      messages
    end

    def message_for_set_bits_request_data(device, data)
      messages = [0x01, 0x14, 0x01, 0x00]
      messages.concat message_for_request_data_device_name(device)
      messages.concat message_for_request_data_device_count(data.size)

      _data = []
      data.each_slice(2) do |pair|
        _t = 0
        if pair.first == true
          _t = _t | 16
        end

        if pair.size == 1
          _data << _t
          next
        end

        if pair.last == true
          _t = _t | 1
        end

        _data << _t
      end

      __data = _data.pack("c*").unpack("C*")

      # messages.concat _data.pack("s*").unpack("C*")
      messages.concat __data


      messages
    end

    def message_for_set_words_request_data(device, data)
      messages = [0x01, 0x14, 0x00, 0x00]
      messages.concat message_for_request_data_device_name(device)
      messages.concat message_for_request_data_device_count(data.size)
      messages.concat data.pack("s*").unpack("C*")

      messages
    end

    def message_for_request_data_device_name(device)
      # | デバイス番号   | デバイスコード |
      # | 0x64 0x00 0x00 | 0xa8           |

      # デバイス番号 3byte
      # 内部リレー (M)1234の場合(デバイス番号が10進数のデバイスの場合)
      # バイナリコード時は，デバイス番号を16進数に変換します。"1234"(10進) => "4D2"(16進)

      message = []

      if device.decimal_device?
        message.concat [device.number_int].pack("V").unpack("c*")

      elsif device.hex_device?
        message.concat [device.number.hex].pack("V").unpack("c*")

      end

      message[3] = device.code

      message
    end

    def message_for_request_data_device_count(count)
      # | デバイス点数 |
      # | 0x02 0x00    | (10点)
      [count].pack("v").unpack("c*")
    end

    def bit_data_length_limit
      BIT_DATA_LENGTH_LIMIT
    end

    def word_data_length_limit
      WORD_DATA_LENGTH_LIMIT
    end
  end
end
