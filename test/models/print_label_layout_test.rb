require "test_helper"

class PrintLabelLayoutTest < ActiveSupport::TestCase
  test "default layout uses a full A4 two by eight grid" do
    layout = PrintLabelLayout.new
    assert_predicate layout, :valid?
    assert_equal 16, layout.per_page
    assert_equal 105, layout.label_width
    assert_equal 37.125, layout.label_height
  end

  test "margins and gaps determine the remaining label dimensions" do
    layout = PrintLabelLayout.new(columns: 3, rows: 4, margin_top: 11, margin_bottom: 13,
      margin_left: 10, margin_right: 14, gap_horizontal: 3, gap_vertical: 5)
    assert_predicate layout, :valid?
    assert_equal 60, layout.label_width
    assert_equal 64.5, layout.label_height
  end

  test "rejects invalid counts nonnumeric values and excessive dimensions" do
    [ { columns: 0 }, { rows: "1.5" }, { columns: "2junk" }, { font_size: "NaN" },
      { margin_top: -1 }, { margin_left: "Infinity" }, { gap_vertical: 31 }, { rows: 21 }, { font_size: 50 } ].each do |attributes|
      assert_not PrintLabelLayout.new(attributes).valid?, attributes.inspect
    end
  end

  test "rejects unusable label areas after subtracting margins gaps and padding" do
    [ { columns: 6, margin_left: 90, margin_right: 90 }, { rows: 20 },
      { padding_horizontal: 20, columns: 4 }, { margin_top: 100, margin_bottom: 100, gap_vertical: 20 } ].each do |attributes|
      layout = PrintLabelLayout.new(attributes)
      assert_not layout.valid?, attributes.inspect
      assert layout.errors[:base].any?
    end
  end
end
