require "./dsl/task"
require "./util/webget"
require "./util/rjson"
require "./util/checker"

class RecipeTaskClass < TaskClass
    attr_accessor :taskname, :filename, :cookbookname, :site, :sourcefilename, :content, :time, :proc, :isDelete

    @@recipepool = Hash.new()

    def RecipeTaskClass.recipepool
        return @@recipepool
    end

    def initialize(taskname)
        @taskname = taskname
        @filename = taskname
        @site = ""
        @time = 0
        @isDelete = false
    end

    #################################################################################
    # DSL 用メソッド
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

    def RecipeTaskClass.getInstance(taskname)
        var = @@recipepool[taskname]
        if var == nil
            $logger.fatal("Cannnot find recipe task [#{taskname}].")
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
            cmd = "rm #{$config['repodir']}/#{@site}cookbooks/#{cookbookname}/recipes/#{@filename} -f"
            system(cmd)

        else
            if @sourcefilename == nil
                @sourcefilename = @filename
            end

            # Web 上からの取得の場合
            str = Webget.getStrFromURL(@sourcefilename)
            unless str
                readfile = "#{$config['repodir']}/#{@site}cookbooks/#{@cookbookname}/recipes/#{@sourcefilename}"
                begin
                    str = File.read(readfile)
                rescue Errno::ENOENT
                    $logger.error("Source recipe file [#{readfile}] is not found! This task will configured from blank.")
                    str = ""
                end
            end

            # コード変更処理
            @content = RJSON.parse(str)
            @proc.call()

            # RJSON 化
            result = RJSON.pretty_generate(@content)

            # ファイルへの書き出し
            File.write("#{$config['repodir']}/#{@site}cookbooks/#{cookbookname}/recipes/#{@filename}", result)
        end

        # upload 処理
        system("knife cookbook upload #{@cookbookname} -o #{$config['repodir']}/#{@site}cookbooks")

        $logger.info("adapted #{@taskname} successfully")

        # 待機処理
        @time.adapt()
    end
end

def recipe(taskname, &block)
    $logger.debug("Recipe task will register [#{taskname}]")
    var = RecipeTaskClass.new(taskname)
    var.instance_eval(&block)

    # Task 名の重複チェック
    if RecipeTaskClass.recipepool.has_key?(taskname)
        $logger.fatal("Already recipe task name [#{taskname}] is registered!")
    end
    RecipeTaskClass.recipepool[taskname] = var

    var.register()
    $logger.debug("Recipe task registered [#{taskname}]")
end
