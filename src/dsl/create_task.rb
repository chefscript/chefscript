require "./dsl/task"
require "./util/file_array"
require "./util/webget"
require "./util/checker"
require "./thirdparty/proc_source"

require "securerandom"
require "json"

class CreateTaskClass < TaskClass
    attr_accessor :id, :taskname, :filename, :content, :cookbookname, :site, :sourcefilename, :time, :proc, :isDelete, :isLinked

    @@createpool = Hash.new()

    # Manage all of create task
    def CreateTaskClass.createpool
        return @@createpool
    end

    def initialize(taskname)
        @taskname = taskname
        @filename = taskname
        @site = ""
        @time = 0
        @isDelete = false
        @isLinked = false
    end


    #################################################################################
    # DSL methods
    #################################################################################
    def file(filename)
        Checker.checkClass(filename, String)
        @filename = filename
    end

    def cookbook(cookbookname)
        Checker.checkClass(cookbookname, String)
        @cookbookname = cookbookname
    end

    def isSite(tOrf)
        Checker.checkClasses(tOrf, TrueClass, FalseClass)
        if tOrf
            @site = "site-"
        else
            @site = ""
        end
    end

    def source_file(sourcefilename)
        Checker.checkClass(sourcefilename, String)
        @sourcefilename = sourcefilename
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
        if @sourcefilename == nil
            @sourcefilename = @filename
        end

        # Save task constitution to backend
        $backend.addCreateTask(self, 0)
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

    def CreateTaskClass.getInstance(taskname)
        var = @@createpool[taskname]
        if var == nil
            $logger.fatal("Cannnot find create task [#{taskname}].")
        end
        var.linking()

        return var
    end

    def getJsonInfo()
        scheduled_list = JSON.parse("{}")

        scheduled_list["taskname"] = @taskname
        scheduled_list["file"] = @filename
        scheduled_list["source_file"] = @sourcefilename
        scheduled_list["cookbook"] = @cookbookname
        scheduled_list["interval"] = @time.getJsonInfo()
        scheduled_list["modify"] = @proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"')
        scheduled_list["_isSite"] = @site
        scheduled_list["delete"] = @isDelete.to_s()

        return JSON.pretty_generate(scheduled_list).gsub(/\\n/, "\n  ").gsub(/\"{/, "{").gsub(/}\"/, "}").gsub(/\\\"/, "\"")
    end


    #################################################################################
    # Running at adapt phase
    #################################################################################
    def adapt()
        $logger.info("Task #{@taskname} will adapt now")

        if isDelete
            cmd = "rm #{$config['repodir']}/#{@site}cookbooks/#{cookbookname}/#{@filename} -f"
            system(cmd)

        else
            # Try to get on the web, but if failed, then get from localfile
            str = Webget.getStrFromURL(@sourcefilename)
            unless str
                readfile = "#{$config['repodir']}/#{@site}cookbooks/#{@cookbookname}/#{@sourcefilename}"
                begin
                    str = File.read(readfile)
                rescue Errno::ENOENT
                    $logger.error("Source file [#{readfile}] is not found! This task will configured from blank.")
                    str = ""
                end
            end

            # Process of modifing codes
            @content = FileArray.parse(str)
            @proc.call()

            # Convert to FileArry format
            result = FileArray.pretty_generate(@content)

            # Write back to file for uploading to ChefServer
            File.write("#{$config['repodir']}/#{@site}cookbooks/#{cookbookname}/#{@filename}", result)
        end

        # Upload process
        system("#{$config["knife_cmd"]} cookbook upload #{@cookbookname} -o #{$config['repodir']}/#{@site}cookbooks")

        $logger.info("adapted #{@taskname} successfully")

        # Interval process
        @time.adapt()
    end
end



def create(taskname, &block)
    $logger.debug("Create task will register [#{taskname}]")
    var = CreateTaskClass.new(taskname)
    var.instance_eval(&block)

    # Duplication check of Task name
    if CreateTaskClass.createpool.has_key?(taskname)
        $logger.fatal("Already create task name [#{taskname}] is registered!")
    end
    CreateTaskClass.createpool[taskname] = var

    var.register()
    $logger.debug("Create task registered [#{taskname}]")
end


