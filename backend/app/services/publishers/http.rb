require "net/http"
require "openssl"
require "uri"
require "json"

module Publishers
  # HTTP helper for the publishing APIs.
  #
  # Oauth::Http covers the token endpoints (form-encoded POST, JSON GET); the
  # content APIs need a bearer-authenticated JSON POST and a raw binary PUT for
  # the media transfer. Kept as a separate seam from Oauth::Http so publisher
  # specs stub uploads without touching the OAuth flows.
  class Http
    class Error < StandardError
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        @status = status
        @body = body
        super(message)
      end

      # A rate limit or a transient server fault is worth another attempt; a 4xx
      # rejection is not. A nil status means the connection itself failed, which
      # is also worth retrying.
      def retryable?
        status.nil? || status == 429 || status >= 500
      end
    end

    OPEN_TIMEOUT = 15
    # An upload streams an entire video, so the read timeout has to cover the
    # transfer rather than just the handshake.
    READ_TIMEOUT = 120

    # Media transfer replies 201 once every chunk has landed and 206 while more
    # are expected.
    UPLOAD_ACCEPTED_CODES = [200, 201, 206].freeze

    class << self
      def post_json(url, body, bearer:)
        uri = URI.parse(url)
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{bearer}"
        request["Content-Type"] = "application/json; charset=UTF-8"
        request["Accept"] = "application/json"
        request.body = JSON.generate(body)

        parse(execute(uri, request))
      end

      # Sends `io` as a single chunk covering the whole file.
      def put_binary(url, io, content_type:, size:)
        uri = URI.parse(url)
        request = Net::HTTP::Put.new(uri)
        request["Content-Type"] = content_type
        request["Content-Length"] = size.to_s
        request["Content-Range"] = "bytes 0-#{size - 1}/#{size}"
        request.body_stream = io

        response = execute(uri, request)
        code = response.code.to_i

        unless UPLOAD_ACCEPTED_CODES.include?(code)
          raise Error.new(
            "HTTP #{code} uploading to #{uri.host}",
            status: code,
            body: response.body
          )
        end

        code
      end

      private

      def execute(uri, request)
        Net::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT
        ) { |http| http.request(request) }
      rescue Timeout::Error,
             Errno::ECONNREFUSED,
             Errno::ECONNRESET,
             Errno::ETIMEDOUT,
             Errno::EPIPE,
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
