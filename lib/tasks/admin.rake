namespace :admin do
  desc "Create or reset the single admin owner from ADMIN_EMAIL and ADMIN_PASSWORD"
  task create: :environment do
    email = ENV.fetch("ADMIN_EMAIL").strip.downcase
    password = ENV.fetch("ADMIN_PASSWORD")

    raise ArgumentError, "ADMIN_EMAIL must be a valid email address" unless email.match?(URI::MailTo::EMAIL_REGEXP)
    raise ArgumentError, "ADMIN_PASSWORD must be at least 14 characters" if password.length < 14

    user, recovery_codes = AdminUser.provision(email: email, password: password)

    puts "Owner credentials rotated. Save this output now; recovery codes are not recoverable."
    puts "TOTP provisioning URI:"
    puts user.totp_provisioning_uri
    puts "Recovery codes:"
    recovery_codes.each { |code| puts code }
  end
end
