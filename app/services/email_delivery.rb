class EmailDelivery
  def self.enabled?
    ENV["PROD_SEND"] == "true"
  end
end
