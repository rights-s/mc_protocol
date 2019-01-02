# McProtocol

三菱電機製品の通信プロトコルであるMCプロトコルTCP通信ライブラリです。

## サポートしているプロトコル

MCプロトコルはフレームの異なる4つの通信方式があります。
このライブラリで対応しているのは以下２つになります。

* 3Eフレーム
* 1Eフレーム

## インストール方法

Gemによるインストール

    $ gem install rights-s/gem-mc_protocol

Gemfileによるインストール

```ruby
gem 'mc_protocol'
```

    $ bundle

## 使い方

コンフィグファイルの追加(Rails)

    $ rails g mc_protocol:config

通信方法

### 初期化

    > client = McProtocol::Frame1e::Client.new "192.168.1.160", 3000

### オプション

    > client = McProtocol::Frame1e::Client.new "192.168.1.160", 3000, log_level: :debug
    
* log_level ... ログレベル
* pc_no ... PC番号
* network_no ... ネットワークNo
* unit_io_no ... ユニットNo
* unit_station_no ... ステーションNo

### オープン

    > client.open

### 初期化 & オープン

    > client = McProtocol::Frame1e::Client.open "192.168.1.160", 3000

### ビット呼出

M10を読込み

    > client.get_bit "M10"

M10から100点を読込み

    > client.get_bits "M10", 100

### ビット書込

M10を書き込み

    > client.set_bit "M10", true

M10から4点を書き込み

    > client.set_bits "M10", [1, 0, 1, 0]

### ワード呼出

D10を読込み

    > client.get_word "D10"

D10から100点を読込み

    > client.get_words "D10", 100

### ワード書込

D10を書き込み

    > client.set_word "D10", 1200

D10から4点を書き込み

    > client.set_words "D10", [1200, 0, 2400, -360]

### ブロックの利用

```ruby
McProtocol::Frame1e::Client.open "192.168.1.160", 3000, do |client|
  client.set_bit "M1", 1
end
```
