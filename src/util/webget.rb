module Webget
    def Webget.getStrFromURL(url)
        if url =~ /^http|^ftp/
            # If source file is located on the Web, download and write to temp file
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}"

            unless system("wget #{url} -q -O #{tmpfilename}")
                $logger.error("Can not download #{url} as #{tmpfilename}")
            end

            # Read from temp file and return this contents
            result = WebGet.getStrFromFile(tmpfilename)

            # If this is production environment, delete this temp file
            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end

            return result
        else
            return false
        end
    end
end

