require "./dsl/task"
require "./util/webget"
require "./util/checker"
require "./thirdparty/proc_source"

require "json"
require "securerandom"

class JsonTaskClass < TaskClass
    attr_accessor :id, :taskname, :nodename, :sourcenodename, :content, :time, :proc, :isDelete, :isLinked

    @@jsonpool = Hash.new()

    # Manage all of json task
    def JsonTaskClass.jsonpool
        return @@jsonpool
    end

    def initialize(taskname)
        @taskname = taskname
        @nodename = taskname
        @time = 0
        @isDelete = false
        @isLinked = false
    end


    #################################################################################
    # DSL methods
    #################################################################################
    def node(nodename)
        Checker.checkClass(nodename, String)
        @nodename = nodename
    end

    def source_node(sourcenodename)
        Checker.checkClass(sourcenodename, String)
        @sourcenodename = sourcenodename
    end

    def interval(time)
        Checker.checkClasses(time, String, Fixnum)
        @time = time.to_s()
    end

    def modify(&block)
        @proc = Proc.new(&block)
    end

    def delete(tOrf)
        Checker.checkClasses(tOrf, TrueClass, FalseClass)
        @isDelete = tOrf
    end


    #################################################################################
    # Running at register phase
    #################################################################################
    def register()
        if @sourcenodename == nil
            @sourcenodename = @nodename
        end

        # Save task constitution to backend
        $backend.addJsonTask(self, 0)
    end


    #################################################################################
    # Running at linking phase
    #################################################################################
    def linking()
        if @isLinked
            return
        end

        $logger.debug("Linking... [#{@time}] (interval)")
        @time = IntervalTaskClass.getInstance(@time)
        @isLinked = true
        $logger.debug("Linked [#{@time.taskname}] (interval)")
    end

    def JsonTaskClass.getInstance(taskname)
        var = @@jsonpool[taskname]
        if var == nil
            $logger.fatal("Cannnot find json task [#{taskname}].")
        end
        var.linking()

        return var
    end

    def getJsonInfo()
        scheduled_list = JSON.parse("{}")

        scheduled_list["taskname"] = @taskname
        scheduled_list["node"] = @nodename
        scheduled_list["source_node"] = @sourcenodename
        scheduled_list["interval"] = @time.getJsonInfo()
        scheduled_list["modify"] = @proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"')
        scheduled_list["delete"] = @isDelete.to_s()
        
        return JSON.pretty_generate(scheduled_list).gsub(/\\n/, "\n  ").gsub(/\"{/, "{").gsub(/}\"/, "}").gsub(/\\\"/, "\"")
    end


    #################################################################################
    # Running at adapt phase
    #################################################################################
    def adapt()
        $logger.info("Task #{@taskname} will adapt now")

        if isDelete
            cmd = "EDITOR=cat #{$config["knife_cmd"]} node delete #{@nodename} 2> /dev/null"
            system(cmd)

        else
            # Try to get on the web, but if failed, then get from ChefServer
            str = Webget.getStrFromURL(@sourcenodename)
            unless str
                # Get from ChefServer
                cmd = "EDITOR=cat #{$config["knife_cmd"]} node edit #{@sourcenodename} 2> /dev/null"
                str = `#{cmd}`
                $logger.debug("Done: #{cmd}")
                $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")

                if str == ""
                    $logger.warn("Node [#{sourcenodename}] is not exist.")

                    if @sourcenodename != @nodename
                        $logger.error("Source node [#{sourcenodename}] is added to ChefServer, but not configured!")
                    end

                    cmd = "EDITOR=cat #{$config["knife_cmd"]} node create #{@sourcenodename} 2> /dev/null | sed -e '$d'"
                    str = `#{cmd}`
                    $logger.debug("Done: #{cmd}")
                    $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")
                end
            end

            # Process of modifing codes
            full_content = JSON.parse(str)
            @content = full_content # ["normal"]
            @proc.call()

            # Convert to JSON format
            # full_content["normal"] = @content
            @content["name"] = @nodename
            result = JSON.pretty_generate(@content)

            # Write back to ChefServer
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}.json"
            File.write(tmpfilename, result)
            $logger.debug("Result is written to #{tmpfilename}")
            $logger.debug("Result: #{result.gsub(/\n/, '\\n')}")

            system("#{$config["knife_cmd"]} node from file #{tmpfilename}")

            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end
        end

        $logger.info("adapted #{@taskname} successfully")

        # Interval process
        @time.adapt()
    end
end



def json(taskname, &block)
    $logger.debug("Json task will register [#{taskname}]")
    var = JsonTaskClass.new(taskname)
    var.instance_eval(&block)

    # Duplication check of Task name
    if JsonTaskClass.jsonpool.has_key?(taskname)
        $logger.fatal("Already json task name [#{taskname}] is registered!")
    end
    JsonTaskClass.jsonpool[taskname] = var

    var.register()
    $logger.debug("Json task registered [#{taskname}]")
end
