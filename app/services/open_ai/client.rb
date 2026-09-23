# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"

module OpenAi
  class Client
    class Error < StandardError
      attr_reader :category, :retryable, :status

      def initialize(category:, retryable:, status: nil)
        @category = category
        @retryable = retryable
        @status = status
        super("OpenAI request failed (#{category})")
      end

      def retryable? = retryable
    end

    DEFAULT_BASE_URL = "https://api.openai.com"

    def initialize(api_key: ENV["OPENAI_API_KEY"], base_url: ENV.fetch("OPENAI_BASE_URL", DEFAULT_BASE_URL))
      @api_key = api_key
      @base_url = base_url
    end

    def upload_batch_file(jsonl)
      boundary = "hackorum-#{SecureRandom.hex(16)}"
      body = multipart_body(boundary, jsonl)
      request(:post, "/v1/files", body:, content_type: "multipart/form-data; boundary=#{boundary}")
    end

    def create_batch(input_file_id:, metadata: {})
      request(:post, "/v1/batches", json: {
        input_file_id:,
        endpoint: "/v1/chat/completions",
        completion_window: "24h",
        metadata:
      })
    end

    def retrieve_batch(batch_id)
      request(:get, "/v1/batches/#{escape(batch_id)}")
    end

    def cancel_batch(batch_id)
      request(:post, "/v1/batches/#{escape(batch_id)}/cancel", json: {})
    end

    def retrieve_file_content(file_id)
      request(:get, "/v1/files/#{escape(file_id)}/content", parse_json: false)
    end

    private

    attr_reader :api_key, :base_url

    def request(method, path, json: nil, body: nil, content_type: "application/json", parse_json: true)
      raise Error.new(category: "missing_api_key", retryable: false) if api_key.blank?

      uri = URI.join(base_url, path)
      klass = method == :get ? Net::HTTP::Get : Net::HTTP::Post
      http_request = klass.new(uri)
      http_request["Authorization"] = "Bearer #{api_key}"
      http_request["Content-Type"] = content_type
      http_request["User-Agent"] = "Hackorum AI summaries"
      http_request.body = json ? JSON.generate(json) : body

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 60) do |http|
        http.request(http_request)
      end
      handle_response(response, parse_json:)
    rescue Error
      raise
    rescue Timeout::Error, SocketError, EOFError, Errno::ECONNRESET, Errno::ECONNREFUSED
      raise Error.new(category: "transport_error", retryable: true)
    end

    def handle_response(response, parse_json:)
      status = response.code.to_i
      return parse_json ? JSON.parse(response.body) : response.body if status.between?(200, 299)

      category, retryable = case status
      when 401, 403 then [ "authentication_error", false ]
      when 408, 409, 429 then [ "rate_limited", true ]
      when 400, 404, 422 then [ "invalid_request", false ]
      when 500..599 then [ "provider_unavailable", true ]
      else [ "provider_error", false ]
      end
      raise Error.new(category:, retryable:, status:)
    rescue JSON::ParserError
      raise Error.new(category: "invalid_provider_response", retryable: true, status:)
    end

    def multipart_body(boundary, jsonl)
      [
        "--#{boundary}\r\nContent-Disposition: form-data; name=\"purpose\"\r\n\r\nbatch\r\n",
        "--#{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"hackorum-summaries.jsonl\"\r\n",
        "Content-Type: application/jsonl\r\n\r\n#{jsonl}\r\n",
        "--#{boundary}--\r\n"
      ].join
    end

    def escape(value)
      URI.encode_www_form_component(value)
    end
  end
end
