require 'json'
require 'net/http'
require 'uri'

module RedmineAssistant
  class OllamaClient
    CHAT_PATH = '/api/chat'.freeze
    DEFAULT_OPEN_TIMEOUT = 10
    DEFAULT_READ_TIMEOUT = 180

    def initialize(settings = RedmineAssistant.settings)
      @base_url = settings['ollama_base_url'].to_s
      @model = settings['default_chat_model'].to_s
      validate_configuration!
    end

    def chat(messages, model = nil)
      payload = {
        :model => model.presence || @model,
        :messages => messages,
        :stream => false
      }
      response = request_json(:post, CHAT_PATH, payload)
      response.dig('message', 'content').to_s
    end

    private

    def validate_configuration!
      raise 'Ollama base URL is not configured' if @base_url.blank?
      raise 'Default chat model is not configured' if @model.blank?
    end

    def request_json(method, path, payload)
      uri = URI.join(normalized_base_url, path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = DEFAULT_OPEN_TIMEOUT
      http.read_timeout = DEFAULT_READ_TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Accept'] = 'application/json'
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(payload)

      response = http.request(request)
      unless response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.error("[redmine_assistant] Ollama request failed path=#{path} status=#{response.code}")
        raise "Ollama request failed (#{response.code})"
      end

      JSON.parse(response.body)
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("[redmine_assistant] Ollama request error path=#{path}: #{e.class}: #{e.message}")
      raise "Ollama request error for #{@base_url}: #{e.message}. Check the Redmine Assistant Ollama base URL setting and make sure Ollama is running."
    rescue JSON::ParserError => e
      Rails.logger.error("[redmine_assistant] invalid Ollama JSON response: #{e.message}")
      raise 'Ollama returned an invalid JSON response'
    end

    def normalized_base_url
      @base_url.end_with?('/') ? @base_url : "#{@base_url}/"
    end
  end
end
