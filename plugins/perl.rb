#-*- coding: utf-8 -*-
# Perlで実行
Plugin.create(:shell_post).add_command(/^@shell_pl\s+([\w\W]+)/) { |text|
  if text =~ /^@shell_pl\s+([\w\W]+)/
    Thread.new{
      Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 perl -e '#{Plugin.create(:shell_post).command_escape($1)}'`}", :system => true)])
    }
  end
}
