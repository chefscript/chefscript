require "./dsl/task"
require "./util/webget"
require "./util/checker"

require "json"
require "securerandom"

class JsonTaskClass < TaskClass
    attr_accessor :taskname, :nodename, :sourcenodename, :content, :time, :proc, :isDelete

    @@jsonpool = Hash.new()

    def JsonTaskClass.jsonpool
        return @@jsonpool
    end

    def initialize(taskname)
        @taskname = taskname
        @nodename = taskname
        @time = 0
        @isDelete = false
    end

    #################################################################################
    # DSL 用メソッド
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

    def JsonTaskClass.getInstance(taskname)
        var = @@jsonpool[taskname]
        if var == nil
            $logger.fatal("Cannnot find json task [#{taskname}].")
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
            cmd = "EDITOR=cat knife node delete #{@nodename} 2> /dev/null"
            system(cmd)

        else
            if @sourcenodename == nil
                @sourcenodename = @nodename
            end

            # Web 上からの取得の場合
            str = Webget.getStrFromURL(@sourcenodename)
            unless str
                # ChefServer から情報の取得
                cmd = "EDITOR=cat knife node edit #{@sourcenodename} 2> /dev/null"
                str = `#{cmd}`
                $logger.debug("Done: #{cmd}")
                $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")

                if str == ""
                    $logger.warn("Node [#{sourcenodename}] is not exist.")

                    if @sourcenodename != @nodename
                        $logger.error("Source node [#{sourcenodename}] is added to ChefServer, but not configured!")
                    end

                    cmd = "EDITOR=cat knife node create #{@sourcenodename} 2> /dev/null | sed -e '$d'"
                    str = `#{cmd}`
                    $logger.debug("Done: #{cmd}")
                    $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")
                end
            end

            # コード変更処理
            full_content = JSON.parse(str)
            @content = full_content # ["normal"]
            @proc.call()

            # JSON 化
            # full_content["normal"] = @content
            @content["name"] = @nodename
            result = JSON.pretty_generate(@content)

            # ChefServer へ書き出し
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}.json"
            File.write(tmpfilename, result)
            $logger.debug("Result is written to #{tmpfilename}")
            $logger.debug("Result: #{result.gsub(/\n/, '\\n')}")

            system("knife node from file #{tmpfilename}")

            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end
        end

        $logger.info("adapted #{@taskname} successfully")

        # 待機処理
        @time.adapt()
    end
end

def json(taskname, &block)
    $logger.debug("Json task will register [#{taskname}]")
    var = JsonTaskClass.new(taskname)
    var.instance_eval(&block)

    # Task 名の重複チェック
    if JsonTaskClass.jsonpool.has_key?(taskname)
        $logger.fatal("Already json task name [#{taskname}] is registered!")
    end
    JsonTaskClass.jsonpool[taskname] = var

    var.register()
    $logger.debug("Json task registered [#{taskname}]")
end
