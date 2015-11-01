module Webget
    def Webget.getStrFromURL(url)
        if url =~ /^http|^ftp/
            # ソースファイルが Web 上にある場合ダウンロード
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}"

            unless system("wget #{url} -q -O #{tmpfilename}")
                $logger.error("Can not download #{url} as #{tmpfilename}")
            end

            result = WebGet.getStrFromFile(tmpfilename)

            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end

            return result
        else
            return false
        end
    end
end

