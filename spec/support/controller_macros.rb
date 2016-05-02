# frozen_string_literal: true
module ControllerMacros
  def json
    JSON.parse(response.body)
  end

  def sign(payload, key)
    digest = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, key, payload)
  end
end
