require 'oauth'
require 'httparty'

require 'dotenv'

Dotenv.load

class Getter
  include HTTParty

  def stuff
    path = "/api/v2!authuser"
    site = "https://www.smugmug.com"

    consumer = OAuth::Consumer.new(
      ENV.fetch("API_KEY"),
      ENV.fetch("API_SECRET"),
      site: site)

    # The access token key and secret are retrieved from the
    # SmugMug UI -> Account Settings -> Privacy -> Authorized Services
    #
    # (click on "TOKEN")
    access_token = OAuth::AccessToken.new(
      consumer,
      ENV.fetch("API_ACCESS_TOKEN"),
      ENV.fetch("API_ACCESS_TOKEN_SECRET")
    )

    response = access_token.request(:get, path, {
      "Accept" => "application/json"
    })

    puts response.body
  end
end

Getter.new.stuff
