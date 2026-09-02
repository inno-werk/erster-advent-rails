require "test_helper"

class BusinessTest < ActiveSupport::TestCase
  test "admin confirmation alone makes a business publicly visible" do
    business = businesses(:member)
    assert business.publicly_visible?
    assert_includes Business.publicly_visible, business
  end

  test "listing does not depend on payment status" do
    business = businesses(:member)
    participation = participation_for
    assert business.publicly_visible?
    participation.mark_paid!
    assert business.publicly_visible?
    participation.mark_unpaid!
    assert business.publicly_visible?
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
    participation = participation_for(category: "no_listing")
    assert_not businesses(:member).publicly_visible?
    assert_not_includes Business.publicly_visible, businesses(:member)
    participation.mark_paid!
    assert_not businesses(:member).publicly_visible?
  end

  test "a previous year no listing membership does not hide the business" do
    participation_for(category: "no_listing", year: EventConfiguration.year - 1, paid: true)
    assert businesses(:member).publicly_visible?
  end

  test "deleted users are excluded" do
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
