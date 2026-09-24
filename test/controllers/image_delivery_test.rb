require "test_helper"

class ImageDeliveryTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")
  EPS = "%!PS-Adobe-3.0 EPSF-3.0\n%%BoundingBox: 0 0 10 10\nshowpage\n"
  VARIANT_PROXY = %r{/rails/active_storage/representations/proxy/}
  BLOB_PROXY = %r{/rails/active_storage/blobs/proxy/}

  setup do
    participation_for
    @business = businesses(:member)
  end

  test "store listing and detail serve resized variants through the proxy" do
    @business.update!(main_image: { io: StringIO.new(PNG), filename: "logo.png" })

    get marketing_stores_path
    assert_select ".store-card-media a[href=?] img[loading=lazy]", marketing_store_path(@business) do |images|
      assert_match VARIANT_PROXY, images.first["src"]
    end

    get marketing_store_path(@business)
    assert_select ".business-gallery-slider img" do |images|
      assert images.all? { |image| image["src"].match?(VARIANT_PROXY) }
    end
  end

  test "an image that cannot be resized falls back to the original file" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(EPS), filename: "old.eps")
    ActiveStorage::Attachment.create!(record: @business, name: "main_image", blob: blob)

    get marketing_stores_path

    assert_select ".store-card-media a[href=?] img", marketing_store_path(@business) do |images|
      assert_match BLOB_PROXY, images.first["src"]
    end
  end

  test "proxied files are cacheable for a year" do
    @business.update!(main_image: { io: StringIO.new(PNG), filename: "logo.png" })

    get rails_storage_proxy_path(@business.main_image)

    assert_response :success
    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=#{1.year.to_i}"
  end

  test "new uploads queue their variants for preprocessing" do
    assert_enqueued_with(job: ActiveStorage::TransformJob) do
      @business.update!(main_image: { io: StringIO.new(PNG), filename: "logo.png" })
      perform_enqueued_jobs(only: ActiveStorage::AnalyzeJob)
    end
  end
end
