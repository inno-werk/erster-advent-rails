require "test_helper"
require "action_mailer/test_helper"
require "minitest/mock"

class DemoDataSeedTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    # Existing fixture shops plus eleven additional test-only shops cover each
    # scenario. The seeder itself must never create a user or a business.
    11.times do |index|
      user = User.new(email: "demo-owner-#{index}@example.com", password: "password123", role: 0)
      user.skip_confirmation!
      user.save!
      Business.create!(user: user, business_name: "Demo shop #{index}", address: "Gasse #{index}",
        billing_address: "Gasse #{index}", phone: "031 123 45 67", map_link: "https://example.com", status: :confirmed)
    end
  end

  test "adds diverse valid histories without changing shops users catalogue or sending emails" do
    before = preserved_records
    result = nil
    assert_no_emails { result = DemoData::Seed.new.call }
    assert_equal before, preserved_records
    assert_equal 13, result[:shops]
    assert_equal 5, Participation.distinct.count(:year)
    assert_equal 60, Participation.count
    assert_operator PrintOrder.count, :>=, 50
    assert_operator PrintOrderItem.count, :>=, 60
    assert_equal Participation::CATEGORIES.keys.sort, Participation.distinct.pluck(:category).sort
    assert Participation.pending.exists?
    assert Participation.paid.exists?
    assert ParticipationUpgrade.pending.exists?
    assert ParticipationUpgrade.paid.exists?
    assert PrintOrder.where.not(id: PrintOrderItem.select(:print_order_id)).exists?
    assert PrintOrderItem.where(quantity: 10).exists?
    assert_equal [ "dummy" ], Participation.paid.distinct.pluck(:payment_provider)
    Participation.find_each do |record|
      assert record.valid?, record.errors.full_messages.join(", ")
      assert_equal record.year, record.selected_at.year
      assert_match(/\ADEMO-/, record.payment_reference)
      assert_operator record.paid_at, :>=, record.created_at if record.paid?
    end
    ParticipationUpgrade.includes(:participation).find_each do |record|
      assert record.valid?, record.errors.full_messages.join(", ")
      assert_equal "no_listing", record.previous_category
      assert_includes [ 10_000, 15_000 ], record.difference_cents
      assert_equal record.participation.year, record.created_at.year
      assert record.payable? if record.pending?
      assert_equal record.category, record.participation.category if record.paid?
    end
  end

  test "preserves existing memberships payments orders and dates and is repeatable" do
    existing = participation_for(paid: true)
    existing.update!(payment_provider: "manual", payment_reference: "EXISTING")
    order = users(:member).print_orders.create!(year: EventConfiguration.year)
    order.items.create!(print_product: print_products(:posters), quantity: 4)
    dates = PrintDistribution.create!(year: EventConfiguration.year,
      distribution_on: Date.new(EventConfiguration.year, 10, 8), order_deadline_on: Date.new(EventConfiguration.year, 9, 17))
    original = [ existing.attributes, order.reload.attributes, order.items.map(&:attributes), dates.attributes ]
    DemoData::Seed.new.call
    assert_equal original, [ existing.reload.attributes, order.reload.attributes, order.items.reload.map(&:attributes), dates.reload.attributes ]
    snapshot = seeded_records
    result = DemoData::Seed.new.call
    assert_empty result[:created]
    assert_equal snapshot, seeded_records
  end

  test "refuses production and invalid year ranges before writing" do
    before = seeded_records
    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_raises(RuntimeError) { DemoData::Seed.new.call }
    end
    assert_raises(ArgumentError) { DemoData::Seed.new(year: 2000, years: 5) }
    assert_raises(ArgumentError) { DemoData::Seed.new(years: 20) }
    assert_equal before, seeded_records
  end

  test "rolls back an interrupted run and restores the clock" do
    before = seeded_records
    clock = Time.current
    PrintDistribution.stub(:create!, ->(*) { raise "simulated failure" }) do
      assert_raises(RuntimeError) { DemoData::Seed.new.call }
    end
    assert_equal before, seeded_records
    assert_in_delta clock.to_f, Time.current.to_f, 10
  end

  private

  def preserved_records
    [ User, Business, PrintProduct ].map { |model| model.order(:id).map(&:attributes) }
  end

  def seeded_records
    [ Participation, ParticipationUpgrade, PrintOrder, PrintOrderItem, PrintDistribution ].map { |model| model.order(:id).map(&:attributes) }
  end
end
