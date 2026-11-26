# Creates (or completes) the Known Premium subscriptions in App Store Connect.
# Idempotent: re-running skips whatever already exists.
#
#   cd ios && APP_STORE_CONNECT_KEY_ID=… APP_STORE_CONNECT_ISSUER_ID=… \
#     APP_STORE_CONNECT_KEY_CONTENT="$(cat AuthKey_….p8)" \
#     bundle exec ruby ../tool/store/asc_plus_products.rb
#
# Products and prices are the ones in docs/PRODUCT.md §L. India (IND) is the
# base territory; Apple's equalised price points fill every other territory.
require 'json'
require 'jwt'
require 'net/http'
require 'openssl'
require 'uri'

APP_ID = '6839632799'
BASE = 'IND'
FEATURES = 'Trends over time and an AI summary of your Wall' # max 55

SUBS = [
  { product_id: 'wall_premium_yearly', name: 'Known Premium Yearly', period: 'ONE_YEAR', price: '999', level: 1 },
  { product_id: 'wall_premium_monthly', name: 'Known Premium Monthly', period: 'ONE_MONTH', price: '149', level: 2 }
].freeze

def token
  key = OpenSSL::PKey.read(ENV.fetch('APP_STORE_CONNECT_KEY_CONTENT'))
  JWT.encode({ iss: ENV.fetch('APP_STORE_CONNECT_ISSUER_ID'), exp: Time.now.to_i + 1100, aud: 'appstoreconnect-v1' },
             key, 'ES256', { kid: ENV.fetch('APP_STORE_CONNECT_KEY_ID') })
end

def api(method, path, body = nil)
  uri = URI(path.start_with?('http') ? path : "https://api.appstoreconnect.apple.com#{path}")
  req = Net::HTTP.const_get(method.capitalize).new(uri)
  req['Authorization'] = "Bearer #{token}"
  req['Content-Type'] = 'application/json'
  req.body = body.to_json if body
  3.times do |attempt|
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
    return(res.body.to_s.empty? ? {} : JSON.parse(res.body)) if res.code.to_i < 300
    if res.code.to_i >= 500 || res.code == '429'
      sleep(2**attempt * 2)
      next
    end
    raise "#{method} #{path} -> #{res.code}: #{res.body[0, 600]}"
  end
  raise "#{method} #{path}: gave up after retries"
end

def all_pages(path)
  out = []
  url = path
  while url
    page = api(:get, url)
    out.concat(page['data'])
    url = page.dig('links', 'next')
  end
  out
end

def rel(type, id) = { data: { type: type, id: id } }

# ------------------------------------------------------------------- group
groups = api(:get, "/v1/apps/#{APP_ID}/subscriptionGroups?limit=10")['data']
group = groups.find { |g| g.dig('attributes', 'referenceName') == 'Known Premium' }
group ||= api(:post, '/v1/subscriptionGroups', data: {
                type: 'subscriptionGroups', attributes: { referenceName: 'Known Premium' },
                relationships: { app: rel('apps', APP_ID) }
              })['data']
GROUP_ID = group['id']
puts "group: #{GROUP_ID}"

# ---------------------------------------------------------------- group copy
group_locs = api(:get, "/v1/subscriptionGroups/#{GROUP_ID}/subscriptionGroupLocalizations")['data']
if group_locs.none? { |l| l.dig('attributes', 'locale') == 'en-US' }
  api(:post, '/v1/subscriptionGroupLocalizations', data: {
        type: 'subscriptionGroupLocalizations',
        attributes: { name: 'Known Premium', locale: 'en-US' },
        relationships: { subscriptionGroup: rel('subscriptionGroups', GROUP_ID) }
      })
  puts 'group: en-US name set'
end

territories = all_pages('/v1/territories?limit=200').map { |t| t['id'] }
puts "territories: #{territories.size}"

# ------------------------------------------------------------ subscriptions
existing = api(:get, "/v1/subscriptionGroups/#{GROUP_ID}/subscriptions?limit=50")['data']
SUBS.each do |s|
  sub = existing.find { |x| x.dig('attributes', 'productId') == s[:product_id] }
  sub ||= api(:post, '/v1/subscriptions', data: {
                type: 'subscriptions',
                attributes: { name: s[:name], productId: s[:product_id], subscriptionPeriod: s[:period],
                              familySharable: false, groupLevel: s[:level], reviewNote: 'Unlocks Trends and the AI summary. Open My Wall, tap the Premium banner. The review account already has Premium.' },
                relationships: { group: rel('subscriptionGroups', GROUP_ID) }
              })['data']
  id = sub['id']
  puts "#{s[:product_id]}: #{id}"

  locs = api(:get, "/v1/subscriptions/#{id}/subscriptionLocalizations")['data']
  if locs.none? { |l| l.dig('attributes', 'locale') == 'en-US' }
    api(:post, '/v1/subscriptionLocalizations', data: {
          type: 'subscriptionLocalizations',
          attributes: { locale: 'en-US', name: s[:name], description: FEATURES },
          relationships: { subscription: rel('subscriptions', id) }
        })
    puts '  localization'
  end

  begin
    api(:post, '/v1/subscriptionAvailabilities', data: {
          type: 'subscriptionAvailabilities',
          attributes: { availableInNewTerritories: true },
          relationships: { subscription: rel('subscriptions', id),
                           availableTerritories: { data: territories.map { |t| { type: 'territories', id: t } } } }
        })
    puts '  availability: all territories'
  rescue RuntimeError => e
    puts "  availability: #{e.message[0, 120]}"
  end

  priced = api(:get, "/v1/subscriptions/#{id}/prices?limit=1")['data'].any?
  unless priced
    base_point = all_pages("/v1/subscriptions/#{id}/pricePoints?filter[territory]=#{BASE}&limit=200")
                 .find { |p| p.dig('attributes', 'customerPrice').to_f == s[:price].to_f }
    raise "no #{BASE} price point at #{s[:price]}" unless base_point

    points = [base_point] + all_pages("/v1/subscriptionPricePoints/#{base_point['id']}/equalizations?limit=200")
    points.each do |p|
      terr = p.dig('relationships', 'territory', 'data', 'id') || BASE
      api(:post, '/v1/subscriptionPrices', data: {
            type: 'subscriptionPrices',
            attributes: { preserveCurrentPrice: false },
            relationships: { subscription: rel('subscriptions', id),
                             subscriptionPricePoint: rel('subscriptionPricePoints', p['id']),
                             territory: rel('territories', terr) }
          })
    end
    puts "  prices: #{points.size} territories (#{BASE} ₹#{s[:price]})"
  end

  next unless s[:trial]

  offers = api(:get, "/v1/subscriptions/#{id}/introductoryOffers?limit=1")['data']
  next if offers.any?

  territories.each do |t|
    api(:post, '/v1/subscriptionIntroductoryOffers', data: {
          type: 'subscriptionIntroductoryOffers',
          attributes: { duration: s[:trial], offerMode: 'FREE_TRIAL', numberOfPeriods: 1 },
          relationships: { subscription: rel('subscriptions', id), territory: rel('territories', t) }
        })
  end
  puts "  free trial: #{s[:trial]} in #{territories.size} territories"
end

# ------------------------------------------------------- review screenshots
# The paywall as App Review sees it (tool/screenshots harness, "plus.png").
require 'digest'
shot = ENV['PLUS_REVIEW_SHOT'] || File.join(__dir__, '..', '..', 'build', 'screens', 'store', '04-trends.png')
if File.exist?(shot)
  bytes = File.binread(shot)
  upload = lambda do |type, rel_name, rel_type, owner_id|
    res = api(:post, "/v1/#{type}", data: {
                type: type,
                attributes: { fileName: 'known-premium.png', fileSize: bytes.bytesize },
                relationships: { rel_name => rel(rel_type, owner_id) }
              })['data']
    res.dig('attributes', 'uploadOperations').each do |op|
      uri = URI(op['url'])
      req = Net::HTTP.const_get(op['method'].capitalize).new(uri)
      op['requestHeaders'].each { |h| req[h['name']] = h['value'] }
      req.body = bytes.byteslice(op['offset'], op['length'])
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
    end
    api(:patch, "/v1/#{type}/#{res['id']}", data: {
          type: type, id: res['id'],
          attributes: { uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(bytes) }
        })
  end
  api(:get, "/v1/subscriptionGroups/#{GROUP_ID}/subscriptions?limit=50")['data'].each do |sub|
    has = api(:get, "/v1/subscriptions/#{sub['id']}/appStoreReviewScreenshot")['data'] rescue nil
    next if has

    upload.call('subscriptionAppStoreReviewScreenshots', :subscription, 'subscriptions', sub['id'])
    puts "review screenshot: #{sub.dig('attributes', 'productId')}"
  end
else
  puts "no review screenshot at #{shot}; run the screenshot harness first"
end
