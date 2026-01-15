require 'rails_helper'

RSpec.describe ShortLink, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      link = ShortLink.new(destination: 'https://example.com')
      expect(link).to be_valid
    end

    it 'requires a destination' do
      link = ShortLink.new(destination: nil)
      expect(link).not_to be_valid
      expect(link.errors[:destination]).to include("can't be blank")
    end

    it 'requires a unique slug' do
      ShortLink.create!(destination: 'https://example.com', slug: 'test')
      duplicate = ShortLink.new(destination: 'https://example2.com', slug: 'test')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include('has already been taken')
    end

    it 'validates destination is a valid URL' do
      link = ShortLink.new(destination: 'not_a_url')
      expect(link).to be_valid # Should normalize to https://not_a_url
    end

    it 'blocks javascript: URLs' do
      link = ShortLink.new(destination: 'javascript:alert(1)')
      expect(link).not_to be_valid
      expect(link.errors[:destination]).to be_present
    end

    it 'blocks data: URLs' do
      link = ShortLink.new(destination: 'data:text/html,<script>alert(1)</script>')
      expect(link).not_to be_valid
      expect(link.errors[:destination]).to be_present
    end

    it 'blocks vbscript: URLs' do
      link = ShortLink.new(destination: 'vbscript:msgbox')
      expect(link).not_to be_valid
      expect(link.errors[:destination]).to be_present
    end

    # SSRF Protection Tests
    it 'blocks localhost URLs' do
      [ 'http://localhost/admin', 'http://127.0.0.1/admin', 'http://0.0.0.0/router' ].each do |url|
        link = ShortLink.new(destination: url)
        expect(link).not_to be_valid
        expect(link.errors[:destination]).to include("cannot point to localhost")
      end
    end

    it 'blocks private IPv4 ranges (10.x.x.x)' do
      link = ShortLink.new(destination: 'http://10.0.0.1/admin')
      # Note: This test requires DNS resolution, so we'll mock it
      allow(Resolv::DNS).to receive(:new).and_return(
        double(getaddresses: [ Resolv::IPv4.create('10.0.0.1') ])
      )
      expect(link).not_to be_valid
      expect(link.errors[:destination]).to include("cannot point to private or internal IP addresses")
    end

    it 'blocks private IPv4 ranges (192.168.x.x)' do
      link = ShortLink.new(destination: 'http://192.168.1.1/router')
      allow(Resolv::DNS).to receive(:new).and_return(
        double(getaddresses: [ Resolv::IPv4.create('192.168.1.1') ])
      )
      expect(link).not_to be_valid
      expect(link.errors[:destination]).to include("cannot point to private or internal IP addresses")
    end

    it 'blocks private IPv4 ranges (172.16-31.x.x)' do
      link = ShortLink.new(destination: 'http://172.16.0.1/internal')
      allow(Resolv::DNS).to receive(:new).and_return(
        double(getaddresses: [ Resolv::IPv4.create('172.16.0.1') ])
      )
      expect(link).not_to be_valid
      expect(link.errors[:destination]).to include("cannot point to private or internal IP addresses")
    end

    it 'blocks AWS metadata endpoint' do
      link = ShortLink.new(destination: 'http://169.254.169.254/latest/meta-data')
      allow(Resolv::DNS).to receive(:new).and_return(
        double(getaddresses: [ Resolv::IPv4.create('169.254.169.254') ])
      )
      expect(link).not_to be_valid
      expect(link.errors[:destination]).to include("cannot point to private or internal IP addresses")
    end

    it 'allows public URLs' do
      link = ShortLink.new(destination: 'https://google.com')
      # Mock DNS to return public IP
      allow(Resolv::DNS).to receive(:new).and_return(
        double(getaddresses: [ Resolv::IPv4.create('8.8.8.8') ])
      )
      expect(link).to be_valid
    end

    it 'rejects reserved slugs' do
      ShortLink::RESERVED_SLUGS.each do |reserved_slug|
        link = ShortLink.new(destination: 'https://example.com', slug: reserved_slug)
        expect(link).not_to be_valid
        expect(link.errors[:slug]).to include('is reserved and cannot be used')
      end
    end

    it 'validates custom slug format' do
      link = ShortLink.new(destination: 'https://example.com', slug: 'valid-slug_123', custom: true)
      expect(link).to be_valid

      invalid_link = ShortLink.new(destination: 'https://example.com', slug: 'invalid slug with spaces', custom: true)
      expect(invalid_link).not_to be_valid
    end

    it 'enforces case-insensitive slug uniqueness' do
      ShortLink.create!(destination: 'https://example.com', slug: 'GitHub', custom: true)

      duplicate = ShortLink.new(destination: 'https://example2.com', slug: 'github', custom: true)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include('has already been taken')
    end

    it 'prevents case-insensitive slug collisions (reverse case)' do
      ShortLink.create!(destination: 'https://example.com', slug: 'myslug', custom: true)

      duplicate = ShortLink.new(destination: 'https://example2.com', slug: 'MySlug', custom: true)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include('has already been taken')
    end

    it 'accepts slugs up to 50 characters' do
      long_slug = 'a' * 50
      link = ShortLink.new(destination: 'https://example.com', slug: long_slug, custom: true)
      expect(link).to be_valid
      link.save!
      expect(link.slug).to eq(long_slug)
    end

    it 'rejects slugs longer than 50 characters' do
      too_long_slug = 'a' * 51
      link = ShortLink.new(destination: 'https://example.com', slug: too_long_slug, custom: true)
      expect(link).not_to be_valid
      expect(link.errors[:slug]).to include('is too long (maximum is 50 characters)')
    end
  end

  describe 'callbacks' do
    it 'normalizes destination by adding https:// if missing' do
      link = ShortLink.create!(destination: 'example.com')
      expect(link.destination).to eq('https://example.com')
    end

    it 'does not modify destination if protocol exists' do
      link = ShortLink.create!(destination: 'http://example.com')
      expect(link.destination).to eq('http://example.com')
    end

    it 'generates slug automatically if not provided' do
      link = ShortLink.create!(destination: 'https://example.com')
      expect(link.slug).to be_present
      expect(link.slug.length).to be > 0
    end

    it 'does not generate slug if one is provided' do
      link = ShortLink.create!(destination: 'https://example.com', slug: 'custom', custom: true)
      expect(link.slug).to eq('custom')
    end
  end

  describe '.id_to_slug' do
    it 'converts ID 0 to first character' do
      expect(ShortLink.id_to_slug(0)).to eq('a')
    end

    it 'converts ID 1 to "b"' do
      expect(ShortLink.id_to_slug(1)).to eq('b')
    end

    it 'converts ID 61 to "9"' do
      expect(ShortLink.id_to_slug(61)).to eq('9')
    end

    it 'converts ID 62 to "ba"' do
      expect(ShortLink.id_to_slug(62)).to eq('ba')
    end

    it 'converts ID 123 to "b9"' do
      expect(ShortLink.id_to_slug(123)).to eq('b9')
    end

    it 'converts large IDs correctly' do
      expect(ShortLink.id_to_slug(3843)).to eq('99')
      expect(ShortLink.id_to_slug(238327)).to eq('999')
    end

    it 'returns variable length slugs (no padding)' do
      expect(ShortLink.id_to_slug(1).length).to eq(1)
      expect(ShortLink.id_to_slug(62).length).to eq(2)
      expect(ShortLink.id_to_slug(3844).length).to eq(3)
    end
  end

  describe '.slug_to_id' do
    it 'converts slug back to ID' do
      expect(ShortLink.slug_to_id('a')).to eq(0)
      expect(ShortLink.slug_to_id('b')).to eq(1)
      expect(ShortLink.slug_to_id('ba')).to eq(62)
      expect(ShortLink.slug_to_id('b9')).to eq(123)
    end

    it 'is inverse of id_to_slug' do
      [ 0, 1, 61, 62, 123, 3843, 238327 ].each do |id|
        slug = ShortLink.id_to_slug(id)
        expect(ShortLink.slug_to_id(slug)).to eq(id)
      end
    end
  end

  describe '#generate_slug' do
    context 'with random strategy' do
      before { stub_const('ShortLink::SLUG_STRATEGY', :random) }

      it 'generates random 7-character slugs' do
        link = ShortLink.create!(destination: 'https://example.com')
        expect(link.slug.length).to eq(7)
        expect(link.slug).to match(/\A[a-zA-Z0-9]{7}\z/)
      end

      it 'generates unique random slugs for multiple records' do
        links = 10.times.map { ShortLink.create!(destination: 'https://example.com') }
        slugs = links.map(&:slug)
        expect(slugs.uniq.length).to eq(10)  # All unique
      end

      it 'generates non-sequential slugs' do
        links = 5.times.map { ShortLink.create!(destination: 'https://example.com') }
        slugs = links.map(&:slug)

        # Random slugs should not be in alphabetical order
        # (probability of 5 random slugs being sorted is astronomically low)
        expect(slugs).not_to eq(slugs.sort)
      end
    end

    context 'with sequential strategy' do
      before { stub_const('ShortLink::SLUG_STRATEGY', :sequential) }

      it 'generates unique slugs for multiple records' do
        links = 5.times.map { ShortLink.create!(destination: 'https://example.com') }
        slugs = links.map(&:slug)
        expect(slugs.uniq.length).to eq(5)
      end
    end

    context 'collision handling' do
      before { stub_const('ShortLink::SLUG_STRATEGY', :sequential) }

      it 'skips slugs that are already taken by custom slugs' do
        # Create a custom slug that would conflict with auto-generated
        next_id = ShortLink.maximum(:id).to_i + 1
        expected_slug = ShortLink.id_to_slug(next_id)

        ShortLink.create!(destination: 'https://custom.com', slug: expected_slug, custom: true)

        # Next auto-generated should skip the taken slug
        auto_link = ShortLink.create!(destination: 'https://auto.com')
        expect(auto_link.slug).not_to eq(expected_slug)
      end

      it 'retries with incremented IDs when slugs are taken' do
        # Pre-fill the next 3 expected slugs
        next_id = ShortLink.maximum(:id).to_i + 1
        3.times do |i|
          slug = ShortLink.id_to_slug(next_id + i)
          ShortLink.create!(destination: "https://prefill-#{i}.com", slug: slug, custom: true)
        end

        # The next auto-generated link should skip the taken slugs and use next_id + 3
        auto_link = ShortLink.create!(destination: 'https://auto.com')
        expected_slug = ShortLink.id_to_slug(next_id + 3)
        expect(auto_link.slug).to eq(expected_slug)
      end
    end

    it 'handles concurrent slug generation without collisions' do
      # Simulate concurrent requests by creating multiple links in threads
      threads = []
      links = []
      mutex = Mutex.new

      10.times do |i|
        threads << Thread.new do
          link = ShortLink.create!(destination: "https://concurrent-#{i}.com")
          mutex.synchronize { links << link }
        end
      end

      threads.each(&:join)

      # All slugs should be unique
      slugs = links.map(&:slug)
      expect(slugs.length).to eq(10)
      expect(slugs.uniq.length).to eq(10)
    end
  end

  describe 'custom attribute' do
    it 'defaults to false' do
      link = ShortLink.create!(destination: 'https://example.com')
      expect(link.custom).to be false
    end

    it 'can be set to true for custom slugs' do
      link = ShortLink.create!(destination: 'https://example.com', slug: 'mycustom', custom: true)
      expect(link.custom).to be true
    end
  end
end
