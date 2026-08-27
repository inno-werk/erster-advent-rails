require "test_helper"

class ParticipationTest < ActiveSupport::TestCase
  test "missing delivery config uses readable fallback text instead of an empty options object" do
    previous = Rails.configuration.x.print_delivery_information
    Rails.configuration.x.print_delivery_information = ActiveSupport::OrderedOptions.new
    assert_kind_of String, EventConfiguration.print_delivery_information
    assert_match(/Verteiltag/, EventConfiguration.print_delivery_information)
  ensure
    Rails.configuration.x.print_delivery_information = previous
  end

  test "a selection snapshots amount and time and remains pending" do
    participation = participation_for
    assert_equal 20_000, participation.amount_cents
    assert participation.selected_at
    assert participation.pending?
    assert_not participation.complete?
    assert_nil participation.paid_at
  end

  test "pending category can change and resnapshots amount" do
    participation = participation_for
    participation.update!(category: "non_leist_member")
    assert_equal 25_000, participation.amount_cents
    participation.update!(category: "no_listing")
    assert_equal 10_000, participation.amount_cents
    assert_not participation.permits_listing?
  end

  test "unrelated updates do not reprice historical records" do
    participation = participation_for
    participation.update_column(:amount_cents, 19_000)
    participation.update!(payment_reference: "historical-reference")
    assert_equal 19_000, participation.reload.amount_cents
  end

  test "paid participation cannot change category or amount" do
    participation = participation_for(paid: true)
    assert_not participation.update(category: "no_listing")
    assert_equal "leist_member", participation.reload.category
    assert_not participation.update(amount_cents: 100)
    assert_equal 20_000, participation.reload.amount_cents
  end

  test "payment state transitions preserve a stable paid date and can be corrected" do
    participation = participation_for
    participation.mark_paid!
    paid_at = participation.paid_at
    participation.mark_paid!
    assert_equal paid_at, participation.paid_at
    assert participation.complete?
    participation.mark_unpaid!
    assert participation.pending?
    assert_nil participation.paid_at
  end

  test "one participation per user and year is enforced by model and database" do
    original = participation_for
    duplicate = original.dup
    assert_not duplicate.valid?
    assert duplicate.errors[:year].any?
    assert_raises(ActiveRecord::RecordNotUnique) do
      Participation.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end

  test "new year requires renewal and keeps historical snapshots" do
    previous = participation_for(year: EventConfiguration.year - 1, paid: true)
    assert_nil users(:member).current_participation
    assert_not users(:member).participation_complete?
    current = participation_for(category: "no_listing")
    assert_equal current, users(:member).current_participation
    assert previous.reload.paid?
    assert_equal 20_000, previous.amount_cents
    assert_equal 2, users(:member).participations.count
  end

  test "active year configuration changes lookups without changing history" do
    original = Rails.configuration.x.participation_year
    Rails.configuration.x.participation_year = 2030
    participation = participation_for(paid: true)
    assert_equal 2030, participation.year
    Rails.configuration.x.participation_year = 2031
    assert_nil users(:member).current_participation
    assert_equal 2030, participation.reload.year
  ensure
    Rails.configuration.x.participation_year = original
  end

  test "ownership and event year cannot be reassigned" do
    participation = participation_for
    assert_not participation.update(year: participation.year + 1)
    participation.reload
    assert_not participation.update(user: users(:other))
  end

  test "paid upgrades charge only the difference and keep the original tier until confirmation" do
    participation = participation_for(category: "no_listing", paid: true)
    original_paid_at = participation.paid_at
    upgrade = participation.request_upgrade("leist_member")
    assert upgrade.persisted?
    assert_equal [ 10_000, 20_000, 10_000 ], upgrade.values_at(:previous_amount_cents, :amount_cents, :difference_cents)
    assert_equal "no_listing", participation.reload.category
    assert_equal 10_000, participation.amount_due_cents
    assert participation.paid?
    assert participation.payment_due?
    assert_not users(:member).business_editing_allowed?
    assert_equal upgrade, participation.request_upgrade("leist_member")
    assert_equal 1, participation.upgrades.count
    assert_not participation.request_upgrade("non_leist_member").persisted?
    assert_raises(ActiveRecord::RecordNotUnique) do
      ParticipationUpgrade.transaction(requires_new: true) { participation.upgrades.create!(category: "non_leist_member") }
    end

    upgrade.mark_paid!
    assert_equal "leist_member", participation.reload.category
    assert_equal 20_000, participation.amount_cents
    assert_equal original_paid_at, participation.paid_at
    assert_equal 0, participation.amount_due_cents
    assert users(:member).business_editing_allowed?
    assert businesses(:member).publicly_visible?
    paid_at = upgrade.paid_at
    assert_equal paid_at, participation.last_payment_at
    upgrade.mark_paid!
    assert_equal paid_at, upgrade.paid_at
    assert_equal 20_000, participation.reload.amount_cents

    second = participation.request_upgrade("non_leist_member")
    assert_not second.persisted?
    assert second.errors.any?
    assert_equal 20_000, participation.reload.amount_cents
    assert_equal 10_000, participation.upgrades.paid.sum(:difference_cents)
    assert_empty participation.upgrade_categories
  end

  test "upgrade requests reject downgrades equal tiers and unpaid memberships" do
    participation = participation_for(category: "no_listing")
    assert_not participation.request_upgrade("non_leist_member").persisted?
    participation.mark_paid!
    %w[no_listing unknown].each do |category|
      upgrade = participation.request_upgrade(category)
      assert_not upgrade.persisted?
      assert upgrade.errors.any?
    end
    assert_equal "no_listing", participation.reload.category
    upgrade = participation.request_upgrade("non_leist_member")
    assert_equal 15_000, upgrade.difference_cents
    assert_not upgrade.update(difference_cents: 1)
    assert_equal 15_000, upgrade.reload.difference_cents
    assert_raises(ActiveRecord::RecordInvalid) { participation.mark_unpaid! }
    assert participation.reload.paid?
    upgrade.mark_paid!
    assert_equal "non_leist_member", participation.reload.category
    assert_equal 25_000, participation.amount_cents
    assert_empty participation.upgrade_categories
    assert_not participation.request_upgrade("leist_member").persisted?
  end

  test "neither listed paid category permits upgrade creation through the model" do
    Participation::LISTED_CATEGORIES.zip([ users(:member), users(:other) ]).each do |category, user|
      participation = participation_for(user, category: category, paid: true)
      Participation::CATEGORIES.each_key do |target|
        upgrade = participation.upgrades.build(category: target)
        assert_not upgrade.save
        assert_not upgrade.payable?
      end
      assert_not participation.upgrade_available?
    end
  end

  test "upgrade quote uses the paid snapshot rather than repricing the original tier" do
    participation = participation_for(category: "no_listing")
    participation.update_column(:amount_cents, 9_000)
    participation.mark_paid!
    upgrade = participation.request_upgrade("non_leist_member")
    assert_equal 16_000, upgrade.difference_cents
    assert_equal 9_000, upgrade.previous_amount_cents
  end
end
