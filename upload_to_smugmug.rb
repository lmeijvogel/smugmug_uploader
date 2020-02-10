require 'dotenv'
require 'optparse'

$LOAD_PATH << "."

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
      puts "Checking folder: #{folder_to_upload}"

      folder_in_smugmug = File.basename(folder_to_upload)

      local_files = Dir.glob(File.join(folder_to_upload, "*.{jpg,JPG,mp4,mv}")).map { |file| File.basename(file) }

      # The year folder will be prepended by the adapter
      album = smugmug_adapter.fetch_album_with_name(folder_in_smugmug)

      if album
        images_on_smugmug = smugmug_adapter.images_for_album(album)

        images_not_on_smugmug = local_files - images_on_smugmug

        puts images_not_on_smugmug
      else
        puts "Album is not on smugmug yet"
      end
    end

    exit
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
exit
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
