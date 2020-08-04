require 'bundler'

Bundler.load

require 'dotenv'
require 'optparse'

$LOAD_PATH << "lib"

require 'migration_log_mapper'
require 'smugmug_adapter'
require 'smugmug_auth'

Dotenv.load

LOCAL_IMAGES_PATH = "/data/user_data/My Pictures/"

class UploadToSmugmug
  attr_accessor :smugmug_adapter, :dry_run

  def initialize(dry_run)
    smugmug_api_host = "https://www.smugmug.com"

    public_galleries_host = ENV.fetch("PUBLIC_GALLERIES_HOSTNAME")

    self.smugmug_adapter = SmugmugAdapter.new(auth, smugmug_api_host, public_galleries_host)
    self.dry_run = dry_run
  end

  def main(input_dirs)
    input_dirs.each do |folder_to_upload|
      upload_dir_if_necessary(folder_to_upload)
    end
  end


  private

  def upload_dir_if_necessary(folder_to_upload)
    album = find_or_create_album(folder_to_upload)

    return if !album

    images_not_on_smugmug = find_new_images(folder_to_upload, album)

    return if images_not_on_smugmug.none?

    puts "New images to be uploaded:"
    images_not_on_smugmug.each do |name|
      puts "- #{File.basename(name)}"
    end

    should_upload = ask("Upload? [yN]", default: false)

    if should_upload
      upload_images(images_not_on_smugmug, album)
    end
  end

  def find_or_create_album(folder_to_upload)
    puts "Checking folder: #{folder_to_upload}"

    folder_in_smugmug = File.basename(folder_to_upload)

    # The year folder will be prepended by the adapter
    album = smugmug_adapter.fetch_album_with_name(folder_in_smugmug)

    return album if album

    puts "Album #{folder_to_upload} is not on smugmug yet"
    should_create = ask "Create it?", default: false

    if should_create
      smugmug_adapter.create_album_with_name(folder_in_smugmug)
    else
      nil
    end
  end

  def find_new_images(folder_to_upload, album)
    images_on_smugmug = smugmug_adapter.images_for_album(album)

    local_files = Dir.glob(File.join(folder_to_upload, "*.{jpg,JPG,mp4,mv}"))

    local_files.reject do |local_file|
      images_on_smugmug.include?(File.basename(local_file))
    end
  end

  def upload_images(images, album)
    access_token = smugmug_adapter.access_token

    file_uploader = FileUploader.new(access_token)

    file_uploader.with_session do |session|
      images.each do |image|
        upload_file(image, album, session)
      end
    end
  end

  def upload_file(image_path, album, session)
    album_uri = album["Uri"]

    puts "Uploading #{image_path} to #{album_uri}"

    session.upload(image_path, album_uri) unless dry_run
  rescue StandardError => e
    puts "Error: #{image_path.inspect} => #{e.message}"
    puts e.backtrace

    raise
  end

  def ask(question, default:)
    STDOUT.write("#{question}: ")
    input = STDIN.gets
    input.strip!

    if default == true # More readable than just 'if default'
      input.downcase !~ /n/
    else
      input.downcase =~ /y/
    end
  end

  public :ask

  def contains_image?(album, source)
    basename = File.basename(source)

    images_for_album(album).include? basename
  end

  def images_for_album(album)
    @images_for_album ||= Hash.new do |hash, key|
      hash[key] = smugmug_adapter.images_for_album(key)
    end

    @images_for_album[album]
  end

  def auth
    SmugmugAuth.from_env(ENV)
  end
end

options = {}

option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options] dir_glob"
  opts.on "--dry-run", "Do not actually upload files" do options[:dry_run] = true end
  opts.on "--help", "-h", "Print this text" do
    puts opts
    exit 0
  end
end.parse!

input_dirs = ARGV

UploadToSmugmug.new(options[:dry_run]).main(input_dirs)
