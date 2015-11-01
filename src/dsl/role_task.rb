require "./dsl/task"
require "./util/webget"
require "./util/checker"
require "./thirdparty/proc_source"

require "json"
require "securerandom"

class RoleTaskClass < TaskClass
    attr_accessor :id, :taskname, :rolename, :sourcerolename, :content, :time, :proc, :isDelete, :isLinked, :isLinked

    @@rolepool = Hash.new()

    # Manage all of role task
    def RoleTaskClass.rolepool
        return @@rolepool
    end

    def initialize(taskname)
        @taskname = taskname
        @rolename = taskname
        @time = 0
        @isDelete = false
        @isLinked = false
    end


    #################################################################################
    # DSL methods
    #################################################################################
    def name(rolename)
        Checker.checkClass(rolename, String)
        @rolename = rolename
    end

    def source_name(sourcerolename)
        Checker.checkClass(sourcerolename, String)
        @sourcerolename = sourcerolename
    end

    def interval(time)
        Checker.checkClass(time, String)
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
        if @sourcerolename == nil
            @sourcerolename = @rolename
        end

        # Save task constitution to backend
        $backend.addRoleTask(self, 0)
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

    def RoleTaskClass.getInstance(taskname)
        var = @@rolepool[taskname]
        if var == nil
            $logger.fatal("Cannnot find role task [#{taskname}].")
        end
        var.linking()

        return var
    end

    def getJsonInfo()
        scheduled_list = JSON.parse("{}")

        scheduled_list["taskname"] = @taskname
        scheduled_list["name"] = @rolename
        scheduled_list["source_name"] = @sourcerolename
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
            cmd = "EDITOR=cat #{$config["knife_cmd"]} role delete #{@rolename} -y 2> /dev/null"
            system(cmd)

        else
            # Try to get on the web, but if failed, then get from ChefServer
            str = Webget.getStrFromURL(@sourcerolename)
            unless str
                # Get from ChefServer
                cmd = "EDITOR=cat #{$config["knife_cmd"]} role edit #{@sourcerolename} 2> /dev/null | sed -e '$d'"
                str = `#{cmd}`
                $logger.debug("Done: #{cmd}")
                $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")

                if str == ""
                    $logger.warn("Role [#{sourcerolename}] is not exist.")

                    if @sourcerolename != @rolename
                        $logger.error("Source role [#{sourcerolename}] is added to ChefServer, but not configured!")
                    end

                    cmd = "EDITOR=cat #{$config["knife_cmd"]} role create #{@sourcerolename} 2> /dev/null | sed -e '$d'"
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
            full_content["name"] = @rolename
            result = JSON.pretty_generate(@content)

            # Write back to ChefServer
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}.json"
            File.write(tmpfilename, result)
            $logger.debug("Result is written to #{tmpfilename}")
            $logger.debug("Result: #{result.gsub(/\n/, '\\n')}")

            system("#{$config["knife_cmd"]} role from file #{tmpfilename}")

            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end
        end

        $logger.info("adapted #{@taskname} successfully")

        # Interval process
        @time.adapt()
    end
end



def role(taskname, &block)
    $logger.debug("Role task will register [#{taskname}]")
    var = RoleTaskClass.new(taskname)
    var.instance_eval(&block)

    # Duplication check of Task name
    if RoleTaskClass.rolepool.has_key?(taskname)
        $logger.fatal("Already role task name [#{taskname}] is registered!")
    end
    RoleTaskClass.rolepool[taskname] = var

    var.register()
    $logger.debug("Role task registered [#{taskname}]")
end
