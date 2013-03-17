#-*- coding: utf-8 -*-

Plugin.create(:shell_post).add_command(/^@?whois\s+@?([a-zA-Z0-9_]+)/) { |text|
  if text =~ /^@?whois\s+@?([a-zA-Z0-9_]+)/
    user = User.findbyidname($1)
    if user
      Plugin.call(:show_profile, Service.primary, user)
    else
      Plugin.call(:update, nil, [Message.new(:message => "@#{$1}が見つかりませんでした", :system => true)])
    end
  end
}
