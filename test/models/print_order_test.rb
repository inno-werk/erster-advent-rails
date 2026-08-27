require "test_helper"

class PrintOrderTest < ActiveSupport::TestCase
  setup do
    @order = users(:member).print_orders.build(year: EventConfiguration.year)
    @product = print_products(:posters)
  end

  test "quantities count bundles and can be edited or removed" do
    assert @order.update_quantities({ @product.id.to_s => "2" }, products: PrintProduct.available)
    assert_equal 2, @order.reload.items.sole.quantity
    previous_update = @order.updated_at
    travel 1.minute do
      assert @order.update_quantities({ @product.id.to_s => "3" }, products: PrintProduct.available)
    end
    assert @order.reload.updated_at > previous_update
    assert_equal 3, @order.reload.items.sole.quantity
    assert @order.update_quantities({ @product.id.to_s => "0" }, products: PrintProduct.available)
    assert_empty @order.reload.items
  end

  test "negative fractional malformed and excessive quantities are rejected" do
    [ "-1", "1.5", "abc", "1abc", "100001" ].each do |quantity|
      order = users(:member).print_orders.build(year: EventConfiguration.year)
      assert_not order.update_quantities({ @product.id.to_s => quantity }, products: PrintProduct.available), quantity
    end
    assert_equal 0, PrintOrder.count
  end

  test "unknown or inactive products cannot be added by a user" do
    assert_not @order.update_quantities({ print_products(:inactive).id.to_s => "2" }, products: PrintProduct.available)
    assert_not @order.update_quantities({ "0" => "2" }, products: PrintProduct.available)
  end

  test "disabling a product preserves existing quantities while other items can change" do
    @order.update_quantities({ @product.id.to_s => "2" }, products: PrintProduct.available)
    @product.update!(active: false)
    assert @order.update_quantities({ print_products(:postcards).id.to_s => "3" }, products: PrintProduct.available)
    assert_equal 2, @order.reload.items.find_by!(print_product: @product).quantity
  end

  test "a failed update does not partially remove existing quantities" do
    @order.update_quantities({ @product.id.to_s => "2" }, products: PrintProduct.available)
    assert_not @order.update_quantities({ @product.id.to_s => "0", print_products(:postcards).id.to_s => "-1" }, products: PrintProduct.available)
    assert_equal 2, @order.reload.items.sole.quantity
  end

  test "annual order and per product uniqueness and database quantity constraints" do
    @order.update_quantities({ @product.id.to_s => "2" }, products: PrintProduct.available)
    assert_not @order.dup.valid?
    assert_not @order.items.sole.dup.valid?
    assert_raises(ActiveRecord::StatementInvalid) do
      PrintOrderItem.transaction(requires_new: true) { @order.items.sole.update_column(:quantity, 0) }
    end
    assert users(:member).print_orders.create!(year: EventConfiguration.year + 1)
    assert_equal 2, @order.reload.items.sole.quantity
  end
end
