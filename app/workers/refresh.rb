require 'net/http'

module Net
  class HTTP::Purge < HTTPRequest
    METHOD='PURGE'
    REQUEST_HAS_BODY = false
    RESPONSE_HAS_BODY = true
  end
end

class Refresh
  include Sidekiq::Worker

  sidekiq_options queue: 'reindex', unique: true, retry: 3

  def perform(version_id)
    version = Version.find(version_id)

    purge(version.gem_url)
    purge(version.gemspec_url)

    true
  end

  def purge(url)
    uri = URI.parse(url)

    Net::HTTP.start(uri.host, uri.port) do |http|
      req = Net::HTTP::Purge.new(uri.request_uri)
      req['X-Shelly-Cache-Auth'] = ENV['SHELLY_CACHE_AUTH']
      resp = http.request(req)
      unless (200...400).include?(resp.code.to_i)
        raise "A problem occurred. PURGE was not performed. Status code: #{resp.code}"
      end
    end
  end
end
