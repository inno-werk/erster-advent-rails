ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Opt into parallel workers on compatible hosts. The macOS Ruby/pg runtime
    # can crash while opening PostgreSQL connections after fork.
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 1).to_i)

    # The insurance fixtures are unused remnants from the original scaffold and
    # refer to tables that do not exist in this application.
    fixtures :users, :businesses, :print_products

    def participation_for(user = users(:member), category: "leist_member", year: EventConfiguration.year, paid: false)
      participation = user.participations.create!(year: year, category: category)
      participation.mark_paid! if paid
      participation
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def default_url_options
    { locale: nil }
  end
end
