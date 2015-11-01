require "./dsl/task"
require "./util/webget"
require "./util/checker"
require "./thirdparty/proc_source"

require "json"
require "securerandom"

class EnvironmentTaskClass < TaskClass
    attr_accessor :id, :taskname, :environmentname, :sourceenvironmentname, :content, :time, :proc, :isDelete, :isLinked

    @@environmentpool = Hash.new()

    # Manage all of environment task
    def EnvironmentTaskClass.environmentpool
        return @@environmentpool
    end

    def initialize(taskname)
        @taskname = taskname
        @environmentname = taskname
        @time = 0
        @isDelete = false
        @isLinked = false
    end


    #################################################################################
    # DSL methods
    #################################################################################
    def name(environmentname)
        Checker.checkClass(environmentname, String)
        @environmentname = environmentname
    end

    def source_name(sourceenvironmentname)
        Checker.checkClass(sourceenvironmentname, String)
        @sourceenvironmentname = sourceenvironmentname
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
        if @sourceenvironmentname == nil
            @sourceenvironmentname = @environmentname
        end

        # Save task constitution to backend
        $backend.addEnvironmentTask(self, 0)
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

    def EnvironmentTaskClass.getInstance(taskname)
        var = @@environmentpool[taskname]
        if var == nil
            $logger.fatal("Cannnot find environment task [#{taskname}].")
        end
        var.linking()

        return var
    end

    def getJsonInfo()
        scheduled_list = JSON.parse("{}")

        scheduled_list["taskname"] = @taskname
        scheduled_list["name"] = @environmentname
        scheduled_list["source_name"] = @sourceenvironmentname
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
            cmd = "EDITOR=cat #{$config["knife_cmd"]} environment delete #{@environmentname} -y 2> /dev/null"
            system(cmd)

        else
            # Try to get on the web, but if failed, then get from ChefServer
            str = Webget.getStrFromURL(@sourceenvironmentname)
            unless str
                # Get from ChefServer
                cmd = "EDITOR=cat #{$config["knife_cmd"]} environment edit #{@sourceenvironmentname} 2> /dev/null | sed -e '$d'"
                str = `#{cmd}`
                $logger.debug("Done: #{cmd}")
                $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")

                if str == ""
                    $logger.warn("Environment [#{sourceenvironmentname}] is not exist.")

                    if @sourceenvironmentname != @environmentname
                        $logger.error("Source environment [#{sourceenvironmentname}] is added to ChefServer, but not configured!")
                    end

                    cmd = "EDITOR=cat #{$config["knife_cmd"]} environment create #{@sourceenvironmentname} 2> /dev/null | sed -e '$d'"
                    str = `#{cmd}`
                    $logger.debug("Done: #{cmd}")
                    $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")
                end
            end

            # Process of modifing codes
            full_content = JSON.parse(str)
            @content = full_content # ["raw_data"]
            @proc.call()

            # Convert to JSON format
            # full_content["raw_data"] = @content
            full_content["name"] = @environmentname
            result = JSON.pretty_generate(@content)

            # Write back to ChefServer
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}.json"
            File.write(tmpfilename, result)
            $logger.debug("Result is written to #{tmpfilename}")
            $logger.debug("Result: #{result.gsub(/\n/, '\\n')}")

            system("#{$config["knife_cmd"]} environment from file #{tmpfilename}")

            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end
        end

        $logger.info("adapted #{@taskname} successfully")

        # Interval process
        @time.adapt()
    end
end



def environment(taskname, &block)
    $logger.debug("Environment task will register [#{taskname}]")
    var = EnvironmentTaskClass.new(taskname)
    var.instance_eval(&block)

    # Duplication check of Task name
    if EnvironmentTaskClass.environmentpool.has_key?(taskname)
        $logger.fatal("Already environment task name [#{taskname}] is registered!")
    end
    EnvironmentTaskClass.environmentpool[taskname] = var

    var.register()
    $logger.debug("Environment task registered [#{taskname}]")
end
