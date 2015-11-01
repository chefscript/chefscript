require "./dsl/task"
require "./util/checker"
require "./thirdparty/proc_source"

class IntervalTaskClass < TaskClass
    attr_accessor :id, :taskname, :every, :proc, :time, :trials, :isLinked

    @@intervalpool = Hash.new()

    # Manage all of interval task
    def IntervalTaskClass.intervalpool
        return @@intervalpool
    end

    def initialize(taskname)
        @taskname = taskname
        @time = -1
        @isLinked = false
    end


    #################################################################################
    # DSL methods
    #################################################################################
    def every(every)
        Checker.checkClass(every, Fixnum)
        @every = every
    end

    def trials(trials)
        Checker.checkClass(trials, Fixnum)
        @trials = trials
    end

    def confirm(&block)
        @proc = Proc.new(&block)
    end


    #################################################################################
    # Running at register phase
    #################################################################################
    def register()
        # Save task constitution to backend
        $backend.addRecipeTask(self, 0)
    end


    #################################################################################
    # Running at linking phase
    #################################################################################
    def linking()
        if @isLinked
            return
        end

        # $logger.debug("Linking... [#{@time}] (interval)")
        # @time = IntervalTaskClass.getInstance(@time)
        @isLinked = true
        # $logger.debug("Linked [#{@time.name}] (interval)")
    end

    def getJsonInfo()
        scheduled_list = JSON.parse("{}")

        scheduled_list["taskname"] = @taskname
        scheduled_list["every"] = @every.to_s()
        scheduled_list["confirm"] = @proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"')
        scheduled_list["_time"] = @time.to_s()
        scheduled_list["trials"] = @trials.to_s()
        
        return JSON.pretty_generate(scheduled_list).gsub(/\\n/, "\n  ").gsub(/\"{/, "{").gsub(/}\"/, "}").gsub(/\\\"/, "\"")
    end

    def IntervalTaskClass.getInstance(taskname)
        # if taskname is Fixnum or String(Fixnum), then convert to Fixnum
        if taskname == taskname.to_i().to_s()
            taskname = taskname.to_i()
        end

        if taskname.class() == Fixnum
            if taskname == 0
                return @@nowait
            end
            var = IntervalTaskClass.new("Wait #{taskname} sec")
            var.setTime(taskname)
            var.linking()

            return var
        else
            var = @@intervalpool[taskname]
            if var == nil
                $logger.fatal("Cannnot find interval task [#{taskname}].")
            end
            var.linking()

            return var
        end
    end

    # This method is used at fix time interval task
    # For example, wait X seconds.
    def setTime(time)
        @time = time
    end


    #################################################################################
    # Running at adapt phase
    #################################################################################
    def adapt()
        $logger.info("Task #{@taskname} will adapt now")
        trial_counts = 0

        if @time == 0
            # no operation
        elsif @time < 0
            while true
                if trial_counts >= @trials
                    emsg = "Interval task [#{@taskname}] is failed #{@trials} times"
                    $logger.fatal(emsg)
                    abort(emsg)
                    break
                end
                if @proc.call()
                    $logger.debug("Confirm block is succeeded")
                    break
                end
                sleep(@every)
                $logger.debug("Sleep #{@every} sec every")

                # If failed counts is over than trial counts, then taskgroup is failed
                trial_counts += 1
            end
        else
            $logger.debug("Sleep #{@time} sec from now")
            sleep(@time)
        end

        $logger.info("adapted #{@taskname} successfully")
    end

    # Singleton instance for no wait (0 sec interval)
    @@nowait = IntervalTaskClass.new("No wait")
    @@nowait.setTime(0)
end



def interval(taskname, &block)
    $logger.debug("Interval task will register [#{taskname}]")
    var = IntervalTaskClass.new(taskname)
    var.instance_eval(&block)

    # Duplication check of Task name
    if IntervalTaskClass.intervalpool.has_key?(taskname)
        $logger.fatal("Already interval task name [#{taskname}] is registered!")
    end
    IntervalTaskClass.intervalpool[taskname] = var

    var.register()
    $logger.debug("Interval task registered [#{taskname}]")
end

