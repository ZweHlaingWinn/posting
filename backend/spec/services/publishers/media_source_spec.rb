require 'rails_helper'

RSpec.describe Publishers::MediaSource do
  let(:url) { 'https://cdn.example.com/clip.mp4' }

  # Real Net::HTTPResponse subclasses, so the case/when on Net::HTTPSuccess and
  # Net::HTTPRedirection in the service exercises the same branches it will in
  # production. Only the socket is faked.
  def response(klass, code, headers: {}, chunks: [])
    built = klass.new('1.1', code, code)
    headers.each { |name, value| built[name] = value }
    built.define_singleton_method(:read_body) { |&block| chunks.each { |chunk| block.call(chunk) } }
    built
  end

  def ok_response(body: 'video-bytes', content_type: 'video/mp4', content_length: nil)
    response(
      Net::HTTPOK,
      '200',
      headers: {
        'Content-Type' => content_type,
        'Content-Length' => (content_length || body.bytesize).to_s
      }.compact,
      chunks: [body]
    )
  end

  def stub_connection(*responses)
    queue = responses.flatten
    http = instance_double(Net::HTTP)

    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:ipaddr=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:start) { |&block| block.call(http) }
    allow(http).to receive(:request) { |_request, &block| block.call(queue.shift) }
    allow(Net::HTTP).to receive(:new).and_return(http)

    http
  end

  def resolves_to(*addresses)
    allow(Resolv).to receive(:getaddresses).and_return(addresses)
  end

  before { resolves_to('93.184.216.34') }

  describe 'URL validation' do
    it 'refuses plain http' do
      expect { described_class.fetch('http://cdn.example.com/clip.mp4') { |_| } }
        .to raise_error(described_class::Error, /must be a public https/)
    end

    it 'refuses a non-URL' do
      expect { described_class.fetch('not a url') { |_| } }
        .to raise_error(described_class::Error, /not a valid URL/)
    end

    it 'refuses a URL with no host' do
      expect { described_class.fetch('https:///clip.mp4') { |_| } }
        .to raise_error(described_class::Error, /must be a public https/)
    end
  end

  describe 'address validation' do
    {
      'loopback' => '127.0.0.1',
      'the RFC1918 10/8 block' => '10.1.2.3',
      'the RFC1918 192.168/16 block' => '192.168.1.10',
      'the RFC1918 172.16/12 block' => '172.20.0.5',
      'the cloud metadata endpoint' => '169.254.169.254',
      'the CGNAT block' => '100.100.0.1',
      'IPv6 loopback' => '::1',
      'IPv6 unique local space' => 'fd00::1',
      'IPv4-mapped loopback' => '::ffff:127.0.0.1'
    }.each do |description, address|
      it "refuses a host resolving to #{description}" do
        resolves_to(address)

        expect { described_class.fetch(url) { |_| } }
          .to raise_error(described_class::Error, /not publicly routable/)
      end
    end

    it 'refuses the host when only one of several answers is private' do
      resolves_to('93.184.216.34', '10.0.0.1')

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /not publicly routable/)
    end

    it 'refuses a host that does not resolve' do
      resolves_to

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /could not resolve/)
    end

    it 'pins the socket to the address it validated' do
      http = stub_connection(ok_response)

      expect(http).to receive(:ipaddr=).with('93.184.216.34')

      described_class.fetch(url) { |_| }
    end
  end

  describe 'a successful download' do
    it 'yields the body, its size and its content type' do
      stub_connection(ok_response(body: 'abcdef'))

      described_class.fetch(url) do |media|
        expect(media.size).to eq(6)
        expect(media.content_type).to eq('video/mp4')
        expect(media.file.read).to eq('abcdef')
      end
    end

    it 'hands over a file positioned at the start' do
      stub_connection(ok_response)

      described_class.fetch(url) { |media| expect(media.file.pos).to eq(0) }
    end

    it 'removes the temp file afterwards' do
      stub_connection(ok_response)
      path = nil

      described_class.fetch(url) { |media| path = media.file.path }

      expect(File.exist?(path)).to be(false)
    end

    it 'removes the temp file even when the block raises' do
      stub_connection(ok_response)
      path = nil

      expect do
        described_class.fetch(url) do |media|
          path = media.file.path
          raise 'upload blew up'
        end
      end.to raise_error('upload blew up')

      expect(File.exist?(path)).to be(false)
    end
  end

  describe 'size limits' do
    it 'refuses a declared length over the cap without downloading' do
      stub_connection(ok_response(content_length: 200))

      expect { described_class.fetch(url, max_bytes: 100) { |_| } }
        .to raise_error(described_class::Error, /larger than the/)
    end

    it 'aborts once the streamed bytes pass the cap, whatever was declared' do
      # A server that under-reports Content-Length must not get to write past
      # the limit.
      lying = response(
        Net::HTTPOK,
        '200',
        headers: { 'Content-Type' => 'video/mp4', 'Content-Length' => '5' },
        chunks: ['a' * 60, 'b' * 60]
      )
      stub_connection(lying)

      expect { described_class.fetch(url, max_bytes: 100) { |_| } }
        .to raise_error(described_class::Error, /larger than the/)
    end

    it 'reports the limit in megabytes' do
      stub_connection(ok_response(content_length: 200 * 1024 * 1024))

      expect { described_class.fetch(url, max_bytes: 64 * 1024 * 1024) { |_| } }
        .to raise_error(described_class::Error, /64 MB limit/)
    end

    it 'refuses an empty body' do
      stub_connection(response(Net::HTTPOK, '200', headers: { 'Content-Type' => 'video/mp4' }))

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /empty file/)
    end
  end

  describe 'content types' do
    %w[video/mp4 video/quicktime video/webm].each do |content_type|
      it "accepts #{content_type}" do
        stub_connection(ok_response(content_type: content_type))

        expect { described_class.fetch(url) { |_| } }.not_to raise_error
      end
    end

    it 'ignores charset parameters' do
      stub_connection(ok_response(content_type: 'video/mp4; charset=binary'))

      described_class.fetch(url) { |media| expect(media.content_type).to eq('video/mp4') }
    end

    # A login page or error page served from a path ending in .mp4 must not slip
    # through on the strength of the extension alone.
    it 'refuses a page that is not a video even at a video path' do
      stub_connection(ok_response(content_type: 'text/html'))

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /expected an MP4, MOV or WebM/)
    end

    # Object stores routinely serve video as octet-stream.
    it 'falls back to the path extension when the type is generic' do
      stub_connection(ok_response(content_type: 'application/octet-stream'))

      described_class.fetch('https://cdn.example.com/a/clip.MOV') do |media|
        expect(media.content_type).to eq('video/quicktime')
      end
    end

    it 'refuses a generic type with no usable extension' do
      stub_connection(ok_response(content_type: 'application/octet-stream'))

      expect { described_class.fetch('https://cdn.example.com/download') { |_| } }
        .to raise_error(described_class::Error, /expected an MP4, MOV or WebM/)
    end
  end

  describe 'redirects' do
    def redirect_to(location)
      response(Net::HTTPFound, '302', headers: { 'Location' => location })
    end

    it 'follows a redirect and downloads the destination' do
      stub_connection(
        redirect_to('https://cdn2.example.com/clip.mp4'),
        ok_response(body: 'moved')
      )

      described_class.fetch(url) { |media| expect(media.file.read).to eq('moved') }
    end

    it 'validates the redirect destination' do
      stub_connection(redirect_to('http://cdn2.example.com/clip.mp4'))

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /must be a public https/)
    end

    it 'checks the redirect destination against the private ranges too' do
      stub_connection(redirect_to('https://internal.example.com/clip.mp4'))
      allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34'], ['10.0.0.1'])

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /not publicly routable/)
    end

    it 'gives up after too many redirects' do
      stub_connection(Array.new(5) { redirect_to('https://cdn.example.com/again.mp4') })

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /redirected too many times/)
    end

    it 'refuses a redirect with no destination' do
      stub_connection(response(Net::HTTPFound, '302'))

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /redirected without a destination/)
    end
  end

  describe 'other failures' do
    it 'reports an error status from the host' do
      stub_connection(response(Net::HTTPNotFound, '404'))

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /returned HTTP 404/)
    end

    it 'reports a connection failure' do
      allow(Net::HTTP).to receive(:new).and_raise(SocketError, 'getaddrinfo failed')

      expect { described_class.fetch(url) { |_| } }
        .to raise_error(described_class::Error, /could not download the media/)
    end
  end
end
