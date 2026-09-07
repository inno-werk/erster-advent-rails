namespace :print_materials do
  desc "Create print bundles and remove the old Gratis seed suffix without overwriting custom descriptions"
  task seed: :environment do
    PrintMaterials::Seed.call
  end
end
