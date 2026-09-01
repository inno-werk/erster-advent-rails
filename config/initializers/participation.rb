# Set PARTICIPATION_YEAR explicitly when opening renewal for the next event.
Rails.application.config.x.participation_year = ENV["PARTICIPATION_YEAR"].presence&.then { |year| Integer(year, 10) }
