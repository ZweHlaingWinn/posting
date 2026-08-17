require "ipaddr"
require "net/http"
require "resolv"
require "tempfile"
require "uri"

module Publishers
  # Downloads user-supplied media to a temp file so a publisher can forward it.
  #
  # The URL is typed into the composer by a user, which makes this a server-side
  # request forgery sink: without guards it would happily fetch
  # http://169.254.169.254/ or a service on the private network and hand the body
  # to an external API. So every hop is checked, the socket is pinned to the
  # address that was checked (a hostname that re-resolves to a private range
  # afterwards cannot win the race), and the body is capped while streaming
  # rather than trusting the declared Content-Length.
  class MediaSource
    class Error < StandardError; end

    MAX_REDIRECTS = 3
    DEFAULT_MAX_BYTES = 64 * 1024 * 1024
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 120

    EXTENSION_CONTENT_TYPES = {
      ".mp4" => "video/mp4",
      ".mov" => "video/quicktime",
      ".webm" => "video/webm"
    }.freeze

    # Types that carry no information, which object stores hand back for video.
    # Only these are allowed to fall through to the path extension.
    GENERIC_CONTENT_TYPES = [
      "", "application/octet-stream", "binary/octet-stream", "application/binary"
    ].freeze

    # Ranges that must never be reachable: loopback, the RFC1918 and CGNAT
    # blocks, link-local (which covers the 169.254.169.254 cloud metadata
    # endpoint), multicast and reserved space, plus their IPv6 equivalents.
    BLOCKED_RANGES = [
      "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16",
      "172.16.0.0/12", "192.0.0.0/24", "192.168.0.0/16", "198.18.0.0/15",
      "224.0.0.0/4", "240.0.0.0/4",
      "::/128", "::1/128", "fc00::/7", "fe80::/10", "ff00::/8"
    ].map { |cidr| IPAddr.new(cidr) }.freeze

    Media = Struct.new(:file, :content_type, :size, keyword_init: true)

    # Yields a Media whose file is positioned at the start, and removes the temp
    # file afterwards however the block exits.
    def self.fetch(url, max_bytes: DEFAULT_MAX_BYTES, &block)
      new(url, max_bytes: max_bytes).fetch(&block)
    end

    # Checks a browser-uploaded file before Active Storage keeps it. Returns the
    # canonical video content type, or raises Error.
    def self.validate_upload!(upload, max_bytes: DEFAULT_MAX_BYTES)
      raise Error, "no video file was attached" if upload.blank?

      unless upload.respond_to?(:original_filename) && upload.respond_to?(:size)
        raise Error, "the video upload is not a file"
      end

      size = upload.size.to_i
      raise Error, too_large_message_for(max_bytes) if size > max_bytes
      raise Error, "the video file is empty" if size.zero?

      content_type = video_content_type(
        declared: upload.content_type,
        filename: upload.original_filename
      )

      if content_type.blank?
        declared = upload.content_type.to_s.split(";").first.to_s.strip.downcase
        raise Error,
              "the video file was #{declared.presence || 'an unknown type'}; " \
              "expected an MP4, MOV or WebM video"
      end

      content_type
    end

    def self.video_content_type(declared:, filename: nil)
      type = declared.to_s.split(";").first.to_s.strip.downcase
      return type if EXTENSION_CONTENT_TYPES.value?(type)

      if GENERIC_CONTENT_TYPES.include?(type)
        EXTENSION_CONTENT_TYPES[File.extname(filename.to_s).downcase].presence
      end
    end

    def self.too_large_message_for(max_bytes)
      "the media is larger than the #{max_bytes / 1_048_576} MB limit"
    end

    def initialize(url, max_bytes: DEFAULT_MAX_BYTES)
      @url = url.to_s
      @max_bytes = max_bytes
    end

    def fetch
      file = Tempfile.new("publisher-media", binmode: true)
      content_type = stream_to(file)
      file.rewind

      yield Media.new(file: file, content_type: content_type, size: file.size)
    ensure
      file&.close!
    end

    private

    def stream_to(file)
      url = @url

      (MAX_REDIRECTS + 1).times do
        redirect_to = nil
        content_type = nil
        uri = validated_uri(url)

        connection_for(uri).start do |http|
          http.request(Net::HTTP::Get.new(uri)) do |response|
            case response
            when Net::HTTPRedirection
              redirect_to = response["location"]
              raise Error, "the media URL redirected without a destination" if redirect_to.blank?
            when Net::HTTPSuccess
              content_type = content_type_for(response, uri)
              write_capped(response, file)
            else
              raise Error, "the media URL returned HTTP #{response.code}"
            end
          end
        end

        return content_type if redirect_to.nil?

        url = URI.join(url, redirect_to).to_s
      end

      raise Error, "the media URL redirected too many times"
    rescue Timeout::Error,
           Errno::ECONNREFUSED,
           Errno::ECONNRESET,
           Errno::ETIMEDOUT,
           SocketError,
           OpenSSL::SSL::SSLError,
           EOFError => e
      raise Error, "could not download the media: #{e.message}"
    end

    def write_capped(response, file)
      declared = response["Content-Length"].to_i
      raise Error, too_large_message if declared > @max_bytes

      written = 0

      response.read_body do |chunk|
        written += chunk.bytesize
        raise Error, too_large_message if written > @max_bytes

        file.write(chunk)
      end

      raise Error, "the media URL returned an empty file" if written.zero?
    end

    def validated_uri(url)
      uri = URI.parse(url)

      unless uri.is_a?(URI::HTTPS) && uri.hostname.present?
        raise Error, "the media URL must be a public https:// link"
      end

      uri
    rescue URI::InvalidURIError
      raise Error, "the media URL is not a valid URL"
    end

    def connection_for(uri)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      # Connect straight to the address that passed the check while leaving the
      # hostname in place for SNI and certificate verification.
      http.ipaddr = public_address_for(uri.hostname)
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http
    end

    def public_address_for(hostname)
      addresses = Resolv.getaddresses(hostname).filter_map do |address|
        IPAddr.new(address)
      rescue IPAddr::InvalidAddressError
        nil
      end

      raise Error, "could not resolve #{hostname}" if addresses.empty?

      # If any answer points somewhere private, refuse the host outright instead
      # of picking a public answer and hoping the next lookup agrees.
      unless addresses.all? { |address| public_ip?(address) }
        raise Error, "#{hostname} resolves to an address that is not publicly routable"
      end

      addresses.first.to_s
    end

    def public_ip?(address)
      candidate = address.ipv4_mapped? ? address.native : address

      BLOCKED_RANGES.none? { |range| range.include?(candidate) }
    end

    # A strict allowlist keeps a bad link from wasting an upload. The path
    # extension is only consulted when the host declares nothing useful, so a
    # host that says it is serving HTML is still refused however the path is
    # spelled.
    def content_type_for(response, uri)
      declared = response["Content-Type"]
      type = self.class.video_content_type(declared: declared, filename: uri.path)

      return type if type.present?

      shown = declared.to_s.split(";").first.to_s.strip.downcase
      raise Error,
            "the media URL served #{shown.presence || 'an unknown type'}; " \
            "expected an MP4, MOV or WebM video"
    end

    def too_large_message
      self.class.too_large_message_for(@max_bytes)
    end
  end
end
