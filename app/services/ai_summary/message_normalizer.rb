# frozen_string_literal: true

module AiSummary
  class MessageNormalizer
    FOOTER_PATTERNS = [
      /\A_{5,}\z/,
      /\A-{5,}\z/,
      /mailing list/i,
      /unsubscribe/i,
      /sent from my (?:iphone|ipad|android)/i
    ].freeze
    QUOTE_HEADER = /\AOn .+wrote:\s*\z/i

    def self.call(body)
      new(body).call
    end

    def initialize(body)
      @body = body.to_s
    end

    def call
      lines = body.encode("UTF-8", invalid: :replace, undef: :replace, replace: "\uFFFD")
                  .gsub("\r\n", "\n").gsub("\r", "\n").lines(chomp: true)
      lines = remove_signature(lines)
      lines = remove_trailing_quote(lines)
      lines = lines.reject { |line| quote_depth(line) > 1 }
      lines = remove_footer(lines)
      collapse_blank_lines(lines).join("\n").strip
    end

    private

    attr_reader :body

    def remove_signature(lines)
      signature = lines.index { |line| line.strip == "--" || line.strip == "-- " }
      signature ? lines.first(signature) : lines
    end

    def remove_trailing_quote(lines)
      last_original = lines.rindex { |line| line.present? && quote_depth(line).zero? && !line.match?(QUOTE_HEADER) }
      return lines unless last_original

      trailing = lines[(last_original + 1)..]
      first_quote = trailing&.index { |line| line.match?(QUOTE_HEADER) || quote_depth(line).positive? }
      return lines unless first_quote

      quote_start = last_original + 1 + first_quote
      after_quote = lines[quote_start..]
      return lines unless after_quote.all? { |line| line.blank? || line.match?(QUOTE_HEADER) || quote_depth(line).positive? }

      lines.first(quote_start)
    end

    def remove_footer(lines)
      footer = lines.index { |line| FOOTER_PATTERNS.any? { |pattern| line.strip.match?(pattern) } }
      footer ? lines.first(footer) : lines
    end

    def quote_depth(line)
      line[/\A\s*>+/].to_s.count(">")
    end

    def collapse_blank_lines(lines)
      lines.each_with_object([]) do |line, result|
        stripped = line.rstrip
        result << stripped unless stripped.blank? && result.last&.blank?
      end
    end
  end
end
