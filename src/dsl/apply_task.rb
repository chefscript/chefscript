require "./dsl/task"
require "./util/webget"
require "./util/checker"
require "./thirdparty/proc_source"

require "securerandom"
require "json"

class ApplyTaskClass < TaskClass
    attr_accessor :taskname, :nodename, :isLinked

    @@Applypool = Hash.new()

    # Manage all of apply task
    def ApplyTaskClass.Applypool
        return @@Applypool
    end

    def initialize(nodename)
        @taskname = "Apply codes to #{nodename}"
        @nodename = nodename
        @isLinked = false
    end

    #################################################################################
    # Running at register phase
    #################################################################################
    def register()
        # $backend.addApplyTask(self, 0)
    end

    #################################################################################
    # Running at linking phase
    #################################################################################
    def linking()
        if @isLinked
            return
        end

        @isLinked = true
    end

    def ApplyTaskClass.getInstance(nodename)
        var = nil
        if ApplyTaskClass.Applypool.has_key?(nodename)
            var = @@Applypool[nodename]
        else
            var = ApplyTaskClass.new(nodename)
            @@Applypool[nodename] = var
        end

        return var
    end

    def getJsonInfo()
        scheduled_list = JSON.parse("{}")

        scheduled_list["taskname"] = @taskname
        scheduled_list["_nodename"] = @nodename
        
        return JSON.pretty_generate(scheduled_list).gsub(/\\n/, "\n  ").gsub(/\"{/, "{").gsub(/}\"/, "}").gsub(/\\\"/, "\"")
    end

    #################################################################################
    # Running at adapt phase
    #################################################################################
    def adapt()
        $logger.info("Apply codes to node [#{@nodename}] will adapt now")

        cmd = "#{$config["knife_cmd"]} job start chef-client #{@nodename} 2> /dev/null"
        str = `#{cmd}`
        $logger.debug("Done: #{cmd}")
        $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")
        $logger.info("Applied codes to node [#{@nodename}] successfully")
    end

end
