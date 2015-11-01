module DSLUtils
    def DSLUtils.isSite(str)
        if str == ""
            return false
        elsif str == "site-"
            return true
        else
            $logger.fatal("Unknown 'isSite' entry is got from backend. [#{str}]")
        end
    end
end
