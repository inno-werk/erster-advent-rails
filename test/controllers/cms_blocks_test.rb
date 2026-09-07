require "test_helper"

class CmsBlocksTest < ActionDispatch::IntegrationTest
  setup do
    @faq = CmsBlock.create!(
      page: "home",
      position: 1,
      block_type: :faq_item,
      question: "Was ist neu?"
    )
  end

  test "admin edits an FAQ answer as rich text" do
    sign_in users(:admin)

    get edit_admin_cms_block_path(id: @faq.id)

    assert_response :success
    assert_select "label[for=cms_block_content]", text: "Antwort"
    assert_select "input[type=hidden][name='cms_block[content]']", count: 1
    assert_select "trix-editor", count: 1
    assert_select "textarea[name='cms_block[answer]']", count: 0

    patch admin_cms_block_path(id: @faq.id), params: {
      cms_block: {
        question: @faq.question,
        content: "<div>Eine <strong>wichtige</strong> Antwort</div>"
      }
    }

    assert_redirected_to edit_admin_cms_path
    assert_equal "Eine wichtige Antwort", @faq.reload.content.to_plain_text
  end

  test "homepage renders FAQ answer formatting and preserves legacy answers" do
    @faq.update!(content: "<div>Eine <strong>wichtige</strong> Antwort</div>")
    legacy_faq = CmsBlock.create!(
      page: "home",
      position: 2,
      block_type: :faq_item,
      question: "Was war bisher?",
      answer: "Eine bisherige Antwort"
    )

    get root_path

    assert_response :success
    assert_select ".accordion-row", text: /#{Regexp.escape(@faq.question)}/ do
      assert_select ".cms-rich-text strong", text: "wichtige"
    end
    assert_select ".accordion-row", text: /#{Regexp.escape(legacy_faq.question)}/ do
      assert_select ".text-body", text: "Eine bisherige Antwort"
    end
  end
end
