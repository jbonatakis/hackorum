class Feature
  ALL = {
    email_sending: "Email sending",
    ai_topic_summaries: "Topic summaries"
  }.freeze

  NAMES = ALL.keys.map(&:to_s).freeze

  def self.valid?(name)
    ALL.key?(name.to_sym)
  rescue NoMethodError
    false
  end

  def self.label(name)
    ALL[name.to_sym]
  end

  def self.names
    ALL.keys
  end
end
