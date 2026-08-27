namespace :print_materials do
  desc "Create print bundles and remove the old Gratis seed suffix without overwriting custom descriptions"
  task seed: :environment do
    [
      [ "posters", "3 × Plakate", "Ein Bündel mit 3 Plakaten im Format A2." ],
      [ "postcards", "50 × Postkarten", "Ein Bündel mit 50 Postkarten im Format A6." ],
      [ "city_maps", "25 × gedruckte Stadtpläne", "Ein Bündel mit 25 gedruckten Stadtplänen im Format A5." ]
    ].each_with_index do |(key, title, description), position|
      product = PrintProduct.find_or_create_by!(seed_key: key) do |record|
        record.assign_attributes(title: title, description: description, position: position)
      end
      product.update!(description: description) if product.description == "#{description} Gratis."
    end
  end
end
