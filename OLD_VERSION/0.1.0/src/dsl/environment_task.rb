require "./dsl/task"
require "./util/webget"
require "./util/checker"

require "json"
require "securerandom"

class EnvironmentTaskClass < TaskClass
    attr_accessor :taskname, :environmentname, :sourceenvironmentname, :content, :time, :proc, :isDelete

    @@environmentpool = Hash.new()

    def EnvironmentTaskClass.environmentpool
        return @@environmentpool
    end

    def initialize(taskname)
        @taskname = taskname
        @environmentname = taskname
        @time = 0
        @isDelete = false
    end

    #################################################################################
    # DSL 用メソッド
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
        @time = time
    end

    def modify(&block)
        @proc = Proc.new(&block)
    end

    def delete(tOrf)
        Checker.checkClasses(tOrf, TrueClass, FalseClass)
        @isDelete = tOrf
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
        $logger.debug("Linking... [#{@time}] (interval)")
        @time = IntervalTaskClass.getInstance(@time)
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

    #################################################################################
    # 適用フェーズに実行するメソッド定義
    #################################################################################
    def adapt()
        $logger.info("Task #{@taskname} will adapt now")

        if isDelete
            cmd = "EDITOR=cat knife environment delete #{@environmentname} -y 2> /dev/null"
            system(cmd)

        else
            if @sourceenvironmentname == nil
                @sourceenvironmentname = @environmentname
            end

            # Web 上からの取得の場合
            str = Webget.getStrFromURL(@sourceenvironmentname)
            unless str
                # ChefServer から情報の取得
                cmd = "EDITOR=cat knife environment edit #{@sourceenvironmentname} 2> /dev/null | sed -e '$d'"
                str = `#{cmd}`
                $logger.debug("Done: #{cmd}")
                $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")

                if str == ""
                    $logger.warn("Environment [#{sourceenvironmentname}] is not exist.")

                    if @sourceenvironmentname != @environmentname
                        $logger.error("Source environment [#{sourceenvironmentname}] is added to ChefServer, but not configured!")
                    end

                    cmd = "EDITOR=cat knife environment create #{@sourceenvironmentname} 2> /dev/null | sed -e '$d'"
                    str = `#{cmd}`
                    $logger.debug("Done: #{cmd}")
                    $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")
                end
            end

            # コード変更処理
            full_content = JSON.parse(str)
            @content = full_content # ["raw_data"]
            @proc.call()

            # JSON 化
            # full_content["raw_data"] = @content
            full_content["name"] = @environmentname
            result = JSON.pretty_generate(@content)

            # ChefServer へ書き出し
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}.json"
            File.write(tmpfilename, result)
            $logger.debug("Result is written to #{tmpfilename}")
            $logger.debug("Result: #{result.gsub(/\n/, '\\n')}")

            system("knife environment from file #{tmpfilename}")

            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end
        end

        $logger.info("adapted #{@taskname} successfully")

        # 待機処理
        @time.adapt()
    end
end

def environment(taskname, &block)
    $logger.debug("Environment task will register [#{taskname}]")
    var = EnvironmentTaskClass.new(taskname)
    var.instance_eval(&block)

    # Task 名の重複チェック
    if EnvironmentTaskClass.environmentpool.has_key?(taskname)
        $logger.fatal("Already environment task name [#{taskname}] is registered!")
    end
    EnvironmentTaskClass.environmentpool[taskname] = var

    var.register()
    $logger.debug("Environment task registered [#{taskname}]")
end
