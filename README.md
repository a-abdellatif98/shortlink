# ShortLink

A URL shortening service built with Ruby on Rails.

## Installation

```bash
bundle install
bin/dev
```

The application will be available at `http://localhost:3000`

## Usage

### Web Interface
Navigate to `http://localhost:3000` and enter a URL to shorten it.

### API

**Create shortlink:**
```bash
curl -X POST http://localhost:3000/api/v1/encode \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'
```

**Get link info:**
```bash
curl http://localhost:3000/api/v1/decode/:slug
```

## Tech Stack

- Ruby on Rails 8.1.2
- SQLite3
- Tailwind CSS

## Security Considerations

While this is a proof-of-concept implementation, here are the key security concerns and how they're addressed:

### Current Protections

**URL Validation**: The app validates that all destination URLs use HTTP/HTTPS protocols only, preventing javascript: or data: URI attacks that could lead to XSS.

**Unique Slugs**: Database-level uniqueness constraints prevent slug collisions and ensure each short code maps to exactly one destination.

**Reserved Slugs**: Critical paths like `/api` and `/admin` are protected from being registered as shortcuts.

### Known Attack Vectors

**Malicious URL Shortening**: Anyone can shorten URLs pointing to phishing sites, malware, or other harmful content. A production system would need:
- URL reputation checking (integration with safe browsing APIs)
- Content scanning before accepting URLs
- User authentication to track who creates links
- Abuse reporting mechanisms

**Rate Limiting**: Currently there's no rate limiting, so an attacker could flood the system with shortlink creation requests. Solutions include:
- Redis-based rate limiting per IP address
- CAPTCHA for anonymous users
- Authentication with per-user quotas

**Slug Enumeration**: The random 7-character slugs are easy to enumerate (62^7 = 3.5 trillion combinations, but attackers could scan popular patterns). Consider:
- Blocking sequential scanning attempts
- Using longer slugs for sensitive content
- Analytics to detect unusual access patterns

**Open Redirect**: By design, this service redirects to any URL. While legitimate, this can be exploited in phishing attacks where `yourshortlink.com/abc123` appears trustworthy but redirects somewhere malicious. Mitigation strategies:
- Display an interstitial warning page for external domains
- Maintain a blocklist of known malicious domains
- Show the destination URL before redirecting

**Denial of Service**: Large-scale automated creation of shortlinks could exhaust database resources or slug namespace. Production systems need:
- Request throttling
- Database connection pooling
- Monitoring and alerting on unusual patterns

## Scalability Considerations

This implementation is designed for simplicity, not scale. Here's how you'd approach each challenge in a production environment:

### Collision Handling

**Current Approach**: We generate a random 7-character slug from 62 possible characters (a-z, A-Z, 0-9), giving us 62^7 ≈ 3.5 trillion possible combinations. The database uniqueness constraint prevents collisions.

**The Problem**: If a collision occurs (random generation picks an existing slug), the current implementation would fail the save. With the first million links, collision probability is only 0.00003%, but this grows as the namespace fills up.

**Production Solutions**:
1. **Retry with exponential backoff**: Catch uniqueness violations and regenerate the slug 3-5 times before failing
2. **Increase slug length**: Using 8 characters gives 62^8 ≈ 218 trillion combinations
3. **Sequential IDs with base62 encoding**: The model includes an `id_to_slug` method that converts database IDs to base62, ensuring zero collisions but making URLs somewhat predictable
4. **Partitioned namespaces**: Use different slug prefixes for different user tiers or content types

### Database Scaling

**Current Setup**: SQLite works great for development but has limitations at scale.

**Scaling Path**:
- **Phase 1** (up to ~100K links): Current SQLite setup is fine
- **Phase 2** (100K-10M links): Migrate to PostgreSQL, add database indexes on `slug` (already have this via uniqueness) and `created_at`
- **Phase 3** (10M+ links):
  - Read replicas for slug lookups (reads >> writes in this use case)
  - Connection pooling (PgBouncer)
  - Database partitioning by date if analytics on old links aren't critical

### Caching Strategy

Shortlink lookups are perfect for caching since URLs rarely change:

- **Redis/Memcached**: Cache slug → destination mappings with 24hr TTL
- **CDN edge caching**: Serve redirects from edge locations worldwide
- **Application-level cache**: Rails cache for frequently accessed links

This could reduce database load by 90%+ for popular links.

### Horizontal Scaling

The app is stateless and easy to scale horizontally:
- Run multiple Rails instances behind a load balancer
- Use managed Redis for centralized caching and rate limiting
- Consider splitting read/write workloads to different server pools

### Analytics at Scale

If tracking clicks becomes important:
- Write click events to a message queue (RabbitMQ, Kafka) rather than directly to DB
- Process analytics asynchronously in batches
- Store analytics in a separate time-series database (TimescaleDB, InfluxDB)

**Note**: These scaling solutions are documented for architectural understanding. The current implementation intentionally prioritizes simplicity and clarity over optimization.
