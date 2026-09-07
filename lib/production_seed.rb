class ProductionSeed
  ADMIN_EMAIL = "admin@erster-advent-bern.ch".freeze

  def self.call
    raise "ProductionSeed may only run in production" unless Rails.env.production?

    SiteSetting.first_or_create!(brand_color: SiteSetting::DEFAULT_BRAND_COLOR)
    PrintMaterials::Seed.call
    FrontpageCms::Seed.call

    email = ENV["SEED_ADMIN_EMAIL"].to_s.strip.downcase.presence || ADMIN_EMAIL
    matching_admins = User.where("LOWER(email) = ?", email).to_a
    raise "Seed admin email belongs to multiple accounts" if matching_admins.many?

    admin = matching_admins.first
    validate_existing_admin!(admin) if admin

    generated_password = nil
    unless admin
      generated_password = SecureRandom.base58(32)
      admin = User.new(email: email, password: generated_password, role: 1)
      admin.skip_confirmation!
      admin.save!
    end

    print_admin(admin, generated_password)
    admin
  end

  def self.validate_existing_admin!(admin)
    return if admin.admin? && admin.confirmed? && !admin.deleted? && !admin.access_locked?

    raise "Seed admin email belongs to an incompatible account"
  end
  private_class_method :validate_existing_admin!

  def self.print_admin(admin, generated_password)
    if generated_password
      puts "Created production admin:"
      puts "  Email: #{admin.email}"
      puts "  Password: #{generated_password}"
      puts "Store this password securely; it will not be printed again."
    else
      puts "Production admin already exists: #{admin.email} (credentials unchanged)."
    end
  end
  private_class_method :print_admin
end
