#-*- coding: utf-8 -*-

require 'socket'
require 'json'
require 'cgi'
require 'weather_jp'

Plugin.create :shell_post do

  COMPILE_TMPDIR = "/dev/shm/mikutter_scratch"

  def postal_search(query, mode = :auto)
    s = TCPSocket.new("api.postalcode.jp", 80)

    if mode == :zipcode
      s.write("GET /v1/zipsearch?zipcode=#{query} HTTP/1.0\r\n\r\n")
    elsif mode == :word
      s.write("GET /v1/zipsearch?word=#{CGI.escape(query)} HTTP/1.0\r\n\r\n")
    else
      if query =~ /[0-9]+/
        s.write("GET /v1/zipsearch?zipcode=#{query} HTTP/1.0\r\n\r\n")
      else
        s.write("GET /v1/zipsearch?word=#{CGI.escape(query)} HTTP/1.0\r\n\r\n")
      end
    end

    str = s.read
    s.close

    data = JSON.parse(str[str.index('{')..-1])
    result = ""
    if data["zipcode"].length == 0
      result = "検索結果がなかったよ(´・ω・｀)"
    elsif data["zipcode"].length <= 10
      data["zipcode"].each { |key, value|   
        result += "〒#{value["zipcode"][0..2]}-#{value["zipcode"][3..-1]} #{value["prefecture"]}#{value["city"]}#{value["town"]}\n"
      }
    else
      result += "検索結果の10件を表示するよ！\n"
      count = 0
      data["zipcode"].each { |key, value|
        result += "〒#{value["zipcode"][0..2]}-#{value["zipcode"][3..-1]} #{value["prefecture"]}#{value["city"]}#{value["town"]}\n"
        count += 1
        if count >= 10
          break
        end
      }
      result += "全部で#{data["zipcode"].length}通り見つかったよ\n"
    end
    result
  end


  # PostBoxの中身をクリアしてイベントをキャンセル
  def clear_post(gui_postbox)
    Plugin.call(:before_postbox_post,
                Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text)
    Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text = ''
    Plugin.filter_cancel!
  end

  def command_escape(str)
    str.gsub(/'/, '''\'''\\\\''\'''''\'''')    
  end

  def source_escape(str)
    str.gsub(/'/, '''\'''')    
  end

  def gen_random_str
    (("a".."z").to_a + ("A".."Z").to_a + (0..9).to_a).shuffle[0..20].join
  end
  
  # @shell または @shell_p に向けたリプライをシェルコマンドと解釈する
  filter_gui_postbox_post do |gui_postbox|
    text = Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text

    # @system に向けたリプライはmikutterコマンドとして処理する
    if text =~ /^@system\s+(.+)/
      Thread.new{
        begin
          result = Kernel.instance_eval($1)
          Plugin.call(:update, nil, [Message.new(:message => "#{result.to_s}", :system => true)])
        rescue Exception => e
          Plugin.call(:update, nil, [Message.new(:message => "失敗しました(´・ω・｀)\nコードを確認してみて下さい↓\n#{text}", :system => true)])
        end
      }
      clear_post(gui_postbox)

    # @shell に向けたリプライは10秒でtimeoutする
    elsif text =~ /^@shell\s+(.+)/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 #{$1}`}", :system => true)])
      }
      clear_post(gui_postbox)

    # @shell_p に向けたリプライはtimeoutしない
    elsif text =~ /^@shell_p\s+(.+)/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "exit #{$1}:\n#{`#{$1}`}", :system => true)])
      }
      clear_post(gui_postbox)

    # Rubyで実行
    elsif text =~ /^@shell_rb\s+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 ruby -e '#{command_escape(text, '@shell_rb')}'`}", :system => true)])
      }
      clear_post(gui_postbox)

    # Pythonで実行
    elsif text =~ /^@shell_py\s+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 python -c '#{command_escape(text, '@shell_py')}'`}", :system => true)])
      }
      clear_post(gui_postbox)

    # Perlで実行
    elsif text =~ /^@shell_pl\s+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 perl -e '#{command_escape(text, '@shell_pl')}'`}", :system => true)])
      }
      clear_post(gui_postbox)

    # Cで実行
    elsif text =~ /^@shell_c\s+.+/
      Thread.new{
        uniqdir = gen_random_str
        `mkdir -p #{COMPILE_TMPDIR}/#{uniqdir}`
        f = open("#{COMPILE_TMPDIR}/#{uniqdir}/src.c", "w")
        f.write(source_escape(text, '@shell_c'))
        f.close
        result = `cd #{COMPILE_TMPDIR}/#{uniqdir} && gcc src.c 2>&1 && timeout 10 ./a.out 2>&1`
        `rm -rf #{COMPILE_TMPDIR}/#{uniqdir}`
        Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
      }
      clear_post(gui_postbox)

    # C++で実行
    elsif text =~ /^@shell_cpp\s+.+/
      Thread.new{
        uniqdir = gen_random_str
        `mkdir -p #{COMPILE_TMPDIR}/#{uniqdir}`
        f = open("#{COMPILE_TMPDIR}/#{uniqdir}/src.cpp", "w")
        f.write(source_escape(text, '@shell_cpp'))
        f.close
        result = `cd #{COMPILE_TMPDIR}/#{uniqdir} && g++ src.cpp 2>&1 && timeout 10 ./a.out 2>&1`
        `rm -rf #{COMPILE_TMPDIR}/#{uniqdir}`
        Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
      }
      clear_post(gui_postbox)

    # 入力されたテキストをファイルに書いて指定されたコマンドで実行
    elsif text =~ /^@script\s+.+/
      Thread.new {
        command = Regexp.new(/^@script +(.*)\n/).match(text).to_a[1]
        source = text.sub(/^@script +.*\n/, '')

        uniqdir = gen_random_str
        `mkdir -p #{COMPILE_TMPDIR}/#{uniqdir}`
        f = open("#{COMPILE_TMPDIR}/#{uniqdir}/src.script", "w")
        f.write(source_escape(source, /^@script.*\n/))
        f.close
        result = `cd #{COMPILE_TMPDIR}/#{uniqdir} && #{command} ./src.script 2>&1`
        `rm -rf #{COMPILE_TMPDIR}/#{uniqdir}`
        Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
      }
      clear_post(gui_postbox)

    # 入力されたテキストをファイルに書いて指定されたコマンドでコンパイル後，exec_commandを実行
    elsif text =~ /^@compile\s+.+/
      Thread.new {
        re = Regexp.new(/^@compile *\[(.+)\] *\[(.+)\] *(.+)\n/)
        filename = re.match(text).to_a[1]
        exec_command = re.match(text).to_a[2]
        command = re.match(text).to_a[3]
        source = text.sub(/^@compile +.*\n/, '')

        uniqdir = gen_random_str
        `mkdir -p #{COMPILE_TMPDIR}/#{uniqdir}`
        f = open("#{COMPILE_TMPDIR}/#{uniqdir}/#{filename}", "w")
        f.write(source_escape(source, /^@compile.*\n/))
        f.close
        result = `cd #{COMPILE_TMPDIR}/#{uniqdir} && #{command} #{filename} 2>&1 && #{exec_command} 2>&1`
        `rm -rf #{COMPILE_TMPDIR}/#{uniqdir}`
        Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
      }
      clear_post(gui_postbox)

    # #{}が含まれる場合はRubyコードとして展開する
    elsif text =~ /#\{[^\}]+\}/
      while text =~ /#\{[^\}]+\}/
        re = Regexp.new(/#\{([^\}]+)\}/)
        command = re.match(text).to_a[1]
        begin
          result = Kernel.instance_eval(command)
        rescue Exception => e
          result = e
        end
        text.sub!(/#\{[^\}]+\}/, result.to_s)
      end
      Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text = text
      Plugin.filter_cancel!

    # @google に向けたリプライをクエリにしてGoogle検索
    elsif text =~ /^@google\s+(.+)/
      Thread.new{
        ::Gtk::openurl("http://www.google.co.jp/search?q=" + URI.escape($1).to_s)
      }
      clear_post(gui_postbox)

    # @maps に向けたリプライをクエリにして地図検索
    elsif text =~ /^@maps\s+(.+)/
      Thread.new{
        ::Gtk::openurl("https://maps.google.co.jp/maps?q=" + URI.escape($1).to_s)
      }
      clear_post(gui_postbox)

    # @openurl に向けたリプライはそのままブラウザで開く
    elsif text =~ /^@openurl\s+(.+)/
      Thread.new{
        ::Gtk::openurl("#{$1}")
      }
      clear_post(gui_postbox)

    elsif text =~ /^@miku\s+郵便番号\s+.+/ or
        text =~ /^@miku\s+郵便\s+.+/ or
        text =~ /^@miku\s+ゆうびん\s+.+/ or
        text =~ /^@miku\s+〒\s+.+/
      Thread.new {
        result = "郵便番号を検索したよ！(・∀・*)\n"
        result += postal_search(text[text.index(/\S+$/)..-1])
        Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
      }
      clear_post(gui_postbox)      

    elsif text =~ /^@?whois\s+@?([a-zA-Z0-9_]+)/
      user = User.findbyidname($1)
      if user
        Plugin.call(:show_profile, Service.primary, user)
      else
        Plugin.call(:update, nil, [Message.new(:message => "@#{$1}が見つかりませんでした", :system => true)])
      end
      clear_post(gui_postbox)

    elsif text =~ /^@miku\s+(.*の天気).*$/u
      Thread.new {
        result = "お天気予報を探したよ！(・∀・*)\n"
        begin
          result << WeatherJp.parse($1).to_s
        rescue Exception => e
          result << "見つけられなかったよ(´・ω・｀)"
        end
        Plugin.call(:update, nil, [Message.new(:message => result, :system => true)])
      }
      clear_post(gui_postbox)

    elsif text =~ /^@miku\s+IC登録/
      begin
        icatr = `opensc-tool -a`.sub("\n", '')
        if `grep #{icatr} #{File.expand_path(File.join(File.dirname(__FILE__), "valid_id"))}`.size > 1
          Plugin.call(:update, nil, [Message.new(:message => "そのカードは既に登録済みです", :system => true)])
        else
          `echo #{icatr} >> #{File.expand_path(File.join(File.dirname(__FILE__), "valid_id"))}`
          Plugin.call(:update, nil, [Message.new(:message => "登録しました(*ﾟ∀ﾟ)", :system => true)])
        end
      rescue Exception => e
        Plugin.call(:update, nil, [Message.new(:message => "登録できませんでした", :system => true)])
      end
      clear_post(gui_postbox)

    elsif `which opensc-tool`
      begin
        icatr = `opensc-tool -a`.sub("\n", '')
        if `cat #{File.expand_path(File.join(File.dirname(__FILE__), "valid_id"))}`.split("\n").find{|id| id == icatr}
          Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text += " [IC認証済]"
        end
      rescue Exception => e
      end
    end

    [gui_postbox]
  end

end

