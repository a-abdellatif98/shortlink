require 'rails_helper'

RSpec.describe 'Redirects', type: :request do
  describe 'GET /:slug' do
    let!(:short_link) { ShortLink.create!(destination: 'https://github.com', slug: 'gh', custom: true) }

    context 'with existing slug' do
      it 'redirects to the destination URL' do
        get "/#{short_link.slug}"

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to('https://github.com')
      end

      it 'redirects with 302 status' do
        get "/#{short_link.slug}"
        expect(response.status).to eq(302)
      end

      it 'allows redirects to other hosts' do
        get "/#{short_link.slug}"
        expect(response.location).to eq('https://github.com')
      end

      it 'redirects for auto-generated slugs' do
        auto_link = ShortLink.create!(destination: 'https://example.com')
        get "/#{auto_link.slug}"

        expect(response).to redirect_to('https://example.com')
      end
    end

    context 'with non-existent slug' do
      it 'returns 404 page' do
        get '/nonexistent'

        expect(response).to have_http_status(:not_found)
      end

      it 'renders the 404 error page' do
        get '/nonexistent'

        expect(response.body).to_not be_empty
      end
    end

    context 'with special characters in slug' do
      it 'handles slugs with hyphens' do
        link = ShortLink.create!(destination: 'https://example.com', slug: 'my-link', custom: true)
        get '/my-link'

        expect(response).to redirect_to('https://example.com')
      end

      it 'handles slugs with underscores' do
        link = ShortLink.create!(destination: 'https://example.com', slug: 'my_link', custom: true)
        get '/my_link'

        expect(response).to redirect_to('https://example.com')
      end
    end

    context 'route precedence' do
      it 'does not conflict with /api routes' do
        get '/api/v1/decode/test'
        expect(response.status).to_not eq(302) # Should not redirect
      end

      it 'prioritizes named routes over slug matching' do
        # root path should not be caught by slug matcher
        get '/'
        expect(response.status).to eq(200)
        expect(response.body).to include('ShortLink')
      end
    end
  end
end
