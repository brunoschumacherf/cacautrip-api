Rails.application.config.filter_parameters += [
  :password, :password_confirmation, :password_digest, :token, :authorization,
  :document_reference, :license_plate, :card, :number, :cvv, :expiry,
  :content, :message, :comment
]
