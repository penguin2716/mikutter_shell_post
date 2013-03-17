#-*- coding: utf-8 -*-
# Pythonで実行
Plugin.create(:shell_post).add_command(/^@shell_py\s+([\w\W]+)/) { |text|
  if text =~ /^@shell_py\s+([\w\W]+)/
    Thread.new{
      Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 python -c '#{Plugin.create(:shell_post).command_escape($1)}'`}", :system => true)])
    }
  end
}
