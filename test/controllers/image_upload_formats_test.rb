require "test_helper"

class ImageUploadFormatsTest < ActionDispatch::IntegrationTest
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
  WEBP = Base64.decode64("UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA=")
  EPS ="%!PS-Adobe-3.0 EPSF-3.0\n%%BoundingBox: 0 0 10 10\nshowpage\n"

  test "business images reject formats an img tag cannot display" do
    business = businesses(:member)

    business.main_image = { io: StringIO.new(EPS), filename: "logo.eps", content_type: "application/postscript" }
    business.image_gallery1 = { io: StringIO.new(PNG), filename: "logo.png", content_type: "image/png" }

    assert_not business.valid?
    assert_includes business.errors[:main_image].join, "JPEG, PNG, WebP oder GIF"
    assert_empty business.errors[:image_gallery1]
  end

  test "business images accept WebP" do
    business = businesses(:member)
    business.main_image = { io: StringIO.new(WEBP), filename: "logo.webp" }

    assert business.valid?
    assert_equal "image/webp", business.main_image.blob.content_type
  end

  test "content type is sniffed from the bytes, not the filename" do
    business = businesses(:member)
    business.main_image = { io: StringIO.new(EPS), filename: "logo.jpg", content_type: "image/jpeg" }

    assert_not business.valid?
  end

  test "an already stored unsupported image does not block saving other fields" do
    business = businesses(:member)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(EPS), filename: "old.eps")
    ActiveStorage::Attachment.create!(record: business, name: "main_image", blob: blob)

    assert business.reload.update(phone: "044 000 00 00")
  end

  test "a rejected upload keeps the stored image" do
    business = businesses(:member)
    business.update!(main_image: { io: StringIO.new(PNG), filename: "logo.png", content_type: "image/png" })

    assert_not business.update(main_image: { io: StringIO.new(EPS), filename: "logo.eps" })
    assert_equal "logo.png", business.main_image.filename.to_s
    assert_equal "logo.png", business.reload.main_image.filename.to_s
  end

  test "member uploading an EPS gets the form back with an error and keeps no attachment" do
    sign_in users(:member)
    business = users(:member).business

    patch app_mystore_path, params: {
      business: { main_image: Rack::Test::UploadedFile.new(StringIO.new(EPS), "application/postscript", original_filename: "logo.eps") }
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /JPEG, PNG, WebP oder GIF/
    assert_select "input[type=file][name='business[main_image]'][accept='#{WebImageAttachments::ACCEPT}']"
    assert_not business.reload.main_image.attached?
  end

  test "member can still upload a PNG" do
    sign_in users(:member)

    patch app_mystore_path, params: {
      business: { main_image: Rack::Test::UploadedFile.new(StringIO.new(PNG), "image/png", original_filename: "logo.png") }
    }

    assert_redirected_to app_mystore_path
    assert users(:member).business.reload.main_image.attached?
  end

  test "admin uploading an EPS to a CMS block is rejected" do
    block = CmsBlock.create!(page: "home", block_type: :text_image_block)
    sign_in users(:admin)

    patch admin_cms_block_path(id: block.id), params: {
      cms_block: { image: Rack::Test::UploadedFile.new(StringIO.new(EPS), "application/postscript", original_filename: "logo.eps") }
    }

    assert_response :unprocessable_entity
    assert_not block.reload.image.attached?
  end
end
