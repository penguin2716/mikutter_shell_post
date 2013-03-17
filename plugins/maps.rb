#-*- coding: utf-8 -*-
# @maps に向けたリプライをクエリにして地図検索
Plugin.create(:shell_post).add_command(/^@maps\s+(.+)/) { |text|
  if text =~ /^@maps\s+(.+)/
    Thread.new{
      ::Gtk::openurl("https://maps.google.co.jp/maps?q=" + URI.escape($1).to_s)
    }
  end
}

