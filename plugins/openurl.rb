#-*- coding: utf-8 -*-
# @openurl に向けたリプライはそのままブラウザで開く
Plugin.create(:shell_post).add_command(/^@openurl\s+(.+)/) { |text|
  if text =~ /^@openurl\s+(.+)/
    Thread.new{
      ::Gtk::openurl("#{$1}")
    }
  end
}

