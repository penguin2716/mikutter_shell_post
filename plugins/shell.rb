#-*- coding: utf-8 -*-
# @shell に向けたリプライは10秒でtimeoutする
Plugin.create(:shell_post).add_command(/^@shell\s+([\w\W]+)/) { |text|
  if text =~ /^@shell\s+([\w\W]+)/
    Thread.new{
      Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 #{$1}`}", :system => true)])
    }
  end
}
