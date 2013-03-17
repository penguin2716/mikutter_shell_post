#-*- coding: utf-8 -*-
# @google に向けたリプライをクエリにしてGoogle検索
Plugin.create(:shell_post).add_command(/^@google\s+(.+)/) { |text|
  if text =~ /^@google\s+(.+)/
    Thread.new{
      ::Gtk::openurl("http://www.google.co.jp/search?q=" + URI.escape($1).to_s)
    }
  end
}
