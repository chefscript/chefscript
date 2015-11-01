require "./dsl/interval_task"
require "./dsl/apply_task"
require "./util/pair"
require "./dsl/task"
require "./util/checker"

class TaskGroupClass < TaskClass
    attr_accessor :id, :taskgroupname, :starttime, :taskqueue, :thread, :state, :pretaskqueue, :isLinked

    @@taskgrouppool = Hash.new()

    # Manage all of taskgroup
    def TaskGroupClass.taskgrouppool
        return @@taskgrouppool
    end

    def initialize(taskgroupname)
        @taskgroupname = taskgroupname
        @pretaskqueue = []
        @taskqueue = nil
        @thread = nil
        @state = 0 # 0:pending, 1:running, 2:done
        @isLinked = false
    end


    #################################################################################
    # DSL methods
    #################################################################################
    def starts(starttime)
        if @starttime.class() == Time
            $logger.warn("Start time is already registerd for taskgroup [#{@taskgroupname}]")
        end
        Checker.checkClass(starttime, String)
        @starttime = Time.parse(starttime)
    end

    def recipe(recipename)
        Checker.checkClass(recipename, String)
        @pretaskqueue.push(Pair.new(:recipe, recipename))
    end

    def json(jsonname)
        Checker.checkClass(jsonname, String)
        @pretaskqueue.push(Pair.new(:json, jsonname))
    end

    def databag(databagname)
        Checker.checkClass(databagname, String)
        @pretaskqueue.push(Pair.new(:databag, databagname))
    end

    def role(rolename)
        Checker.checkClass(rolename, String)
        @pretaskqueue.push(Pair.new(:role, rolename))
    end

    def environment(environmentname)
        Checker.checkClass(environmentname, String)
        @pretaskqueue.push(Pair.new(:environment, environmentname))
    end

    def create(createname)
        Checker.checkClass(createname, String)
        @pretaskqueue.push(Pair.new(:create, createname))
    end

    def copy(copyname)
        Checker.checkClass(copyname, String)
        @pretaskqueue.push(Pair.new(:copy, copyname))
    end

    def interval(intervalname)
        Checker.checkClasses(intervalname, String, Fixnum)
        @pretaskqueue.push(Pair.new(:interval, intervalname))
    end

    def apply(nodename)
        Checker.checkClass(nodename, String)
        @pretaskqueue.push(Pair.new(:apply, nodename))
    end


    #################################################################################
    # Running at register phase
    #################################################################################
    def register()
        # Save taskgroup constitution to backend
        $backend.addTaskGroup(self, 0)
    end

    # Set status (This method is called by backend class at loading task object from backend)
    def setState(state)
        @state = state
    end

    def setCurrentOrder(currentorder)
        if currentorder < 1
            return
        end

        # Set "isCompleted" flags of tasks related this taskgroup.
        for i in 0..(currentorder - 1) do
            taskqueue[i].right = true
        end
    end

    #################################################################################
    # Running at linking phase
    #################################################################################
    def linking()
        if @isLinked
            return
        end

        # Move from preloaded taskqueue (pretaskqueue) to taskqueue for unlimited order loading DSL files
        @taskqueue = []

        $logger.debug("Linking... [#{@taskgroupname}] (taskgroup)")
        @pretaskqueue.each do |pair|
            $logger.debug("Linking... [#{pair.right}] (pair.left)")
            var = nil
            if pair.left == :recipe
                var = RecipeTaskClass.getInstance(pair.right)
            elsif pair.left == :json
                var = JsonTaskClass.getInstance(pair.right)
            elsif pair.left == :databag
                var = DatabagTaskClass.getInstance(pair.right)
            elsif pair.left == :role
                var = RoleTaskClass.getInstance(pair.right)
            elsif pair.left == :environment
                var = EnvironmentTaskClass.getInstance(pair.right)
            elsif pair.left == :create
                var = CreateTaskClass.getInstance(pair.right)
            elsif pair.left == :interval
                var = IntervalTaskClass.getInstance(pair.right)
            elsif pair.left == :apply
                var = ApplyTaskClass.getInstance(pair.right)
            end
            $logger.debug("Linked [#{pair.right}] (pair.left)")

            # Manage each task and executed_flag as pair
            @taskqueue.push(Pair.new(var, false))
        end

        @isLinked = true
        $logger.debug("Linked [#{@taskgroupname}] (taskgroup)")
    end

    def TaskGroupClass.getInstance(taskgroupname)
        var = @@taskgrouppool[taskgroupname]
        if var == nil
            $logger.fatal("Cannnot find taskgroup [#{taskgroupname}].")
        end
        var.linking()

        return var
    end

    def getJsonInfo()
    end


    #################################################################################
    # Running at adapt phase
    #################################################################################
    def setThread(thread)
        @thread = thread
    end

    def adapt()
        # Set state from pending to running
        @state = 1
        $backend.setTaskgroupStatus(taskgroupname, 1)

        $logger.info("Adapting tasks...")

        order = 0
        @taskqueue.each do |pair|
            $logger.info("Task name = #{task.taskname}")

            # If this task is already done, then skip this task.
            # (this process is only run when restart ChefScript or force stop)
            if pair.right
                $logger.info("#{task.taskname} is already adapted, so skipping...")
                order = order + 1
                next
            end

            # Adapt a task (a part of taskgroup)
            pair.left.adapt()
            pair.right = true

            # Save checkpoint (a task is completed)
            $backend.updateProceed(@taskgroupname, order)
            order = order + 1
        end
        
        # Set state from running to done
        @state = 2
        $backend.setTaskgroupStatus(taskgroupname, 2)
    end
end



def taskgroup(taskgroupname, &block)
    $logger.debug("Taskgroup will register [#{taskgroupname}]")
    var = TaskGroupClass.new(taskgroupname)
    var.instance_eval(&block)

    # Duplication check of Task name
    if TaskGroupClass.taskgrouppool.has_key?(taskgroupname)
        $logger.fatal("Already taskgroup name [#{taskgroupname}] is registered!")
    end
    TaskGroupClass.taskgrouppool[taskgroupname] = var

    var.register()
    $logger.debug("Taskgroup registered [#{taskgroupname}]")
end
