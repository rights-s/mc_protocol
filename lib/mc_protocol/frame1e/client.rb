require "mc_protocol/frame1e/device"

module McProtocol::Frame1e
  BIT_DATA_LENGTH_LIMIT = 256
  WORD_DATA_LENGTH_LIMIT = 128

  class Client < McProtocol::Client
    def initialize(host, port, options={})
      super host, port, options
      @pc_no = options[:pc_no] || 0xff
    end

    def get_bits(device_name, count)
      device = Device.new device_name

      response = []

      repeat_set(device, count).each do |res|
        messages = build_get_bits_message(device, res)

        @logger.info "READ: #{device.name}, #{res}"
        write messages

        data = read res

        data.each_with_index do |d, i|
          response << (d & 16 > 0)

          next if i == data.size - 1 && res.odd?

          response << (d & 1 > 0)
        end

        device.offset_device res
      end

      @logger.debug "= #{response.join(' ')}"

      response
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
        messages = build_set_bits_message(device, _values[0, res])

        @logger.info "WRITE: #{device.name}, #{_values[0, res]}"

        write messages

        _response = read(0)
        response << _response

        _values.shift res
        device.offset_device res
      end
    end

    def get_words(device_name, count)
      device = Device.new device_name

      response = []

      repeat_set(device, count).each do |res|
        messages = build_get_words_message(device, res)

        @logger.info "READ: #{device.name}, #{res}"
        write messages

        data = read(res * 8)

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
    end

    private

    def read(count)
      res = []
      len = 0
      begin
        Timeout.timeout(McProtocol.config.timeout) do
          loop do
            c = @socket.read(1)
            next if c.nil? || c == ""

            res << c.bytes.first

            next if res.length < 2

            # 終了コード
            if res[1] == 0
              # 正常終了 サブヘッダ+終了コード+応答データ数分のByte数を受信
              break if res.size >= 2 + (count / 2.0).ceil

            else
              # 異常終了 サブヘッダ+終了コード+異常コード数分のByte数を受信
              break if res.size >= 3

            end
          end
        end

      rescue Timeout::Error
        @logger.debug "< #{dump res}"
        @logger.error "ERROR: Response time out."
      end

      @logger.debug "< #{dump res}"

      # 終了コード(エラーコード)
      if res[1] != 0x00
        if res[1] == 0x5b
          raise ProtocolError.new res[2]
        else
          raise "不明なエラー"
        end
      end

      data = res[2..-1]
      return data
    end

    private

    def build_get_bits_message(device, count)
      # | サブヘッダ | PC番号 | ACPU監視タイマ | 要求データ                              |
      # | 0x00       | 0xff   | 0x10 0x00      | 0xD2 0x04 0x00 0x00 0x20 0x44 0x05 0x00 |
      #
      # サブヘッダ 0x00 - ビット単位の一括読出
      #            0x01 - ワード単位の一括読出
      #            0x02 - ビット単位の一括書込
      #            0x03 - ワード単位の一括書込
      # PC番号     0xff - 自局
      #            0x03 - 他局（局番）
      # ACPU監視タイマ(3Eと同じ)

      messages = []
      messages.concat [0x00] # サブヘッダ
      messages.concat [@pc_no] # PC番号
      messages.concat message_for_monitoring_timer # ACPU監視タイマ
      messages.concat message_for_get_bits_request_data(device, count)

      messages
    end

    def build_get_words_message(device, count)
      messages = []
      messages.concat [0x01] # サブヘッダ
      messages.concat [@pc_no] # PC番号
      messages.concat message_for_monitoring_timer # ACPU監視タイマ
      messages.concat message_for_get_words_request_data(device, count)

      messages
    end

    def build_set_bits_message(device, data)
      # TODO: フォーマット

      messages = []
      messages.concat [0x02] # サブヘッダ
      messages.concat [@pc_no] # PC番号
      messages.concat message_for_monitoring_timer # ACPU監視タイマ
      messages.concat message_for_set_bits_request_data(device, data)

      messages
    end

    def message_for_get_bits_request_data(device, count)
      # 要求データ
      # | 先頭デバイス                         | デバイス点数 | 固定値 |
      # | デバイス番号        | デバイスコード | デバイス点数 | 固定値 |
      # | 50                  | M              | 12           | 0x00   |
      # | 0xd2 0x04 0x00 0x00 | 0x20 0x4d      | 0x0c         | 0x00   |
      messages = []
      messages.concat message_for_request_data_device_name(device)
      messages.concat message_for_request_data_device_count(count)
      messages.concat [0]

      messages
    end

    def message_for_get_words_request_data(device, count)
      messages = []
      messages.concat message_for_request_data_device_name(device)
      messages.concat message_for_request_data_device_count(count)
      messages.concat [0]

      messages
    end

    def message_for_request_data_device_name(device)
      # | デバイス番号        | デバイスコード |
      # | 0xd2 0x04 0x00 0x00 | 0xa8           |

      # デバイス番号 4byte
      # 内部リレー (M)1234の場合(デバイス番号が10進数のデバイスの場合)
      # バイナリコード時は，デバイス番号を16進数に変換します。"1234"(10進) => "4D2"(16進)
      # デバイス番号: 4バイトの数値を下位バイト(L: ビット0~7)から送信します

      message = []

      p device.class
      if device.decimal_device?
        message.concat [device.number_int].pack("V").unpack("C*")

      elsif device.hex_device?
        message.concat [device.number.hex].pack("V").unpack("C*")

      end
      message.concat device.code.unpack("C*").reverse

      message
    end

    def message_for_set_bits_request_data(device, data)
      messages = []
      messages.concat message_for_request_data_device_name(device)
      messages.concat message_for_request_data_device_count(data.size)
      messages.concat [0]

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

    def message_for_request_data_device_count(count)
      # | デバイス点数 |
      # | 0x0c         | (10点)
      if count.zero?
        [0]
      else
        [count]
      end
    end

    def bit_data_length_limit
      BIT_DATA_LENGTH_LIMIT
    end

    def word_data_length_limit
      WORD_DATA_LENGTH_LIMIT
    end
  end
end
