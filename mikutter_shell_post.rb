#-*- coding: utf-8 -*-

require 'socket'
require 'json'
require 'cgi'

Plugin.create :shell_post do
  UserConfig[:shell_exec_with_post] ||= false
  COMPILE_TMPDIR = "/dev/shm/mikutter_scratch"

  def self.compile_tmpdir
    "/dev/shm/mikutter_scratch"
  end

  @add_ons = {}

  def add_command(re, &proc)
    @add_ons[re] = proc
  end

  def delete_command(re)
    @add_ons.delete(re)
  end

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
  def self.clear_post(gui_postbox)
    Plugin.call(:before_postbox_post,
                Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text)
    Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text = ''
    Plugin.filter_cancel!
  end

  def self.command_escape(str)
    str.gsub(/'/, '''\'''\\\\''\'''''\'''')    
  end

  def self.source_escape(str)
    str.gsub(/'/, '''\'''')    
  end

  def self.gen_random_str
    (("a".."z").to_a + ("A".."Z").to_a + (0..9).to_a).shuffle[0..20].join
  end
  
  filter_gui_postbox_post do |gui_postbox|
    text = Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text

    if UserConfig[:shell_exec_with_post]
      Service.primary.post :message => (text[0] == '@') ? text.sub('@','') : text
    end

    # #{}が含まれる場合はRubyコードとして展開する
    if text =~ /#\{[^\}]+\}/
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

    elsif text =~ /^@miku\s+(郵便番号|郵便|ゆうびん|〒)\s+(.+)/
      Thread.new {
        result = "郵便番号を検索したよ！(・∀・*)\n"
        result += postal_search($2)
        Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
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

    @add_ons.each do |key, proc|
      if key =~ text
        proc.call(text)
        clear_post(gui_postbox)
      end
    end


    [gui_postbox]
  end

  settings "shell_post" do
    boolean "コマンド実行と同時に元のコマンドをポストする", :shell_exec_with_post
  end

end

`ls #{File.expand_path(File.join(File.dirname(__FILE__), "plugins"))}/*.rb`.split("\n").each do |plugin|
  load plugin
end

