require 'dotenv'

$LOAD_PATH << "."

require 'migration_log_mapper'
require 'smugmug_adapter'
require 'smugmug_auth'

Dotenv.load

LOCAL_IMAGES_PATH = "/data/user_data/My Pictures/"

class UploadToSmugmug
  attr_accessor :smugmug_adapter, :input_path, :dry_run

  def initialize(input_path, dry_run)
    smugmug_api_host = "https://www.smugmug.com"

    public_galleries_host = ENV.fetch("PUBLIC_GALLERIES_HOSTNAME")
    self.smugmug_adapter = SmugmugAdapter.new(auth, smugmug_api_host, public_galleries_host)
    self.input_path = input_path
    self.dry_run = dry_run
  end

  def main
    migration_log_mapper = MigrationLogMapper.new(input_path, LOCAL_IMAGES_PATH)

    access_token = smugmug_adapter.access_token

    file_uploader = FileUploader.new(access_token)

    upload_log_path = "./migrated_#{File.basename(input_path)}"
    CSV.open(upload_log_path, "w") do |csv|
      file_uploader.with_session do |session|
        migration_log_mapper.for_each_entry do |entry|
          upload_entry(entry, session, csv)
        end
      end
    end
  end


  # TODO: Fix upload to wrong path
  private

  def upload_entry(entry, session, csv)
    source, relative_image_folder, folder = entry.values_at(:source, :relative_image_folder, :folder)

    album = smugmug_adapter.album_with_name(relative_image_folder)

    if contains_image?(album, source)
      csv << [entry[:source], "", "", "Already exists"]

      return
    end

    album_uri = album["Uri"]

    puts "Uploading #{source} to #{album_uri}"

    session.upload(source, album_uri) unless dry_run

    csv << [entry[:source], relative_image_folder, album_uri, "OK"]
  rescue StandardError => e
    csv << [entry[:source], "", "", "ERROR: message '#{e.message}'"]
    puts "Error: #{entry.inspect} => #{e.message}"
    puts e.backtrace

    raise
  end

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

dry_run = ARGV.include?("--dry-run")

input_path = ARGV[-1]

if input_path.nil?
  puts "Please specify input filename"
  exit 1
end

if !File.exist?(input_path)
  puts "Files #{input_path} cannot be read!"
  exit 2
end

if dry_run
  puts "Dry run, no files will be copied (other API calls will be made)"
end

UploadToSmugmug.new(input_path, dry_run).main
