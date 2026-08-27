namespace :demo_data do
  desc "Add varied demo memberships, simulated payments and print orders to existing shops (development/test only)"
  task seed: :environment do
    result = DemoData::Seed.new(year: ENV.fetch("YEAR", EventConfiguration.year), years: ENV.fetch("YEARS", 5)).call
    puts "Demo data for #{result[:shops]} existing shops, years #{result[:years].join(', ')}"
    puts "Created: #{result[:created].inspect}"
    puts "Preserved: #{result[:preserved].inspect}"
    puts "All added payments are simulations (DEMO references). No emails sent or money moved."
  end
end
