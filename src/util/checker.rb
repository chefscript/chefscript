# Check class type of attr
# checkClass() is matching for 1 class
# checkClasses() is matching for 2 classes
module Checker
    def Checker.checkClass(attr, classAttr)
        if attr.class() != classAttr
            emsg = "Class type of [#{attr}] is not mached for [#{classAttr}]"
            $logger.fatal(emsg)
            abort(emsg)
        end
    end

    def Checker.checkClasses(attr, classAttr1, classAttr2)
        if attr.class() != classAttr1 && attr.class() != classAttr2
            emsg = "Class type of [#{attr}] is not mached for [#{classAttr1} | #{classAttr2}]"
            $logger.fatal(emsg)
            abort(emsg)
        end
    end
end

