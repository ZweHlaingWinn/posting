module UploadHelpers
  def uploaded_video(filename: 'clip.mp4', content_type: 'video/mp4', body: 'fake-video-bytes')
    path = File.join(Dir.mktmpdir, filename)
    File.binwrite(path, body)
    Rack::Test::UploadedFile.new(path, content_type)
  end
end
