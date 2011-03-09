module TopicsHelper

  def topic_help_text(topic)
    if topic.description.present?
      truncate_words(remove_links(topic.description), 100)
    else
      topic.title
    end
  end

  private

  def remove_links(description)
    description.gsub(/\[([^\]]*)\]\[\d*\]/, '\1').gsub(/\[\d*\]: [^ ]*/, '').gsub(/ +/, " ").gsub(/[\r\n]/, '')
  end

end
