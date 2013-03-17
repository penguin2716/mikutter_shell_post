#-*- coding: utf-8 -*-
# Rubyで実行
Plugin.create(:shell_post).add_command(/^@shell_rb\s+([\w\W]+)/) { |text|
  if text =~ /^@shell_rb\s+([\w\W]+)/
    Thread.new{
      Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 ruby -e '#{Plugin.create(shell_post).command_escape($1)}'`}", :system => true)])
    }
  end
}
