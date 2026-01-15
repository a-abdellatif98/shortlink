class ShortLink < ApplicationRecord
  ALPHABET = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
  RESERVED_SLUGS = %w[api admin].freeze
  RANDOM_SLUG_LENGTH = 7

  validates :slug, presence: true, uniqueness: true
  validates :destination, presence: true
  validate :validate_url_format

  before_validation :generate_slug, unless: :slug?
  before_validation :normalize_destination

  def self.id_to_slug(id)
    return ALPHABET[0] if id.zero?
    slug = ""
    while id > 0
      slug = ALPHABET[id % 62] + slug
      id /= 62
    end
    slug
  end

  def generate_slug
    self.slug = RANDOM_SLUG_LENGTH.times.map { ALPHABET.sample }.join
  end

  private

  def normalize_destination
    return unless destination.present?
    unless destination =~ /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}/
      self.destination = "https://#{destination}"
    end
  end

  def validate_url_format
    return if destination.blank?
    begin
      uri = URI.parse(destination)
      unless %w[http https].include?(uri.scheme)
        errors.add(:destination, "must be a valid HTTP or HTTPS URL")
      end
    rescue URI::InvalidURIError
      errors.add(:destination, "is not a valid URL")
    end
  end
end
