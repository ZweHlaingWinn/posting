require 'rails_helper'

RSpec.describe Publishers::TiktokPublisher do
  let(:account) { create(:social_account, :tiktok, access_token: 'act.token') }
  let(:post_record) { create(:post, :with_media, user: account.user) }
  let(:post_target) { create(:post_target, post: post_record, social_account: account) }
  let(:adapter) { described_class.new(account) }

  let(:media) do
    Publishers::MediaSource::Media.new(
      file: StringIO.new('binary'),
      content_type: 'video/mp4',
      size: 6
    )
  end

  let(:init_response) do
    {
      'data' => {
        'publish_id' => 'v_inbox_file~v2.123',
        'upload_url' => 'https://open-upload.tiktokapis.com/video/?upload_id=1'
      },
      'error' => { 'code' => 'ok', 'message' => '' }
    }
  end

  # The download is a separate seam with its own spec, so hand the adapter a
  # ready-made file rather than standing up an HTTP server.
  def stub_media_download
    allow(Publishers::MediaSource).to receive(:fetch).and_yield(media)
  end

  describe 'capabilities' do
    it 'reports itself implemented' do
      expect(described_class).to be_implemented
    end

    it 'refuses a text-only post' do
      expect(described_class).to be_requires_media
    end
  end

  describe '#publish' do
    before { stub_media_download }

    it 'initializes the upload with a single chunk covering the whole video' do
      allow(Publishers::Http).to receive(:put_binary).and_return(201)

      expect(Publishers::Http).to receive(:post_json).with(
        described_class::INIT_URL,
        {
          source_info: {
            source: 'FILE_UPLOAD',
            video_size: 6,
            chunk_size: 6,
            total_chunk_count: 1
          }
        },
        bearer: 'act.token'
      ).and_return(init_response)

      adapter.publish(post_record, post_target)
    end

    it 'sends the bytes to the upload URL TikTok returned' do
      allow(Publishers::Http).to receive(:post_json).and_return(init_response)

      expect(Publishers::Http).to receive(:put_binary).with(
        'https://open-upload.tiktokapis.com/video/?upload_id=1',
        media.file,
        content_type: 'video/mp4',
        size: 6
      ).and_return(201)

      adapter.publish(post_record, post_target)
    end

    it 'returns the publish id' do
      allow(Publishers::Http).to receive(:post_json).and_return(init_response)
      allow(Publishers::Http).to receive(:put_binary).and_return(201)

      expect(adapter.publish(post_record, post_target)).to eq('v_inbox_file~v2.123')
    end

    it 'caps the download at the configured size' do
      allow(Publishers::Http).to receive(:post_json).and_return(init_response)
      allow(Publishers::Http).to receive(:put_binary).and_return(201)

      expect(Publishers::MediaSource).to receive(:fetch)
        .with('https://cdn.example.com/clip.mp4', max_bytes: 64 * 1024 * 1024)
        .and_yield(media)

      adapter.publish(post_record, post_target)
    end

    it 'raises when TikTok returns no upload target' do
      allow(Publishers::Http).to receive(:post_json).and_return('data' => {})

      expect { adapter.publish(post_record, post_target) }
        .to raise_error(Publishers::PublishError, /did not return an upload target/)
    end

    it 'wraps an upload failure and keeps it retryable when TikTok is at fault' do
      allow(Publishers::Http).to receive(:post_json).and_return(init_response)
      allow(Publishers::Http).to receive(:put_binary)
        .and_raise(Publishers::Http::Error.new('HTTP 503', status: 503))

      expect { adapter.publish(post_record, post_target) }
        .to raise_error(Publishers::PublishError) { |e| expect(e).to be_retryable }
    end
  end

  describe '#publish without media' do
    it 'refuses a post that has no video' do
      text_only = create(:post, user: account.user, media_urls: [])
      target = create(:post_target, post: text_only, social_account: account)

      expect { adapter.publish(text_only, target) }
        .to raise_error(Publishers::PublishError, /need a video/)
    end
  end

  describe '#publish when the video cannot be fetched' do
    it 'surfaces the download problem to the user' do
      allow(Publishers::MediaSource).to receive(:fetch)
        .and_raise(Publishers::MediaSource::Error, 'the media is larger than the 64 MB limit')

      expect { adapter.publish(post_record, post_target) }
        .to raise_error(Publishers::PublishError, /larger than the 64 MB limit/)
    end
  end

  describe '#publish with an uploaded file' do
    let(:post_record) { create(:post, :with_uploaded_video, user: account.user) }

    it 'sends the attached bytes without downloading a URL' do
      allow(Publishers::Http).to receive(:post_json).and_return(init_response)

      expect(Publishers::MediaSource).not_to receive(:fetch)
      expect(Publishers::Http).to receive(:put_binary).with(
        'https://open-upload.tiktokapis.com/video/?upload_id=1',
        anything,
        content_type: 'video/mp4',
        size: 16
      ).and_return(201)

      expect(adapter.publish(post_record, post_target)).to eq('v_inbox_file~v2.123')
    end
  end

  describe 'error translation' do
    before { stub_media_download }

    def publish_with_error(code, status: 400)
      allow(Publishers::Http).to receive(:post_json).and_raise(
        Publishers::Http::Error.new(
          "HTTP #{status}",
          status: status,
          body: { 'error' => { 'code' => code, 'message' => code } }
        )
      )

      adapter.publish(post_record, post_target)
    end

    it 'treats an invalid token as needing a reconnect' do
      expect { publish_with_error('access_token_invalid', status: 401) }
        .to raise_error(Publishers::TokenRefreshError, /Reconnect the account/)
    end

    it 'marks the account expired when the token is rejected' do
      expect { publish_with_error('access_token_invalid', status: 401) }
        .to raise_error(Publishers::TokenRefreshError)

      expect(account.reload).to be_status_expired
    end

    it 'treats a missing scope as needing a reconnect' do
      expect { publish_with_error('scope_not_authorized', status: 401) }
        .to raise_error(Publishers::TokenRefreshError, /missing permission/)
    end

    it 'explains the pending-share cap without offering a retry' do
      expect { publish_with_error('spam_risk_too_many_pending_share', status: 403) }
        .to raise_error(Publishers::PublishError) do |e|
          expect(e.message).to match(/5 uploads awaiting your review/)
          expect(e).not_to be_retryable
        end
    end

    it 'marks a rate limit retryable' do
      expect { publish_with_error('rate_limit_exceeded', status: 429) }
        .to raise_error(Publishers::PublishError) do |e|
          expect(e.message).to match(/rate limiting/)
          expect(e).to be_retryable
        end
    end

    it 'marks a banned creator as a permanent failure' do
      expect { publish_with_error('spam_risk_user_banned_from_posting', status: 403) }
        .to raise_error(Publishers::PublishError) do |e|
          expect(e).not_to be_retryable
        end
    end

    it 'falls back to the message for an unrecognised code' do
      allow(Publishers::Http).to receive(:post_json).and_return(
        'error' => { 'code' => 'something_new', 'message' => 'brand new problem' }
      )

      expect { adapter.publish(post_record, post_target) }
        .to raise_error(Publishers::PublishError, /brand new problem/)
    end

    it 'treats an error code in a 200 body as a failure' do
      allow(Publishers::Http).to receive(:post_json).and_return(
        'data' => {}, 'error' => { 'code' => 'invalid_param', 'message' => 'bad video' }
      )

      expect { adapter.publish(post_record, post_target) }
        .to raise_error(Publishers::PublishError, /Check that it is between/)
    end
  end

  describe 'token refresh' do
    let(:account) do
      create(:social_account, :tiktok, expires_at: 1.minute.ago, refresh_token: 'old-refresh')
    end

    let(:refreshed) do
      {
        'access_token' => 'new-access',
        'refresh_token' => 'new-refresh',
        'expires_in' => 86_400
      }
    end

    it 'exchanges the refresh token before publishing' do
      stub_media_download
      allow(Publishers::Http).to receive(:post_json).and_return(init_response)
      allow(Publishers::Http).to receive(:put_binary).and_return(201)

      expect(Oauth::Http).to receive(:post_form).with(
        described_class::TOKEN_URL,
        hash_including(grant_type: 'refresh_token', refresh_token: 'old-refresh'),
        anything
      ).and_return(refreshed)

      adapter.publish(post_record, post_target)
    end

    it 'stores the rotated credentials' do
      allow(Oauth::Http).to receive(:post_form).and_return(refreshed)

      adapter.ensure_usable_token!

      expect(account.reload).to have_attributes(
        access_token: 'new-access',
        refresh_token: 'new-refresh',
        status: 'active'
      )
      expect(account.expires_at).to be_within(5.seconds).of(1.day.from_now)
    end

    it 'keeps the existing refresh token when TikTok does not rotate it' do
      allow(Oauth::Http).to receive(:post_form).and_return('access_token' => 'new-access')

      adapter.ensure_usable_token!

      expect(account.reload.refresh_token).to eq('old-refresh')
    end

    it 'asks the user to reconnect when the refresh is rejected' do
      allow(Oauth::Http).to receive(:post_form)
        .and_raise(Oauth::Http::Error.new('HTTP 400', status: 400))

      expect { adapter.ensure_usable_token! }
        .to raise_error(Publishers::TokenRefreshError, /Reconnect the account/)

      expect(account.reload).to be_status_expired
    end

    it 'asks the user to reconnect when no token comes back' do
      allow(Oauth::Http).to receive(:post_form)
        .and_return('error_description' => 'refresh token expired')

      expect { adapter.ensure_usable_token! }
        .to raise_error(Publishers::TokenRefreshError, /refresh token expired/)
    end
  end
end
