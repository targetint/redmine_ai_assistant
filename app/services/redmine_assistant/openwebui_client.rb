require 'json'
require 'net/http'
require 'securerandom'
require 'uri'

module RedmineAssistant
  class OpenwebuiClient
    # OpenWebUI API paths have changed between releases. Keep them here so an
    # installation-specific adjustment is small and obvious.
    KNOWLEDGE_BASES_PATH = '/api/v1/knowledge/'.freeze
    CREATE_KNOWLEDGE_BASE_PATH = '/api/v1/knowledge/create'.freeze
    FILES_UPLOAD_PATH = '/api/v1/files/'.freeze
    ADD_FILE_TO_KNOWLEDGE_PATH = '/api/v1/knowledge/%s/file/add'.freeze
    # OpenWebUI exposes an OpenAI-compatible chat endpoint in current releases.
    # If your version differs, adjust this path here.
    CHAT_COMPLETIONS_PATH = '/api/chat/completions'.freeze

    DEFAULT_OPEN_TIMEOUT = 10
    DEFAULT_READ_TIMEOUT = 120

    def initialize(settings = RedmineAssistant.settings)
      @base_url = settings['openwebui_base_url'].to_s
      @api_key = settings['openwebui_api_key'].to_s
      @open_timeout = DEFAULT_OPEN_TIMEOUT
      @read_timeout = DEFAULT_READ_TIMEOUT
      validate_configuration!
    end

    def list_knowledge_bases
      response = request_json(:get, KNOWLEDGE_BASES_PATH)
      normalize_collection(response)
    end

    def find_knowledge_base_by_name(name)
      list_knowledge_bases.find { |knowledge| knowledge_name(knowledge).to_s == name.to_s }
    end

    def create_knowledge_base(name, description = nil)
      payload = { :name => name, :description => description }.delete_if { |_key, value| value.blank? }
      response = request_json(:post, CREATE_KNOWLEDGE_BASE_PATH, payload)
      normalize_record(response)
    end

    def upload_document_to_knowledge_base(knowledge_id, filename, content)
      file = upload_file(filename, content)
      file_id = value_for(file, 'id') || value_for(file, 'file_id')
      raise "OpenWebUI file upload did not return a file id" if file_id.blank?

      path = format(ADD_FILE_TO_KNOWLEDGE_PATH, escape_path(knowledge_id))
      request_json(:post, path, { :file_id => file_id })
    end

    def chat(messages, model = nil)
      payload = {
        :model => model.presence || RedmineAssistant.settings['default_chat_model'].to_s,
        :messages => messages,
        :stream => false
      }
      response = request_json(:post, CHAT_COMPLETIONS_PATH, payload)
      extract_chat_content(response)
    end

    private

    def upload_file(filename, content)
      boundary = "redmine-assistant-#{SecureRandom.hex(12)}"
      body = multipart_body(boundary, filename, content)
      headers = {
        'Content-Type' => "multipart/form-data; boundary=#{boundary}"
      }
      response = request(:post, FILES_UPLOAD_PATH, body, headers)
      parse_json(response)
    end

    def validate_configuration!
      raise 'OpenWebUI base URL is not configured' if @base_url.blank?
      raise 'OpenWebUI API key is not configured' if @api_key.blank?
    end

    def request_json(method, path, payload = nil)
      body = payload.nil? ? nil : JSON.generate(payload)
      response = request(method, path, body, 'Content-Type' => 'application/json')
      parse_json(response)
    end

    def request(method, path, body = nil, extra_headers = {})
      uri = URI.join(normalized_base_url, path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      klass = method.to_s.downcase == 'get' ? Net::HTTP::Get : Net::HTTP::Post
      request = klass.new(uri.request_uri)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Accept'] = 'application/json'
      extra_headers.each { |key, value| request[key] = value }
      request.body = body if body

      response = http.request(request)
      unless response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.error("[redmine_assistant] OpenWebUI request failed path=#{path} status=#{response.code}")
        raise "OpenWebUI request failed (#{response.code})"
      end
      response
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("[redmine_assistant] OpenWebUI request error path=#{path}: #{e.class}: #{e.message}")
      raise "OpenWebUI request error: #{e.message}"
    end

    def parse_json(response)
      return {} if response.body.blank?
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      Rails.logger.error("[redmine_assistant] invalid OpenWebUI JSON response: #{e.message}")
      raise 'OpenWebUI returned an invalid JSON response'
    end

    def normalize_collection(response)
      if response.is_a?(Array)
        response
      elsif response.is_a?(Hash)
        response['data'] || response['knowledge_bases'] || response['items'] || []
      else
        []
      end
    end

    def normalize_record(response)
      if response.is_a?(Hash)
        response['data'] || response['knowledge'] || response
      else
        response
      end
    end

    def extract_chat_content(response)
      content = response.dig('choices', 0, 'message', 'content') if response.respond_to?(:dig)
      content ||= response.dig('message', 'content') if response.respond_to?(:dig)
      content ||= response['content'] if response.is_a?(Hash)
      content = content.to_s
      raise 'OpenWebUI chat response did not include content' if content.blank?

      content
    end

    def knowledge_name(knowledge)
      value_for(knowledge, 'name')
    end

    def value_for(record, key)
      return nil unless record.respond_to?(:[])
      record[key] || record[key.to_sym]
    end

    def normalized_base_url
      @base_url.end_with?('/') ? @base_url : "#{@base_url}/"
    end

    def escape_path(value)
      URI.encode_www_form_component(value.to_s)
    end

    def multipart_body(boundary, filename, content)
      parts = []
      parts << "--#{boundary}\r\n"
      parts << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
      parts << "Content-Type: text/plain\r\n\r\n"
      parts << content.to_s
      parts << "\r\n--#{boundary}--\r\n"
      parts.join
    end
  end
end
