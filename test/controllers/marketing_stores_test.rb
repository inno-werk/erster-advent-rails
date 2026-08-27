require "test_helper"

class MarketingStoresTest < ActionDispatch::IntegrationTest
  test "listing and detail require paid current listed participation and confirmation" do
    participation = participation_for
    get marketing_stores_path
    assert_select "a[href=?]", marketing_store_path(businesses(:member)), count: 0
    get marketing_store_path(businesses(:member))
    assert_redirected_to marketing_stores_path

    participation.mark_paid!
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
end
