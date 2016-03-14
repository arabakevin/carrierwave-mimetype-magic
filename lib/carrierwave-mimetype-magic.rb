require "carrierwave-mimetype-magic/version"

module CarrierWave
  module MimetypeMagic
    extend ActiveSupport::Concern

    included do
      alias_method_chain :cache!, :mimetype_magic

      begin
        require 'mimemagic'
        require 'mimemagic/overlay'
      rescue LoadError => e
        e.message << ' (You may need to install the mimemagic gem)'
        raise e
      end
    end

    def cache_with_mimetype_magic!(new_file = sanitized_file)
      # Only step in on the initial file upload
      opened_file = case new_file
      when CarrierWave::Uploader::Download::RemoteFile  then new_file.send(:file)
      when ActionDispatch::Http::UploadedFile           then File.open(new_file.path)
      else nil
      end

      return cache_without_mimetype_magic!(new_file) unless opened_file


      begin
        # Collect information about the real content type
        real_content_type = MimeMagic.by_magic(opened_file).type
        valid_extensions  = Array(MIME::Types[real_content_type].try(:first).try(:extensions))

        # Set proper content type, and update filename if current name doesn't match reach content type
        new_file  = CarrierWave::SanitizedFile.new(new_file)
        new_file.content_type = real_content_type
        base, ext = new_file.send(:split_extension, new_file.original_filename)
        ext = valid_extensions.first unless valid_extensions.include?(ext)

        new_file.instance_variable_set '@original_filename', [base, ext].join('.')
      rescue StandardError => e
        Rails.logger.warn "[carrierwave-mimetype] Exception raised, not fixing image extension. #{e}"
      ensure
        cache_without_mimetype_magic!(new_file)
      end
    end
  end
end
