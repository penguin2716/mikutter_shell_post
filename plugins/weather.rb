#-*- coding: utf-8 -*-
require 'weather_jp'
Plugin.create(:shell_post).add_command(/^@miku\s+(.*の天気).*$/u) { |text|
  if text =~ /^@miku\s+(.*の天気).*$/u
    Thread.new {
      result = "お天気予報を探したよ！(・∀・*)\n"
      begin
        result << WeatherJp.parse($1).to_s
      rescue Exception => e
        result << "見つけられなかったよ(´・ω・｀)"
      end
      Plugin.call(:update, nil, [Message.new(:message => result, :system => true)])
    }
  end
}
