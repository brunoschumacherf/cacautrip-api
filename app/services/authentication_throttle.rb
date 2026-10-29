require 'digest'

# Proteção local por processo; em produção, aplique também limites no gateway.
class AuthenticationThrottle
  LOCK = Mutex.new
  ATTEMPTS = {}

  def self.allow?(address)
    key = Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{address}")
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    LOCK.synchronize do
      ATTEMPTS.delete_if { |_, entry| now - entry[:start] >= 60 }
      return false if ATTEMPTS.size >= 10_000 && !ATTEMPTS.key?(key)
      entry = ATTEMPTS[key] ||= { start: now, count: 0 }
      entry[:count] += 1
      entry[:count] <= 15
    end
  end
end
