require "test_helper"
require "minitest/mock"

class ProductionSeedTest < ActiveSupport::TestCase
  setup do
    User.where(email: ProductionSeed::ADMIN_EMAIL).destroy_all
    CmsBlock.destroy_all
    PrintProduct.delete_all
    SiteSetting.delete_all
  end

  test "creates the complete production baseline once and prints the generated admin credentials once" do
    first_output = nil
    second_output = nil

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      first_output = capture_io { ProductionSeed.call }.first
      second_output = capture_io { ProductionSeed.call }.first
    end

    admin = User.find_by!(email: ProductionSeed::ADMIN_EMAIL)
    generated_password = first_output[/Password: (.+)/, 1]

    assert admin.admin?
    assert admin.confirmed?
    assert generated_password.present?
    assert admin.valid_password?(generated_password)
    assert_match(/Created production admin/, first_output)
    assert_match(/Production admin already exists/, second_output)
    refute_match(/Password:/, second_output)

    assert_equal 1, User.where(email: ProductionSeed::ADMIN_EMAIL).count
    assert_equal 1, SiteSetting.count
    assert_equal SiteSetting::DEFAULT_BRAND_COLOR, SiteSetting.first.brand_color
    assert_equal PrintMaterials::Seed::PRODUCTS.map(&:first).sort, PrintProduct.pluck(:seed_key).sort
    assert_equal 4, CmsBlock.sections.count
    assert_equal 5, CmsBlock.faq_items.count
    assert_equal 3, CmsBlock.sections.count { |block| block.image.attached? }
    assert_equal FrontpageCms::Seed::FAQS.map(&:first), CmsBlock.faq_items.ordered.pluck(:question)
    assert_equal FrontpageCms::Seed::FAQS.map(&:second), faq_answers
  end

  test "uses the configured seed admin email" do
    email = "first-admin@example.com"

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      with_environment("SEED_ADMIN_EMAIL" => "  FIRST-ADMIN@example.com ") do
        capture_io { ProductionSeed.call }
      end
    end

    assert User.find_by!(email: email).admin?
    assert_nil User.find_by(email: ProductionSeed::ADMIN_EMAIL)
  ensure
    User.where(email: email).destroy_all
  end

  test "refuses an incompatible existing account with the seed admin email" do
    member = User.new(email: ProductionSeed::ADMIN_EMAIL, password: "password123", role: 0)
    member.skip_confirmation!
    member.save!

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      error = assert_raises(RuntimeError) { ProductionSeed.call }
      assert_equal "Seed admin email belongs to an incompatible account", error.message
    end
  end

  test "refuses to run outside production" do
    assert_raises(RuntimeError) { ProductionSeed.call }
  end

  test "development seed refuses production" do
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_raises(RuntimeError) { load Rails.root.join("db/seeds/development.rb") }
    end
  end

  private

  def faq_answers
    CmsBlock.faq_items.ordered.map { |item| item.content.to_plain_text.strip }
  end

  def with_environment(values)
    previous = values.to_h { |key, _value| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
