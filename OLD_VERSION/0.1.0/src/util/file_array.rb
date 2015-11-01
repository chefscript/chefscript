module FileArray
    def FileArray.parse(str)
        splitedStr = str.split("\n")

        $logger.debug("Before: #{str.gsub(/\n/, '\\n')}")
        $logger.debug("Total lines at before = #{splitedStr.size()}")

        return splitedStr
    end

    def FileArray.pretty_generate(splitedStr)
        result = ""
        splitedStr.each do |str|
            result += str + "\n"
        end

        $logger.debug("After: #{result.gsub(/\n/, '\\n')}")
        $logger.debug("Total lines at after = #{splitedStr.size()}")

        return result
    end
end
