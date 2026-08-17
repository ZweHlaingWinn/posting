require "net/http"
require "openssl"
require "uri"
require "json"

module Oauth
  # Minimal JSON/form HTTP helper built on Net::HTTP.
  #
  # Deliberately not a gem: the OAuth flows need two verbs and one content type,
  # and keeping it here means specs can stub this single seam instead of
  # intercepting sockets.
  class Http
    class Error < StandardError
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        @status = status
        @body = body
        super(message)
      end
    end

    TIMEOUT = 15

    class << self
      def post_form(url, params, headers = {})
        uri = URI.parse(url)
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(params)
        headers.each { |key, value| request[key] = value }

        execute(uri, request)
      end

      def get_json(url, headers = {})
        uri = URI.parse(url)
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/json"
        headers.each { |key, value| request[key] = value }

        execute(uri, request)
      end

      private

      def execute(uri, request)
        response = Net::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: TIMEOUT,
          read_timeout: TIMEOUT
        ) { |http| http.request(request) }

        parse(response)
      rescue Timeout::Error,
             Errno::ECONNREFUSED,
             Errno::ECONNRESET,
             Errno::ETIMEDOUT,
             SocketError,
             OpenSSL::SSL::SSLError,
             EOFError => e
        raise Error, "network error contacting #{uri.host}: #{e.message}"
      end

      def parse(response)
        body = begin
          response.body.presence && JSON.parse(response.body)
        rescue JSON::ParserError
          nil
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise Error.new(
            "HTTP #{response.code} from #{response.uri&.host}",
            status: response.code.to_i,
            body: body
          )
        end

        body || {}
      end
    end
  end
end
