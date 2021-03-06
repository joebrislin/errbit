require 'digest/sha1'

class Fingerprint

  attr_reader :notice, :api_key

  def self.generate(notice, api_key)
    self.new(notice, api_key).to_s
  end

  def initialize(notice, api_key)
    @notice = notice
    @api_key = api_key
  end

  def to_s
    Digest::SHA1.hexdigest(fingerprint_source.to_s)
  end

  def fingerprint_source
    {
      :backtrace_fingerprint => notice.backtrace.try(:fingerprint),
      :error_class => notice.error_class,
      :component => notice.component || 'unknown',
      :action => notice.action,
      :environment => notice.environment_name || 'development',
      :api_key => api_key
    }
  end
end
