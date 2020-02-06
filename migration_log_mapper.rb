require 'csv'

class MigrationLogMapper
  attr_accessor :download_log_path, :local_images_path

  def initialize(download_log_path, local_images_path)
    self.download_log_path = download_log_path
    self.local_images_path = local_images_path
  end

  def for_each_entry
    CSV.open(self.download_log_path) do |csv|
      csv.each do |input_source_path, dest_folder|
        image_filename = File.basename(input_source_path)

        current_image_path = File.join(dest_folder, image_filename)

        relative_image_folder = dest_folder.gsub(/^#{self.local_images_path}/, "")

        year = Integer(relative_image_folder[0..3])

        result = {
          source: input_source_path,
          relative_image_folder: relative_image_folder,
          folder: year
        }

        yield result
      end
    end
  end
end
