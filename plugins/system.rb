#-*- coding: utf-8 -*-
# @system に向けたリプライはmikutterコマンドとして処理する
Plugin.create(:shell_post).add_command(/^@system\s+([\w\W]+)/) { |text|
  if text =~ /^@system\s+([\w\W]+)/
    Thread.new{
      begin
        result = Kernel.instance_eval($1)
        Plugin.call(:update, nil, [Message.new(:message => "#{result.to_s}", :system => true)])
      rescue Exception => e
        Plugin.call(:update, nil, [Message.new(:message => "失敗しました(´・ω・｀)\nコードを確認してみて下さい↓\n#{text}", :system => true)])
      end
    }
  end
}
