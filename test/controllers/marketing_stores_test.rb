require "test_helper"

class MarketingStoresTest < ActionDispatch::IntegrationTest
  test "listing and detail require admin confirmation only" do
    businesses(:member).pending!
    get marketing_stores_path
    assert_select "a[href=?]", marketing_store_path(businesses(:member)), count: 0
    get marketing_store_path(businesses(:member))
    assert_redirected_to marketing_stores_path

    businesses(:member).confirmed!
    participation_for
    get marketing_stores_path
    assert_response :success
    assert_select "a[href=?]", marketing_store_path(businesses(:member))
    get marketing_store_path(businesses(:member))
    assert_response :success
  end

  test "category C cannot be accessed through list detail search or featured stores" do
    participation_for(category: "no_listing", paid: true)
    get marketing_stores_path(q: "Testgeschäft")
    assert_select "a[href=?]", marketing_store_path(businesses(:member)), count: 0
    get marketing_store_path(businesses(:member))
    assert_redirected_to marketing_stores_path
    get root_path
    assert_response :success
    assert_select "a[href=?]", marketing_store_path(businesses(:member)), count: 0
  end

  test "public store page shows phone and email only when the business opted in" do
    business = businesses(:member)
    business.update!(email: "laden@example.com", show_phone_publicly: false, show_email_publicly: false)
    participation_for

    get marketing_store_path(id: business.id)
    assert_response :success
    assert_no_match "031 123 45 67", response.body
    assert_select "a[href='mailto:laden@example.com']", count: 0

    business.update!(show_phone_publicly: true, show_email_publicly: true)
    get marketing_store_path(id: business.id)
    assert_match "031 123 45 67", response.body
    assert_select "a[href='mailto:laden@example.com']"
  end

  test "member can change public contact visibility in the store editor" do
    sign_in users(:member)
    get edit_app_mystore_path
    assert_select "input[type=checkbox][name='business[show_phone_publicly]']"
    assert_select "input[type=checkbox][name='business[show_email_publicly]']"

    patch app_mystore_path, params: { business: { show_phone_publicly: "1", show_email_publicly: "0" } }
    assert_redirected_to app_mystore_path
    business = businesses(:member).reload
    assert business.show_phone_publicly?
    assert_not business.show_email_publicly?
  end
end
