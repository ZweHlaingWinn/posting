require 'rails_helper'

RSpec.describe 'Root', type: :request do
  describe 'GET /' do
    it 'returns ok so the API hostname is not a RoutingError' do
      get '/', as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body).to eq('status' => 'ok')
    end
  end
end
