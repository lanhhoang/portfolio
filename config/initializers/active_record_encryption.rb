keys = if Rails.env.production?
  {
    primary_key: ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"),
    deterministic_key: ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"),
    key_derivation_salt: ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
  }
else
  generator = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
  {
    primary_key: generator.generate_key("active-record-encryption-primary", 32),
    deterministic_key: generator.generate_key("active-record-encryption-deterministic", 32),
    key_derivation_salt: generator.generate_key("active-record-encryption-salt", 32)
  }
end

ActiveRecord::Encryption.configure(**keys)
