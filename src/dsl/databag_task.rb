require "./dsl/task"
require "./util/webget"
require "./util/checker"
require "./thirdparty/proc_source"

require "json"
require "securerandom"

class DatabagTaskClass < TaskClass
    attr_accessor :id, :taskname, :bagname, :itemname, :sourcebagname, :sourceitemname, :content, :time, :proc, :isDelete, :isLinked

    @@databagpool = Hash.new()

    # Manage all of databag task
    def DatabagTaskClass.databagpool
        return @@databagpool
    end

    def initialize(taskname)
        @taskname = taskname
        @bagname = taskname
        @time = 0
        @isDelete = false
        @isLinked = false
    end


    #################################################################################
    # DSL methods
    #################################################################################
    def bag(bagname)
        Checker.checkClass(bagname, String)
        @bagname = bagname
    end

    def item(itemname)
        Checker.checkClass(itemname, String)
        @itemname = itemname
    end

    def source_bag(sourcebagname)
        Checker.checkClass(sourcebagname, String)
        @sourcebagname = sourcebagname
    end

    def source_item(sourceitemname)
        Checker.checkClass(sourceitemname, String)
        @sourceitemname = sourceitemname
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
        if @sourcebagname == nil
            @sourcebagname = @bagname
        end
        if @sourceitemname == nil
            @sourceitemname = @itemname
        end

        # Save task constitution to backend
        $backend.addDatabagTask(self, 0)
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

    def DatabagTaskClass.getInstance(taskname)
        var = @@databagpool[taskname]
        if var == nil
            $logger.fatal("Cannnot find databag task [#{taskname}].")
        end
        var.linking()

        return var
    end

    def getJsonInfo()
        scheduled_list = JSON.parse("{}")

        scheduled_list["taskname"] = @taskname
        scheduled_list["bag"] = @bagname
        scheduled_list["source_bag"] = @sourcebagname
        scheduled_list["item"] = @itemname
        scheduled_list["source_item"] = @sourceitemname
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
            cmd = "EDITOR=cat #{$config["knife_cmd"]} data bag delete #{@bagname} #{@itemname} -y 2> /dev/null"
            system(cmd)

        else
            # Try to get on the web, but if failed, then get from ChefServer
            str = Webget.getStrFromURL(@sourceitemname)
            unless str
                str = Webget.getStrFromURL(@sourcebagname)
            end

            isCreated = false
            unless str
                # Get from ChefServer
                cmd = "EDITOR=cat #{$config["knife_cmd"]} data bag edit #{@sourcebagname} #{@sourceitemname} 2> /dev/null | sed -e '$d'"
                str = `#{cmd}`
                $logger.debug("Done: #{cmd}")
                $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")

                if str == ""
                    isCreated = true
                    $logger.warn("Databag Item [#{@sourcebagname} / #{@sourceitemname}] is not exist.")

                    if @sourcebagname != @bagname || @sourceitemname != @itemname
                        $logger.error("Source databag item [#{@sourcebagname} / #{@sourceitemname}] is added to ChefServer, but not configured!")
                    end

                    cmd = "EDITOR=cat #{$config["knife_cmd"]} data bag create #{@sourcebagname} #{@sourceitemname} 2> /dev/null | sed -e '$d'"
                    str = `#{cmd}`
                    $logger.debug("Done: #{cmd}")
                    $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")
                end
            end

            # Process of modifing codes
            full_content = JSON.parse(str)
            if isCreated
                @content = full_content
            else
                @content = full_content["raw_data"]
            end
            @proc.call()

            # Convert to JSON format
            # full_content["raw_data"] = @content
            @content["id"] = @itemname
            result = JSON.pretty_generate(@content)

            # Write back to ChefServer
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}.json"
            File.write(tmpfilename, result)
            $logger.debug("Result is written to #{tmpfilename}")
            $logger.debug("Result: #{result.gsub(/\n/, '\\n')}")

            system("#{$config["knife_cmd"]} data bag create #{@bagname}")
            system("#{$config["knife_cmd"]} data bag from file #{@bagname} #{tmpfilename}")

            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end
        end

        $logger.info("adapted #{@taskname} successfully")

        # Interval process
        @time.adapt()
    end
end



def databag(taskname, &block)
    $logger.debug("Databag task will register [#{taskname}]")
    var = DatabagTaskClass.new(taskname)
    var.instance_eval(&block)

    # Duplication check of Task name
    if DatabagTaskClass.databagpool.has_key?(taskname)
        $logger.fatal("Already databag task name [#{taskname}] is registered!")
    end
    DatabagTaskClass.databagpool[taskname] = var

    var.register()
    $logger.debug("Databag task registered [#{taskname}]")
end
