require "socket"
require "mc_protocol/config"
require "mc_protocol/exceptions"

module McProtocol
  class Client
    attr_accessor :socket,
                  :host,
                  :port,
                  :network_no,
                  :pc_no,
                  :unit_io_no,
                  :unit_station_no,
                  :frame,
                  :logger

    def initialize(host, port, options={})
      @host            = host
      @port            = port

      @logger = Logger.new(STDOUT)
      @logger.level = options[:log_level] || :info
    end

    def self.open(host, port, options={})
      plc = self.new host, port, options

      if plc.open
        yield plc
        plc.close
      end
    end

    def open
      begin
        return true if opened?

        Timeout.timeout(McProtocol.config.timeout) do
          @socket = TCPSocket.open @host, @port
          true
        end
      rescue => e
        @logger.info "retry to open connection..."

        retry_times = retry_times.blank? ? 1 : retry_times + 1
        retry if retry_times <= 3

        @logger.error e

        false
      end
    end

    def opened?
      @socket.present? && !@socket.closed?
    end

    def close
      @socket.close if opened?
      @socket = nil
    end

    def get_bit(device_name)
      get_bits(device_name, 1).first
    end

    def get_bits(device_name, count)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def get_word(device_name)
      get_words(device_name, 1).first
    end

    def get_words(device_name, count)
      device = Device.new device_name

      response = []

      repeat_set(device, count).each do |res|
        messages = build_get_words_message(device, res)

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

    def set_word(device_name, value)
      set_words(device_name, [value])
    end

    def set_words(device_name, values)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def set_bit(device_name, value)
      set_bits(device_name, [value])
    end

    def set_bits(device_name, values)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    private

    def write(messages)
      raise ConnectionNotOpened if opened?.blank?

      @logger.debug "> #{dump messages}"

      # TODO: Cなのかcなのか確認
      @socket.write messages.pack("c*")
      @socket.flush
    end

    def read(count)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def build_get_bits_message(device, count)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def build_get_words_message(device, count)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def build_set_bits_message(device, data)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def build_set_words_message(device, data)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def sub_header_message
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def message_for_monitoring_timer
      # | 監視タイマー |
      # | 0x10, 0x00   | (16 x 250ms = 4s)

      # 読出しおよび書込みの処理を完了するまでの待ち時間を設定します。
      # 接続局のE71がアクセス先へ処理を要求してから応答が返るまでの待ち時間を設定します。
      # 0000H(0): 無限待ち(処理が完了するまで待ち続けます。)
      # 0001H~FFFFH(1~65535): 待ち時間(単位: 250ms)

      [0x10, 0x00]
    end

    def message_for_get_bits_request_data(device, count)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def message_for_get_words_request_data(device, count)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def message_for_set_bits_request_data(device, data)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def message_for_set_words_request_data(device, data)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def message_for_request_data_device_name(device)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def message_for_request_data_device_count(count)
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def bit_data_length_limit
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    def word_data_length_limit
      raise NotImplementedError.new("You must implement #{self.name}.#{__method__}")
    end

    # 1度の通信で取得できるlimitを元にくり返し取得数配列を作成
    def repeat_set(device, count)
      # TODO: refactor
      limit = 0

      if device.bit_device?
        limit = bit_data_length_limit
      elsif device.word_device?
        limit = word_data_length_limit
      end

      counts = []

      divmod = count.divmod limit

      divmod.first.times do |i|
        counts << limit
      end

      counts << divmod.second if divmod.second > 0

      counts
    end

    def dump(packet)
      text = []
      len = packet.length
      _packet = packet.dup
      len.times do |i|
        text << ("0" + _packet[i].to_s(16))[-2, 2]
      end

      text.join " "
    end
  end
end
