require 'net/http'
require 'json'
require 'openssl'
require 'base64'

class GoogleIdentity
  class Invalid < StandardError; end

  def self.exchange(code, nonce:)
    uri = URI('https://oauth2.googleapis.com/token')
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
      http.post(uri.request_uri, URI.encode_www_form(code: code, client_id: ENV.fetch('GOOGLE_CLIENT_ID'),
        client_secret: ENV.fetch('GOOGLE_CLIENT_SECRET'), redirect_uri: ENV.fetch('GOOGLE_CALLBACK_URL'),
        grant_type: 'authorization_code'), 'Content-Type' => 'application/x-www-form-urlencoded')
    end
    raise Invalid unless response.is_a?(Net::HTTPSuccess)
    token = JSON.parse(response.body).fetch('id_token')
    header_segment, payload_segment, signature_segment = token.split('.', 3)
    header = JSON.parse(Base64.urlsafe_decode64(header_segment))
    claims = JSON.parse(Base64.urlsafe_decode64(payload_segment))
    raise Invalid unless header['alg'] == 'RS256' && header['kid'].present?
    certificate = certificates[header['kid']] || certificates(force: true)[header['kid']]
    # As chaves só vêm do endpoint fixo do Google, nunca de um jku enviado no JWT.
    raise Invalid unless certificate
    signature = Base64.urlsafe_decode64(signature_segment)
    key = OpenSSL::X509::Certificate.new(certificate).public_key
    raise Invalid unless key.verify(OpenSSL::Digest::SHA256.new, signature, "#{header_segment}.#{payload_segment}")
    raise Invalid unless ['accounts.google.com', 'https://accounts.google.com'].include?(claims['iss'])
    raise Invalid unless claims['aud'] == ENV.fetch('GOOGLE_CLIENT_ID')
    raise Invalid if claims['azp'].present? && claims['azp'] != ENV.fetch('GOOGLE_CLIENT_ID')
    raise Invalid unless claims['exp'].to_i > Time.current.to_i && claims['iat'].to_i <= Time.current.to_i + 60
    raise Invalid unless claims['nonce'].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(claims['nonce'], nonce)
    raise Invalid unless claims['sub'].is_a?(String) && claims['sub'].length.between?(1, 255)
    raise Invalid unless claims['email_verified'] == true && claims['email'].to_s.match?(URI::MailTo::EMAIL_REGEXP)
    claims
  rescue Invalid
    raise
  rescue StandardError
    raise Invalid
  end

  def self.certificates(force: false)
    # Cache local limitado, independente do null_store usado em desenvolvimento.
    @lock ||= Mutex.new
    @lock.synchronize do
      if force || !@certificates || @expires_at.to_i <= Time.current.to_i
        uri = URI('https://www.googleapis.com/oauth2/v1/certs')
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.get(uri.request_uri) }
        raise Invalid unless response.is_a?(Net::HTTPSuccess)
        @certificates = JSON.parse(response.body)
        @expires_at = 30.minutes.from_now
      end
      @certificates
    end
  end
  private_class_method :certificates
end
