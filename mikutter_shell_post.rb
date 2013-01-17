#-*- coding: utf-8 -*-

Plugin.create :shell_post do

  COMPILE_TMPDIR = "/dev/shm/mikutter_scratch"

  # PostBoxの中身をクリアしてイベントをキャンセル
  def clear_post(gui_postbox)
    Plugin.call(:before_postbox_post,
                Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text)
    Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text = ''
    Plugin.filter_cancel!
  end

  def command_escape(str, delete_str)
    str.sub(/^#{delete_str}[ \n]+/,'').gsub(/'/, '''\'''\\\\''\'''''\'''')    
  end

  def source_escape(str, delete_str)
    str.sub(/^#{delete_str}[ \n]+/,'').gsub(/'/, '''\'''')    
  end
  
  # @shell または @shell_p に向けたリプライをシェルコマンドと解釈する
  filter_gui_postbox_post do |gui_postbox|
    text = Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text

    # @system に向けたリプライはmikutterコマンドとして処理する
    if text =~ /^@system[ \n]+.+/
      Thread.new{
        begin
          result = Kernel.instance_eval(text.sub(/^@system[ \n]+/,''))
          Plugin.call(:update, nil, [Message.new(:message => "#{result.to_s}", :system => true)])
        rescue Exception => e
          Plugin.call(:update, nil, [Message.new(:message => "失敗しました(´・ω・｀)\nコードを確認してみて下さい↓\n#{text}", :system => true)])
        end
      }
      clear_post(gui_postbox)

    # @shell に向けたリプライは10秒でtimeoutする
    elsif text =~ /^@shell[ \n]+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 #{text.sub(/^@shell[ \n]+/,'')}`}", :system => true)])
      }
      clear_post(gui_postbox)

    # @shell_p に向けたリプライはtimeoutしない
    elsif text =~ /^@shell_p[ \n]+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "exit #{text.sub(/^@shell_p[ \n]+/,'')}:\n#{`#{text.sub(/^@shell_p[ \n]+/,'')}`}", :system => true)])
      }
      clear_post(gui_postbox)

    # Rubyで実行
    elsif text =~ /^@shell_rb[ \n]+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 ruby -e '#{command_escape(text, '@shell_rb')}'`}", :system => true)])
      }
      clear_post(gui_postbox)

    # Pythonで実行
    elsif text =~ /^@shell_py[ \n]+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 python -c '#{command_escape(text, '@shell_py')}'`}", :system => true)])
      }
      clear_post(gui_postbox)

    # Perlで実行
    elsif text =~ /^@shell_pl[ \n]+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 perl -e '#{command_escape(text, '@shell_pl')}'`}", :system => true)])
      }
      clear_post(gui_postbox)

    # Cで実行
    elsif text =~ /^@shell_c[ \n]+.+/
      Thread.new{
        `mkdir #{COMPILE_TMPDIR}`
        f = open("#{COMPILE_TMPDIR}/src.c", "w")
        f.write(source_escape(text, '@shell_c'))
        f.close
        result = `cd #{COMPILE_TMPDIR} && gcc src.c 2>&1 && timeout 10 ./a.out 2>&1`
        `rm -rf #{COMPILE_TMPDIR}`
        Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
      }
      clear_post(gui_postbox)

    # C++で実行
    elsif text =~ /^@shell_cpp[ \n]+.+/
      Thread.new{
        `mkdir #{COMPILE_TMPDIR}`
        f = open("#{COMPILE_TMPDIR}/src.cpp", "w")
        f.write(source_escape(text, '@shell_cpp'))
        f.close
        result = `cd #{COMPILE_TMPDIR} && g++ src.cpp 2>&1 && timeout 10 ./a.out 2>&1`
        `rm -rf #{COMPILE_TMPDIR}`
        Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
      }
      clear_post(gui_postbox)

    # 入力されたテキストをファイルに書いて指定されたコマンドで実行
    elsif text =~ /^@script.*/
      Thread.new {
        command = Regexp.new(/^@script +(.*)\n/).match(text).to_a[1]
        source = text.sub(/^@script +.*\n/, '')

        `mkdir #{COMPILE_TMPDIR}`
        f = open("#{COMPILE_TMPDIR}/src.script", "w")
        f.write(source_escape(source, /^@script.*\n/))
        f.close
        result = `cd #{COMPILE_TMPDIR} && #{command} ./src.script 2>&1`
        `rm -rf #{COMPILE_TMPDIR}`
        Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
      }
      clear_post(gui_postbox)

    # 入力されたテキストをファイルに書いて指定されたコマンドでコンパイル後，exec_commandを実行
    elsif text =~ /^@compile.*/
      Thread.new {
        re = Regexp.new(/^@compile *\[(.+)\] *\[(.+)\] *(.+)\n/)
        filename = re.match(text).to_a[1]
        exec_command = re.match(text).to_a[2]
        command = re.match(text).to_a[3]
        source = text.sub(/^@compile +.*\n/, '')

        `mkdir #{COMPILE_TMPDIR}`
        f = open("#{COMPILE_TMPDIR}/#{filename}", "w")
        f.write(source_escape(source, /^@compile.*\n/))
        f.close
        result = `cd #{COMPILE_TMPDIR} && #{command} #{filename} 2>&1 && #{exec_command} 2>&1`
        `rm -rf #{COMPILE_TMPDIR}`
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
    end

    [gui_postbox]
  end

end

