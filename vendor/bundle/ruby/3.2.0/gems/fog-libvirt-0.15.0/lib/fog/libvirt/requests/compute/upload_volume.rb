module Fog
  module Libvirt
    class Compute
      module Shared
        def upload_volume(pool_name, volume_name, file_path)
          volume = client.lookup_storage_pool_by_name(pool_name).lookup_volume_by_name(volume_name)
          stream = client.stream

          image_file = File.open(file_path, "rb")
          volume.upload(stream, 0, image_file.size)
          stream.sendall do |_opaque, n|
            begin
              r = image_file.read(n)
              r ? [r.length, r] : [0, ""]
            rescue Exception => e
              [-1, ""]
            end
          end
          stream.finish
        ensure
          image_file.close if image_file
        end
      end

      class Real
        include Shared
      end

      class Mock
        include Shared
      end
    end
  end
end
