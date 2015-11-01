require "./dsl/task"
require "./util/webget"
require "./util/checker"

require "json"
require "securerandom"

class DatabagTaskClass < TaskClass
    attr_accessor :taskname, :bagname, :itemname, :sourcebagname, :sourceitemname, :content, :time, :proc, :isDelete

    @@databagpool = Hash.new()

    def DatabagTaskClass.databagpool
        return @@databagpool
    end

    def initialize(taskname)
        @taskname = taskname
        @bagname = taskname
        @time = 0
        @isDelete = false
    end

    #################################################################################
    # DSL 用メソッド
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

    def DatabagTaskClass.getInstance(taskname)
        var = @@databagpool[taskname]
        if var == nil
            $logger.fatal("Cannnot find databag task [#{taskname}].")
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
            cmd = "EDITOR=cat knife data bag delete #{@bagname} #{@itemname} -y 2> /dev/null"
            system(cmd)

        else
            if @sourcebagname == nil
                @sourcebagname = @bagname
            end
            if @sourceitemname == nil
                @sourceitemname = @itemname
            end

            # Web 上からの取得の場合
            str = Webget.getStrFromURL(@sourceitemname)
            unless str
                str = Webget.getStrFromURL(@sourcebagname)
            end

            isCreated = false
            unless str
                # ChefServer から情報の取得
                cmd = "EDITOR=cat knife data bag edit #{@sourcebagname} #{@sourceitemname} 2> /dev/null | sed -e '$d'"
                str = `#{cmd}`
                $logger.debug("Done: #{cmd}")
                $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")

                if str == ""
                    isCreated = true
                    $logger.warn("Databag Item [#{@sourcebagname} / #{@sourceitemname}] is not exist.")

                    if @sourcebagname != @bagname || @sourceitemname != @itemname
                        $logger.error("Source databag item [#{@sourcebagname} / #{@sourceitemname}] is added to ChefServer, but not configured!")
                    end

                    cmd = "EDITOR=cat knife data bag create #{@sourcebagname} #{@sourceitemname} 2> /dev/null | sed -e '$d'"
                    str = `#{cmd}`
                    $logger.debug("Done: #{cmd}")
                    $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")
                end
            end

            # コード変更処理
            full_content = JSON.parse(str)
            if isCreated
                @content = full_content
            else
                @content = full_content["raw_data"]
            end
            @proc.call()

            # JSON 化
            # full_content["raw_data"] = @content
            @content["id"] = @itemname
            result = JSON.pretty_generate(@content)

            # ChefServer へ書き出し
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}.json"
            File.write(tmpfilename, result)
            $logger.debug("Result is written to #{tmpfilename}")
            $logger.debug("Result: #{result.gsub(/\n/, '\\n')}")

            system("knife data bag create #{@bagname}")
            system("knife data bag from file #{@bagname} #{tmpfilename}")

            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end
        end

        $logger.info("adapted #{@taskname} successfully")

        # 待機処理
        @time.adapt()
    end
end

def databag(taskname, &block)
    $logger.debug("Databag task will register [#{taskname}]")
    var = DatabagTaskClass.new(taskname)
    var.instance_eval(&block)

    # Task 名の重複チェック
    if DatabagTaskClass.databagpool.has_key?(taskname)
        $logger.fatal("Already databag task name [#{taskname}] is registered!")
    end
    DatabagTaskClass.databagpool[taskname] = var

    var.register()
    $logger.debug("Databag task registered [#{taskname}]")
end
