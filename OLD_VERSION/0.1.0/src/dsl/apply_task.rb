require "./dsl/task"
require "./util/webget"
require "./util/checker"

require "securerandom"

class ApplyTaskClass < TaskClass
    attr_accessor :taskname, :nodename

    @@Applypool = Hash.new()

    def ApplyTaskClass.Applypool
        return @@Applypool
    end

    def initialize(nodename)
        @taskname = "Apply codes to #{nodename}"
        @nodename = nodename
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
    end

    def ApplyTaskClass.getInstance(nodename)
        var = nil
        if ApplyTaskClass.Applypool.has_key?(nodename)
            var = @@Applypool[nodename]
        else
            var = ApplyTaskClass.new(nodename)
            @@Applypool[nodename] = var
        end

        return var
    end

    #################################################################################
    # 適用フェーズに実行するメソッド定義
    #################################################################################
    def adapt()
        $logger.info("Apply codes to node [#{@nodename}] will adapt now")

        cmd = "knife job start chef-client #{@nodename} 2> /dev/null"
        str = `#{cmd}`
        $logger.debug("Done: #{cmd}")
        $logger.debug("Result: #{str.gsub(/\n/, '\\n')}")
        $logger.info("Applied codes to node [#{@nodename}] successfully")
    end

end
