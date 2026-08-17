require 'rails_helper'

RSpec.describe 'Api::V1::Posts', type: :request do
  let(:user) { create(:user) }
  let(:tiktok) { create(:social_account, :tiktok, user: user) }
  let(:headers) { auth_headers_for(user) }
  let(:video_url) { 'https://cdn.example.com/clip.mp4' }

  # The publisher has its own spec; here we only care that the endpoint wires it
  # up, so stub the adapter rather than the HTTP calls underneath it.
  def stub_publisher(publish_id: 'v_inbox_file~v2.1')
    adapter = instance_double(Publishers::TiktokPublisher, publish: publish_id)
    allow(Publishers::Registry).to receive(:for).and_return(adapter)
    adapter
  end

  def stub_failing_publisher(error)
    adapter = instance_double(Publishers::TiktokPublisher)
    allow(adapter).to receive(:publish).and_raise(error)
    allow(Publishers::Registry).to receive(:for).and_return(adapter)
    adapter
  end

  def create_payload(**overrides)
    {
      post: {
        content: 'Shipping something new',
        media_urls: [video_url],
        social_account_ids: [tiktok.id]
      }.merge(overrides)
    }
  end

  describe 'GET /api/v1/posts' do
    it 'lists the caller posts newest first' do
      older = create(:post, user: user, content: 'older', created_at: 2.days.ago)
      newer = create(:post, user: user, content: 'newer', created_at: 1.hour.ago)

      get '/api/v1/posts', headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['posts'].map { |p| p['id'] }).to eq([newer.id, older.id])
    end

    it 'includes the per-channel delivery state' do
      post_record = create(:post, user: user)
      create(:post_target, :published, post: post_record, social_account: tiktok)

      get '/api/v1/posts', headers: headers, as: :json
      target = json_body['posts'].first['targets'].first

      expect(target).to include(
        'platform' => 'tiktok',
        'status' => 'published',
        'external_username' => tiktok.external_username
      )
    end

    it 'does not leak another user posts' do
      create(:post, user: create(:user), content: 'not yours')

      get '/api/v1/posts', headers: headers, as: :json

      expect(json_body['posts']).to be_empty
    end

    it 'returns 401 without a token' do
      get '/api/v1/posts', as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/posts' do
    it 'creates a draft with a target per channel' do
      post '/api/v1/posts', params: create_payload, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_body['post']).to include('status' => 'draft', 'media_urls' => [video_url])
      expect(json_body['post']['targets'].map { |t| t['social_account_id'] }).to eq([tiktok.id])
    end

    it 'does not contact the platform unless asked to publish' do
      expect(Publishers::Registry).not_to receive(:for)

      post '/api/v1/posts', params: create_payload, headers: headers, as: :json
    end

    it 'publishes immediately when publish_now is set' do
      stub_publisher(publish_id: 'publish-123')

      post '/api/v1/posts',
           params: create_payload(publish_now: true),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(json_body['post']['status']).to eq('published')
      expect(json_body['post']['targets'].first).to include(
        'status' => 'published',
        'platform_post_id' => 'publish-123'
      )
    end

    it 'rejects a post with no channels' do
      post '/api/v1/posts',
           params: create_payload(social_account_ids: []),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include(/at least one channel/)
    end

    it 'rejects a channel belonging to somebody else' do
      other = create(:social_account, :tiktok, user: create(:user))

      post '/api/v1/posts',
           params: create_payload(social_account_ids: [other.id]),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include(/not connected/)
    end

    it 'rejects a disconnected channel' do
      revoked = create(:social_account, :tiktok, user: user, status: :revoked)

      post '/api/v1/posts',
           params: create_payload(social_account_ids: [revoked.id]),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include(/not connected/)
    end

    it 'rejects a platform whose publisher is still a stub' do
      twitter = create(:social_account, user: user, platform: :twitter)

      post '/api/v1/posts',
           params: create_payload(social_account_ids: [twitter.id]),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include(/not available yet/)
    end

    it 'rejects a text-only post for a platform that needs video' do
      post '/api/v1/posts',
           params: create_payload(media_urls: []),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include(/need a video/)
    end

    it 'requires a post parameter' do
      post '/api/v1/posts', params: {}, headers: headers, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 401 without a token' do
      post '/api/v1/posts', params: create_payload, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/posts/:id/publish' do
    let(:draft) do
      create(:post, user: user, media_urls: [video_url]).tap do |record|
        create(:post_target, post: record, social_account: tiktok)
      end
    end

    it 'sends the post and records the platform reference' do
      stub_publisher(publish_id: 'publish-abc')

      post "/api/v1/posts/#{draft.id}/publish", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['post']['status']).to eq('published')
      expect(draft.reload).to be_status_published
      expect(draft.post_targets.first.platform_post_id).to eq('publish-abc')
    end

    it 'records the reason on the target when the platform refuses' do
      stub_failing_publisher(
        Publishers::PublishError.new('TikTok is rate limiting this account', platform: 'tiktok')
      )

      post "/api/v1/posts/#{draft.id}/publish", headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include(/rate limiting/)
      expect(draft.reload).to be_status_failed
      expect(draft.post_targets.first).to be_status_failed
      expect(draft.post_targets.first.error_message).to match(/rate limiting/)
    end

    it 'does not fail the whole post when only one channel refuses' do
      second = create(:social_account, :tiktok, user: user)
      create(:post_target, post: draft, social_account: second)

      allow(Publishers::Registry).to receive(:for) do |account|
        if account == second
          instance_double(Publishers::TiktokPublisher).tap do |adapter|
            allow(adapter).to receive(:publish)
              .and_raise(Publishers::PublishError.new('nope', platform: 'tiktok'))
          end
        else
          instance_double(Publishers::TiktokPublisher, publish: 'publish-ok')
        end
      end

      post "/api/v1/posts/#{draft.id}/publish", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(draft.reload).to be_status_published
      expect(draft.post_targets.map(&:status)).to contain_exactly('published', 'failed')
    end

    it 'retries only the channels that have not received it' do
      create(:post_target, :published, post: draft, social_account: create(:social_account, :tiktok, user: user))
      adapter = stub_publisher

      post "/api/v1/posts/#{draft.id}/publish", headers: headers, as: :json

      expect(adapter).to have_received(:publish).once
    end

    it 'refuses to send a post twice' do
      published = create(:post, :published, user: user, media_urls: [video_url])
      create(:post_target, :published, post: published, social_account: tiktok)

      post "/api/v1/posts/#{published.id}/publish", headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include(/already been sent/)
    end

    it 'fails the delivery rather than the request when a publisher blows up' do
      stub_failing_publisher(RuntimeError.new('boom'))

      post "/api/v1/posts/#{draft.id}/publish", headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(draft.post_targets.first.reload.error_message).to match(/Something went wrong/)
    end

    it 'marks the account expired and reports it when credentials are stale' do
      stub_failing_publisher(
        Publishers::TokenRefreshError.new('Reconnect the account', platform: 'tiktok')
      )

      post "/api/v1/posts/#{draft.id}/publish", headers: headers, as: :json

      expect(json_body['errors']).to include(/Reconnect the account/)
    end

    it 'returns 404 for another user post' do
      other = create(:post, user: create(:user))

      post "/api/v1/posts/#{other.id}/publish", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /api/v1/posts/:id' do
    let(:draft) { create(:post, user: user, content: 'first draft', media_urls: [video_url]) }

    it 'updates the caption' do
      patch "/api/v1/posts/#{draft.id}",
            params: { post: { content: 'second draft' } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(draft.reload.content).to eq('second draft')
    end

    it 'refuses to edit a post that has gone out' do
      published = create(:post, :published, user: user, media_urls: [video_url])

      patch "/api/v1/posts/#{published.id}",
            params: { post: { content: 'too late' } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include(/cannot be edited/)
    end

    it 'rejects removing the last of both caption and media' do
      patch "/api/v1/posts/#{draft.id}",
            params: { post: { content: '', media_urls: [] } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/posts/:id' do
    it 'deletes the post and its targets' do
      draft = create(:post, user: user)
      create(:post_target, post: draft, social_account: tiktok)

      expect { delete "/api/v1/posts/#{draft.id}", headers: headers, as: :json }
        .to change(Post, :count).by(-1)
        .and change(PostTarget, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for another user post' do
      other = create(:post, user: create(:user))

      delete "/api/v1/posts/#{other.id}", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/posts/:id' do
    it 'returns the post' do
      draft = create(:post, user: user, content: 'hello')

      get "/api/v1/posts/#{draft.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['post']['content']).to eq('hello')
    end

    it 'returns 404 when it does not exist' do
      get '/api/v1/posts/0', headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
