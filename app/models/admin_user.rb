class AdminUser < ApplicationRecord
  RECOVERY_CODE_COUNT = 10
  RECOVERY_CODE_BYTES = 10
  TOTP_ISSUER = "Portfolio"

  has_secure_password reset_token: { expires_in: 30.minutes }
  encrypts :totp_secret

  has_many :admin_sessions, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 14 }, if: -> { password.present? }
  validates :totp_secret, presence: true
  validates :singleton_guard, inclusion: { in: [1] }

  class << self
    def generate_recovery_code
      SecureRandom.hex(RECOVERY_CODE_BYTES).upcase.scan(/.{4}/).join("-")
    end

    def digest_recovery_code(code)
      normalized = code.to_s.upcase.delete(" \t-")
      key = Rails.application.key_generator.generate_key("admin-recovery-codes", 32)
      OpenSSL::HMAC.hexdigest("SHA256", key, normalized)
    end
  end

  def reset_password(attributes)
    transaction do
      next false unless update(attributes)

      admin_sessions.delete_all
      true
    end
  end

  def verify_totp(code)
    normalized = code.to_s.delete(" \t-")
    return false unless normalized.match?(/\A\d{6}\z/)

    with_lock do
      options = {
        at: Time.current,
        drift_behind: 30,
        drift_ahead: 30
      }
      options[:after] = last_totp_at.to_i if last_totp_at
      verified_at = totp.verify(normalized, **options)
      next false unless verified_at

      update!(last_totp_at: Time.zone.at(verified_at))
      true
    end
  end

  def replace_recovery_codes
    codes = Array.new(RECOVERY_CODE_COUNT) { self.class.generate_recovery_code }
    update!(recovery_code_digests: codes.map { |code| self.class.digest_recovery_code(code) })
    codes
  end

  def consume_recovery_code(code)
    normalized = code.to_s.upcase.delete(" \t-")
    return false unless normalized.match?(/\A[0-9A-F]{20}\z/)

    candidate = self.class.digest_recovery_code(normalized)

    with_lock do
      index = recovery_code_digests.index do |digest|
        ActiveSupport::SecurityUtils.secure_compare(candidate, digest)
      end
      next false unless index

      update!(recovery_code_digests: recovery_code_digests.each_with_index.filter_map { |digest, i| digest unless i == index })
      true
    end
  end

  def totp_provisioning_uri
    totp.provisioning_uri(email)
  end

  private

  def totp
    ROTP::TOTP.new(totp_secret, issuer: TOTP_ISSUER, digits: 6, interval: 30)
  end
end
