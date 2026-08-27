# Set PARTICIPATION_YEAR explicitly when opening renewal for the next event.
Rails.application.config.x.participation_year = ENV["PARTICIPATION_YEAR"].presence&.then { |year| Integer(year, 10) }
Rails.application.config.x.print_delivery_information = ENV["PRINT_DELIVERY_INFORMATION"].presence
