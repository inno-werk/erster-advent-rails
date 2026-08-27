require "test_helper"

class BusinessTest < ActiveSupport::TestCase
  test "confirmed business needs current year paid membership" do
    business = businesses(:member)
    assert_not business.publicly_visible?
    participation = participation_for
    assert_not business.publicly_visible?
    participation.mark_paid!
    assert business.publicly_visible?
    assert_includes Business.publicly_visible, business
    participation.mark_unpaid!
    assert_not business.publicly_visible?
  end

  test "both listed categories are eligible only after admin confirmation" do
    participation_for(category: "non_leist_member", paid: true)
    business = businesses(:member)
    assert business.publicly_visible?
    business.pending!
    assert_not business.publicly_visible?
    business.rejected!
    assert_not business.publicly_visible?
  end

  test "category C is never publicly visible even when paid and confirmed" do
    participation_for(category: "no_listing", paid: true)
    assert_not businesses(:member).publicly_visible?
    assert_not_includes Business.publicly_visible, businesses(:member)
  end

  test "previous year and deleted users are excluded" do
    participation_for(year: EventConfiguration.year - 1, paid: true)
    assert_not businesses(:member).publicly_visible?
    participation_for(paid: true)
    users(:member).update!(deleted: true)
    assert_not businesses(:member).publicly_visible?
  end

  test "only the current years no listing membership prevents business editing" do
    user = users(:member)
    assert user.business_editing_allowed?
    participation_for(user, category: "no_listing", year: EventConfiguration.year - 1, paid: true)
    assert user.business_editing_allowed?
    current = participation_for(user, category: "no_listing")
    assert_not user.business_editing_allowed?
    current.update!(category: "non_leist_member")
    assert user.business_editing_allowed?
  end
end
