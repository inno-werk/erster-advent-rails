namespace :images do
  desc "Generate the resized variants of all uploaded images (safe to re-run; existing variants are skipped)"
  task preprocess: :environment do
    { Business => %i[main_image image_gallery1 image_gallery2 image_gallery3],
      CmsBlock => %i[image],
      PrintProduct => %i[image] }.each do |model, names|
      names.each do |name|
        variants = model.reflect_on_attachment(name).named_variants.keys

        ActiveStorage::Attachment.where(record_type: model.name, name: name.to_s).includes(:blob).find_each do |attachment|
          unless attachment.variable?
            puts "skip #{model.name}##{attachment.record_id} #{name}: #{attachment.blob.content_type} cannot be resized"
            next
          end

          variants.each { |variant| attachment.variant(variant).processed }
          puts "ok   #{model.name}##{attachment.record_id} #{name}"
        rescue StandardError => e
          puts "fail #{model.name}##{attachment.record_id} #{name}: #{e.class}: #{e.message}"
        end
      end
    end
  end
end
