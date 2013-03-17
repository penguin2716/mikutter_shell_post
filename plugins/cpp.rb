#-*- coding: utf-8 -*-
# C++で実行
Plugin.create(:shell_post).add_command(/^@shell_cpp\s+([\w\W]+)/) { |text|
  if text =~ /^@shell_cpp\s+([\w\W]+)/
    Thread.new{
      uniqdir = Plugin.create(:shell_post).gen_random_str
      `mkdir -p #{COMPILE_TMPDIR}/#{uniqdir}`
      f = open("#{COMPILE_TMPDIR}/#{uniqdir}/src.cpp", "w")
      f.write(Plugin.create(:shell_post).source_escape($1))
      f.close
      result = `cd #{COMPILE_TMPDIR}/#{uniqdir} && g++ src.cpp 2>&1 && timeout 10 ./a.out 2>&1`
      `rm -rf #{COMPILE_TMPDIR}/#{uniqdir}`
      Plugin.call(:update, nil, [Message.new(:message => "#{result}", :system => true)])
    }
  end
}
