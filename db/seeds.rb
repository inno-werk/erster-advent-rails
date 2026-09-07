# Environment-specific seed entry point used by db:seed and db:prepare.
case Rails.env
when "production"
  ProductionSeed.call
  puts "Production baseline is ready; no demo businesses or payments were created."
when "development"
  load Rails.root.join("db/seeds/development.rb")
else
  puts "No seed data is defined for #{Rails.env}."
end
