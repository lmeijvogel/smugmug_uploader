require 'oauth'
require 'httparty'

require 'json'

require 'file_uploader'

class SmugmugAdapter
  include HTTParty

  attr_accessor :auth
  attr_accessor :public_galleries_hostname
  attr_accessor :smugmug_api_host

  def initialize(auth, smugmug_api_host, public_galleries_hostname)
    self.auth = auth

    self.smugmug_api_host = smugmug_api_host
    self.public_galleries_hostname = public_galleries_hostname
  end

  def access_token
    # The access token key and secret are retrieved from the
    # SmugMug UI -> Account Settings -> Privacy -> Authorized Services
    #
    # (click on "TOKEN")
    @_access_token ||= begin
                         consumer = OAuth::Consumer.new(
                           auth[:api_key],
                           auth[:api_secret],
                           site: smugmug_api_host
                         )

                         OAuth::AccessToken.new(
                           consumer,
                           self.auth[:api_access_token],
                           self.auth[:api_access_token_secret]
                         )
                       end
  end

  def fetch_album_with_name(album_name)
    folder = Integer(album_name[0..3])
    album_name_with_hyphens = album_name.gsub(/ /, "-").gsub(/[^A-Za-z0-9\-]/, "")

    album_uri = "https://#{public_galleries_hostname}/#{folder}/#{album_name_with_hyphens}"

    query = "/api/v2!weburilookup?WebUri=#{CGI.escape(album_uri)}"

    response = get(query).body

    JSON.parse(response).dig("Response", "Album")
  end

  def create_album_with_name(album_name)
    folder = Integer(album_name[0..3])
    album_name_with_hyphens = album_name.gsub(/ /, "-").gsub(/[^A-Za-z0-9\-]/, "")

    folder_uri = "https://#{public_galleries_hostname}/#{folder}"
    folder_query = "/api/v2!weburilookup?WebUri=#{CGI.escape(folder_uri)}"
    folder_response = get(folder_query)
    folder_json = JSON.parse(folder_response.body)

    folder_albums_uri = folder_json.dig("Response", "Folder", "Uris", "FolderAlbums", "Uri")

    album_response = post(folder_albums_uri,
                    "Name" => album_name,
                    "UrlName" => album_name_with_hyphens
                   )

    JSON.parse(album_response.body).dig("Response", "Album")
  end

  def images_for_album(album)
    album_images_uri = album.dig("Uris", "AlbumImages", "Uri")

    response = get(album_images_uri).body

    # Ensure it is an array to handle empty albums
    album_images = Array(JSON.parse(response).dig("Response", "AlbumImage"))

    while next_page_url = JSON.parse(response).dig("Response", "Pages", "NextPage")
      response = get(next_page_url).body

      album_images += Array(JSON.parse(response).dig("Response", "AlbumImage"))
    end

    album_images.map { |image| image["FileName"] }
  end

  private

  def get(path)
    access_token.get(path, {
      "Accept" => "application/json"
    })
  rescue StandardError => e
    puts "Error while getting '#{path}'"
    puts "Error: #{e.message}"

    raise
  end

  def post(path, data)
    headers = {
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }

    access_token.post(path, data.to_json, headers)
  rescue StandardError => e
    puts "Error while posting '#{path}'"
    puts "Error: #{e.message}"

    raise
  end
end
