class ShortLinksController < ApplicationController
  def index
    @short_link = ShortLink.new
    @recent_links = ShortLink.order(created_at: :desc).limit(10)
  end
end
