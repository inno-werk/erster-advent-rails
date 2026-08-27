require "active_support/testing/time_helpers"

# Run only in the isolated Rake process: travelling the clock lets the normal
# payment/upgrade APIs build consistent historical snapshots and timestamps.
class DemoData::Seed
  include ActiveSupport::Testing::TimeHelpers

  SCENARIOS = [
    [ "leist_member", :paid ],
    [ "non_leist_member", :paid ],
    [ "no_listing", :pending ],
    [ "no_listing", :paid ],
    [ "no_listing", :upgrade_pending, "leist_member" ],
    [ "no_listing", :upgrade_pending, "non_leist_member" ],
    [ "no_listing", :upgrade_paid, "leist_member" ],
    [ "no_listing", :upgrade_paid, "non_leist_member" ],
    [ "leist_member", :pending ],
    [ "non_leist_member", :pending ],
    [ "leist_member", :paid ],
    nil,
    [ "non_leist_member", :paid ]
  ].freeze

  def initialize(year: EventConfiguration.year, years: 5)
    @year = Integer(year)
    @years = Integer(years)
    raise ArgumentError, "Choose 1–10 years within 2000–9999" unless (1..10).cover?(@years) && (2000..9999).cover?(@year) && @year - @years + 1 >= 2000

    @now = Time.current
    @created = Hash.new(0)
    @preserved = Hash.new(0)
  end

  def call
    raise "Demo data is restricted to development and test" unless Rails.env.development? || Rails.env.test?

    years = @year.downto(@year - @years + 1).to_a
    owners = User.active.where(id: Business.where.not(status: :deleted).select(:user_id)).order(:id).to_a
    raise "No existing active shops found; no data was changed" if owners.empty?

    @products = PrintProduct.available.ordered.to_a
    raise "No active print products found; run bin/rails print_materials:seed first" if @products.empty?

    ApplicationRecord.transaction do
      owners.each_with_index do |owner, index|
        owner.with_lock do
          years.each_with_index do |year, offset|
            seed_membership(owner, year, index, offset)
            seed_order(owner, year, index, offset)
          end
        end
      end
      years.each { |year| seed_distribution(year) }
    end
    { shops: owners.size, years: years, created: @created.to_h, preserved: @preserved.to_h }
  end

  private

  def seed_membership(owner, year, index, offset)
    if owner.participations.exists?(year: year)
      @preserved[:memberships] += 1
      return
    end
    scenario = SCENARIOS[(index + offset * 3) % SCENARIOS.size]
    return unless scenario

    category, status, upgrade_category = scenario
    participation = at_seed_time(year, index, 0) do
      owner.participations.create!(year: year, category: category,
        payment_reference: "DEMO-#{year}-#{owner.id}-MEMBERSHIP")
    end
    @created[:memberships] += 1
    return if status == :pending

    at_seed_time(year, index, 1) do
      participation.update!(payment_provider: "dummy")
      participation.mark_paid!
    end
    @created[:paid_memberships] += 1
    return unless upgrade_category

    upgrade = at_seed_time(year, index, 2) do
      record = participation.request_upgrade(upgrade_category)
      raise ActiveRecord::RecordInvalid, record unless record.persisted?
      record.update!(payment_reference: "DEMO-#{year}-#{owner.id}-UPGRADE")
      record
    end
    @created[:upgrades] += 1
    if status == :upgrade_paid
      at_seed_time(year, index, 3) do
        upgrade.update!(payment_provider: "dummy")
        upgrade.mark_paid!
      end
      @created[:paid_upgrades] += 1
    end
  end

  def seed_order(owner, year, index, offset)
    if owner.print_orders.exists?(year: year)
      @preserved[:print_orders] += 1
      return
    end
    pattern = (index + offset * 3) % 9
    return if pattern == 7 # No order yet; distinct from an intentionally empty order.

    order = at_seed_time(year, index, 1) { owner.print_orders.create!(year: year) }
    @created[:print_orders] += 1
    products = case pattern
    when 1 then @products.first(1)
    when 2 then @products.last(1)
    when 3 then @products.first(2)
    when 4 then @products.each_with_index.filter_map { |product, i| product if i.even? }
    when 6 then []
    else @products
    end
    at_seed_time(year, index, 3) do
      quantities = products.each_with_index.to_h do |product, i|
        [ product.id.to_s, ((index * 3 + offset * 2 + i * 7) % 10 + 1).to_s ]
      end
      unless order.update_quantities(quantities, products: @products, maximum_quantity: 10)
        raise ActiveRecord::RecordInvalid, order
      end
    end
    @created[:print_items] += products.size
  end

  def seed_distribution(year)
    if PrintDistribution.exists?(year: year)
      @preserved[:distribution_dates] += 1
      return
    end
    PrintDistribution.create!(year: year, order_deadline_on: Date.new(year, 11, 1), distribution_on: Date.new(year, 11, 15))
    @created[:distribution_dates] += 1
  end

  def at_seed_time(year, index, phase, &block)
    start = Time.zone.local(year, 1, 1)
    finish = year == @now.year ? @now : Time.zone.local(year, 11, 30, 18)
    fraction = 0.2 + (index % SCENARIOS.size) * 0.04 + phase * 0.04
    travel_to(start + (finish - start) * fraction, &block)
  end
end
