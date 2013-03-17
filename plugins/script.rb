#-*- coding: utf-8 -*-
# 入力されたテキストをファイルに書いて指定されたコマンドで実行
Plugin.create(:shell_post).add_command(/^@script\s+(.+)\s+([\w\W]+)/) { |text|
  if text =~ /^@script\s+(.+)\s+([\w\W]+)/
    Thread.new {
      uniqdir = Plugin.create(:shell_post).gen_random_str
      `mkdir -p #{COMPILE_TMPDIR}/#{uniqdir}`
      f = open("#{COMPILE_TMPDIR}/#{uniqdir}/src.script", "w")
      f.write(Plugin.create(:shell_post).source_escape($2))
      f.close
      result = `cd #{COMPILE_TMPDIR}/#{uniqdir} && #{$1} ./src.script 2>&1`
      `rm -rf #{COMPILE_TMPDIR}/#{uniqdir}`
      Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
    }
  end
}
