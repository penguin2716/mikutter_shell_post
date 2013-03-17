#-*- coding: utf-8 -*-
# @shell_p に向けたリプライはtimeoutしない
Plugin.create(:shell_post).add_command(/^@shell_p\s+([\w\W]+)/) {|text|
  if text =~ /^@shell_p\s+([\w\W]+)/
    Thread.new{
      Plugin.call(:update, nil, [Message.new(:message => "exit #{$1}:\n#{`#{$1}`}", :system => true)])
    }
  end
}
