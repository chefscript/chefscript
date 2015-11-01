require "./dsl/task"
require "./util/checker"

class IntervalTaskClass < TaskClass
    attr_accessor :taskname, :every, :proc, :time, :trials

    def initialize(taskname)
        @taskname = taskname
        @time = -1
    end

    @@intervalpool = Hash.new()

    def IntervalTaskClass.intervalpool
        return @@intervalpool
    end

    #################################################################################
    # DSL 用メソッド
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
    # 登録フェーズに実行するメソッド定義
    #################################################################################
    def register()
    end

    #################################################################################
    # 検証フェーズに実行するメソッド定義
    #################################################################################
    def linking()
        # $logger.debug("Linking... [#{@time}] (interval)")
        # @time = IntervalTaskClass.getInstance(@time)
        # $logger.debug("Linked [#{@time.name}] (interval)")
    end

    def IntervalTaskClass.getInstance(taskname)
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

    def setTime(time)
        @time = time
    end

    #################################################################################
    # 適用フェーズに実行するメソッド定義
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
                trial_counts += 1
            end
        else
            $logger.debug("Sleep #{@time} sec from now")
            sleep(@time)
        end

        $logger.info("adapted #{@taskname} successfully")
    end

    # No wait 用インスタンス
    @@nowait = IntervalTaskClass.new("No wait")
    @@nowait.setTime(0)
end

def interval(taskname, &block)
    $logger.debug("Interval task will register [#{taskname}]")
    var = IntervalTaskClass.new(taskname)
    var.instance_eval(&block)

    # Task 名の重複チェック
    if IntervalTaskClass.intervalpool.has_key?(taskname)
        $logger.fatal("Already interval task name [#{taskname}] is registered!")
    end
    IntervalTaskClass.intervalpool[taskname] = var

    var.register()
    $logger.debug("Interval task registered [#{taskname}]")
end

