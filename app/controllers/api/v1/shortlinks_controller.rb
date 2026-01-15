module Api
  module V1
    class ShortlinksController < ApplicationController
      skip_before_action :verify_authenticity_token

      def encode
        short_link = ShortLink.new(encode_params)
        short_link.custom = params[:slug].present?

        if short_link.save
          render json: {
            slug: short_link.slug,
            short_url: shortlink_url(short_link.slug),
            destination: short_link.destination,
            created_at: short_link.created_at
          }, status: :created
        else
          render json: {
            error: "Failed to create shortlink",
            messages: short_link.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def decode
        short_link = ShortLink.find_by(slug: params[:slug])

        if short_link
          render json: {
            slug: short_link.slug,
            destination: short_link.destination,
            custom: short_link.custom,
            created_at: short_link.created_at
          }
        else
          render json: {
            error: "Shortlink not found"
          }, status: :not_found
        end
      end

      private

      def encode_params
        params.permit(:url, :slug).transform_keys do |key|
          key == "url" ? "destination" : key
        end
      end

      def shortlink_url(slug)
        "#{request.protocol}#{request.host_with_port}/#{slug}"
      end
    end
  end
end
