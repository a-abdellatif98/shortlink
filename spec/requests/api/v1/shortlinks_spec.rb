require 'rails_helper'

RSpec.describe 'Api::V1::Shortlinks', type: :request do
  describe 'POST /api/v1/encode' do
    context 'with valid URL' do
      it 'creates a shortlink and returns JSON' do
        post '/api/v1/encode', params: { url: 'https://github.com' }, as: :json

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json).to include(
          'slug',
          'short_url',
          'destination',
          'created_at'
        )
        expect(json['destination']).to eq('https://github.com')
        expect(json['short_url']).to match(%r{http://.*/.+})
      end

      it 'normalizes URL without protocol' do
        post '/api/v1/encode', params: { url: 'example.com' }, as: :json

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['destination']).to eq('https://example.com')
      end

      it 'creates unique slugs for multiple requests' do
        slugs = []

        3.times do |i|
          post '/api/v1/encode', params: { url: "https://example#{i}.com" }, as: :json
          json = JSON.parse(response.body)
          slugs << json['slug']
        end

        expect(slugs.uniq.length).to eq(3)
      end
    end

    context 'with custom slug' do
      it 'creates shortlink with custom slug' do
        post '/api/v1/encode', params: { url: 'https://github.com', slug: 'gh' }, as: :json

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['slug']).to eq('gh')
      end

      it 'rejects duplicate custom slugs' do
        post '/api/v1/encode', params: { url: 'https://first.com', slug: 'duplicate' }, as: :json
        expect(response).to have_http_status(:created)

        post '/api/v1/encode', params: { url: 'https://second.com', slug: 'duplicate' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('Failed to create shortlink')
        expect(json['messages']).to include('Slug has already been taken')
      end

      it 'rejects reserved slugs' do
        post '/api/v1/encode', params: { url: 'https://example.com', slug: 'api' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['messages']).to include('Slug is reserved and cannot be used')
      end

      it 'rejects invalid slug characters' do
        post '/api/v1/encode', params: { url: 'https://example.com', slug: 'invalid slug' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['messages'].join).to match(/can only contain/)
      end
    end

    context 'with invalid URL' do
      it 'rejects javascript: URLs' do
        post '/api/v1/encode', params: { url: 'javascript:alert(1)' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Failed to create shortlink')
        expect(json['messages']).to be_present
      end

      it 'rejects data: URLs' do
        post '/api/v1/encode', params: { url: 'data:text/html,<script>' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects empty URL' do
        post '/api/v1/encode', params: { url: '' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['messages']).to include("Destination can't be blank")
      end
    end

    context 'without URL parameter' do
      it 'returns error' do
        post '/api/v1/encode', params: {}, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/decode/:slug' do
    let!(:short_link) { ShortLink.create!(destination: 'https://github.com', slug: 'gh', custom: true) }

    context 'with existing slug' do
      it 'returns shortlink details' do
        get "/api/v1/decode/#{short_link.slug}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json).to include(
          'slug' => 'gh',
          'destination' => 'https://github.com',
          'custom' => true
        )
        expect(json).to have_key('created_at')
      end

      it 'returns details for auto-generated slug' do
        auto_link = ShortLink.create!(destination: 'https://example.com')
        get "/api/v1/decode/#{auto_link.slug}"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['custom']).to be false
      end
    end

    context 'with non-existent slug' do
      it 'returns 404 with error message' do
        get '/api/v1/decode/nonexistent'

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Shortlink not found')
      end
    end

    context 'with invalid slug format' do
      it 'returns 404' do
        get '/api/v1/decode/invalid%20slug'

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'API security' do
    it 'does not require CSRF token for API endpoints' do
      # Rails would normally reject this without CSRF token
      post '/api/v1/encode', params: { url: 'https://example.com' }, as: :json
      expect(response).to have_http_status(:created)
    end

    it 'accepts JSON content type' do
      post '/api/v1/encode',
           params: { url: 'https://example.com' }.to_json,
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:created)
    end
  end
end
