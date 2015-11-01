#################################################################################
# Monkey Patch
#################################################################################

# If fatal error is occured, then raise exception
class Logger
    alias :_fatal_ :fatal

    def fatal(str)
        _fatal_(str)
        raise(str)
    end

    private :_fatal_
end

# When execute system function, we are logging
module Kernel
    alias :_system_ :system

    def system(str)
        isSucceeded = _system_(str)
        if isSucceeded
            $logger.debug("Done: [" + str + "]")
        else
            $logger.warn("Fail: [" + str + "]")
        end

        return isSucceeded
    end

    private :_system_
end
