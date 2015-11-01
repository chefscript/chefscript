require "./dsl/task"
require "./util/webget"
require "./util/checker"

require "json"
require "securerandom"

class RoleTaskClass < TaskClass
    attr_accessor :taskname, :rolename, :sourcerolename, :content, :time, :proc, :isDelete

    @@rolepool = Hash.new()

    def RoleTaskClass.rolepool
        return @@rolepool
    end

    def initialize(taskname)
        @taskname = taskname
        @rolename = taskname
        @time = 0
        @isDelete = false
    end

    #################################################################################
    # DSL 用メソッド
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

    def RoleTaskClass.getInstance(taskname)
        var = @@rolepool[taskname]
        if var == nil
            $logger.fatal("Cannnot find role task [#{taskname}].")
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
            cmd = "EDITOR=cat knife role delete #{@rolename} -y 2> /dev/null"
            system(cmd)

        else
            if @sourcerolename == nil
                @sourcerolename = @rolename
            end

            # Web 上からの取得の場合
            str = Webget.getStrFromURL(@sourcerolename)
            unless str
                # ChefServer から情報の取得
                cmd = "EDITOR=cat knife role edit #{@sourcerolename} 2> /dev/null | sed -e '$d'"
                str = `#{cmd}`
                $logger.debug("Done: #{cmd}")
                $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")

                if str == ""
                    $logger.warn("Role [#{sourcerolename}] is not exist.")

                    if @sourcerolename != @rolename
                        $logger.error("Source role [#{sourcerolename}] is added to ChefServer, but not configured!")
                    end

                    cmd = "EDITOR=cat knife role create #{@sourcerolename} 2> /dev/null | sed -e '$d'"
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
            full_content["name"] = @rolename
            result = JSON.pretty_generate(@content)

            # ChefServer へ書き出し
            tmpfilename = "/tmp/#{SecureRandom.hex(16)}.json"
            File.write(tmpfilename, result)
            $logger.debug("Result is written to #{tmpfilename}")
            $logger.debug("Result: #{result.gsub(/\n/, '\\n')}")

            system("knife role from file #{tmpfilename}")

            unless $config["development"].to_b
                system("rm #{tmpfilename} -f")
            end
        end

        $logger.info("adapted #{@taskname} successfully")

        # 待機処理
        @time.adapt()
    end
end

def role(taskname, &block)
    $logger.debug("Role task will register [#{taskname}]")
    var = RoleTaskClass.new(taskname)
    var.instance_eval(&block)

    # Task 名の重複チェック
    if RoleTaskClass.rolepool.has_key?(taskname)
        $logger.fatal("Already role task name [#{taskname}] is registered!")
    end
    RoleTaskClass.rolepool[taskname] = var

    var.register()
    $logger.debug("Role task registered [#{taskname}]")
end
