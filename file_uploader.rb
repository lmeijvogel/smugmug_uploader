require 'net/http/post/multipart'
require 'oauth'

class FileUploader
  attr_accessor :host, :access_token

  def initialize(access_token)
    @host = "upload.smugmug.com"

    @access_token = access_token
  end

  def with_session(&block)
    session = UploadSession.new(@host, access_token)
    begin
      session.start

      yield session
    ensure
      session.close
    end
  end
end

class UploadSession
  def initialize(host, access_token)
    @host = host
    @access_token = access_token

    @http = Net::HTTP.new(host, 443)
    @http.use_ssl = true
  end

  def start
    @http.start
  end

  def upload(local_path, remote_album_uri)
    File.open(local_path) do |image|
      request = Net::HTTP::Post::Multipart.new("/",
                                           'text' => 'hi, there',
                                           'image' => UploadIO.new(image, "image/jpeg", File.basename(local_path)))

      request["X-Smug-AlbumUri"] = remote_album_uri
      request["X-Smug-ResponseType"] = "JSON"
      request["X-Smug-Version"] = "v2"
      sign(request)

      @http.request(request)
    end
  end

  def close
    @http.finish if @http.started?
  end

  private

  # I could not get the signing process to work with oauth's AccessToken#sign!:
  # Authentication failed with a 401.
  def sign(request)
    oauth_params = { consumer: @access_token.consumer, token: @access_token }

    oauth_helper = OAuth::Client::Helper.new(request, oauth_params.merge(:request_uri => URI("https://#{@host}")))

    request["Authorization"] = oauth_helper.header
  end
end
