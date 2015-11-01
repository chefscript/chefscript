require "./dsl/interval_task"
require "./dsl/apply_task"
require "./util/pair"
require "./dsl/task"
require "./util/checker"

class TaskGroupClass < TaskClass
    attr_accessor :taskgroupname, :starttime, :taskqueue

    @@taskgrouppool = Hash.new()

    def TaskGroupClass.taskgrouppool
        return @@taskgrouppool
    end

    def initialize(taskgroupname)
        @taskgroupname = taskgroupname
        @pretaskqueue = []
        @taskqueue = nil
    end

    #################################################################################
    # DSL 用メソッド
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
    # 登録フェーズに実行するメソッド定義
    #################################################################################
    def register()
    end

    #################################################################################
    # 検証フェーズに実行するメソッド定義
    #################################################################################
    def linking()
        @taskqueue = []

        $logger.debug("Linking... [#{@taskgroupname}] (taskgroup)")
        @pretaskqueue.each do |pair|
            $logger.debug("Linking... [#{pair.taskname}] (pair.classname)")
            var = nil
            if pair.classname == :recipe
                var = RecipeTaskClass.getInstance(pair.taskname)
            elsif pair.classname == :json
                var = JsonTaskClass.getInstance(pair.taskname)
            elsif pair.classname == :databag
                var = DatabagTaskClass.getInstance(pair.taskname)
            elsif pair.classname == :role
                var = RoleTaskClass.getInstance(pair.taskname)
            elsif pair.classname == :environment
                var = EnvironmentTaskClass.getInstance(pair.taskname)
            elsif pair.classname == :create
                var = CreateTaskClass.getInstance(pair.taskname)
            elsif pair.classname == :copy
                var = CopyTaskClass.getInstance(pair.taskname)
            elsif pair.classname == :interval
                var = IntervalTaskClass.getInstance(pair.taskname)
            elsif pair.classname == :apply
                var = ApplyTaskClass.getInstance(pair.taskname)
            end
            $logger.debug("Linked [#{pair.taskname}] (pair.classname)")

            @taskqueue.push(var)
        end
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

    #################################################################################
    # 適用フェーズに実行するメソッド定義
    #################################################################################
    def adapt()
        $logger.info("Adapting tasks...")
        @taskqueue.each do |task|
            $logger.info("Task name = #{task.taskname}")
            task.adapt()
        end
    end
end

def taskgroup(taskgroupname, &block)
    $logger.debug("Taskgroup will register [#{taskgroupname}]")
    var = TaskGroupClass.new(taskgroupname)
    var.instance_eval(&block)

# Taskgroup 名の重複チェック
    if TaskGroupClass.taskgrouppool.has_key?(taskgroupname)
        $logger.fatal("Already taskgroup name [#{taskgroupname}] is registered!")
    end
    TaskGroupClass.taskgrouppool[taskgroupname] = var

    var.register()
    $logger.debug("Taskgroup registered [#{taskgroupname}]")
end
