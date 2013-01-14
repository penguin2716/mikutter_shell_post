#-*- coding: utf-8 -*-

Plugin.create :shell_post do

  # PostBoxの中身をクリアしてイベントをキャンセル
  def clear_post(gui_postbox)
    Plugin.call(:before_postbox_post,
                Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text)
    Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text = ''
    Plugin.filter_cancel!
  end

  # @shell または @shell_p に向けたリプライをシェルコマンドと解釈する
  filter_gui_postbox_post do |gui_postbox|
    text = Plugin.create(:gtk).widgetof(gui_postbox).widget_post.buffer.text

    # @shell に向けたリプライは10秒でtimeoutする
    if text =~ /^@shell[ \n]+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "#{`timeout 10 #{text.sub(/^@shell[ \n]+/,'')}`}", :system => true)])
      }
      clear_post(gui_postbox)

    # @shell_p に向けたリプライはtimeoutしない
    elsif text =~ /^@shell_p[ \n]+.+/
      Thread.new{
        Plugin.call(:update, nil, [Message.new(:message => "exit #{text.sub(/^@shell_p[ \n]+/,'')}:\n#{`#{text.sub(/^@shell_p[ \n]+/,'')}`}", :system => true)])
      }
      clear_post(gui_postbox)
    end

    [gui_postbox]
  end

end

