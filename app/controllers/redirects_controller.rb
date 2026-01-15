class RedirectsController < ApplicationController
  def show
    short_link = ShortLink.find_by(slug: params[:slug])

    if short_link
      redirect_to short_link.destination, status: :found, allow_other_host: true
    else
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
    end
  end
end
