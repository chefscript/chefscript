require "./dsl/interval_task"
require "./dsl/recipe_task"
require "./dsl/json_task"
require "./dsl/databag_task"
require "./dsl/create_task"
require "./dsl/taskgroup"
require "./dsl/environment_task"
require "./dsl/role_task"

require "logger"
require "time"

require "./util/monkey_patch"
require "./util/extension_patch"

#################################################################################
# How to Use
#################################################################################
# cd /root
# git clone URL
# cd /root/ChefScript/afterComsys2014/src
# rm /root/chef-repo/site-cookbooks/testbook -rf
# cp -ai /root/ChefScript/sample/site-cookbooks/testbook /root/chef-repo/site-cookbooks
# echo "Running... from bash"
# ruby /root/ChefScript/src/main.rb /root/ChefScript/sample/dsl/dsl.rb

#################################################################################
# デフォルト設定の読み込み
#################################################################################
CONFIG_FILE = "chefscript.conf"
$config = Hash.new()
$config["repodir"] = "/root/chef-repo"
$config["logfile"] = "/var/log/chefscript.log"
$config["loglevel"] = Logger::DEBUG

#################################################################################
# 設定の読み込み
#################################################################################
tmplogger = Logger.new(STDOUT)
open(CONFIG_FILE) do |file|
    while line = file.gets()
        if line[0, 1] == "#"
            next
        end

        splitedLine = line.split('=')

        if splitedLine.size() != 2 && line.strip() != ""
            tmplogger.fatal("Syntax of configuration file #{CONFIG_FILE} is not correct.")
        end
        if line.strip() != ""
            $config[splitedLine[0].strip()] = splitedLine[1].strip()
        end
    end
end

#################################################################################
# 起動オプション設定の読み込み
#################################################################################
# TODO

#################################################################################
# ロガーの生成とログレベルの設定
#################################################################################
# $logger = tmplogger
$logger = Logger.new($config["logfile"])
$logger.level = $config["loglevel"].to_i
$logger.info("Start program...")

#################################################################################
# 登録フェーズ
#################################################################################
ARGV.each do |loadfile|
    load(File.expand_path(loadfile))
    $logger.info("File [#{loadfile}] loaded")
end
$logger.info("Total taskgroup: #{TaskGroupClass.taskgrouppool.length}")

#################################################################################
# 検証フェーズ
#################################################################################
TaskGroupClass.taskgrouppool.each do |key, taskgroup|
    taskgroup.linking()
end

#################################################################################
# 実行フェーズ
#################################################################################
begin
    threadqueue = []
    TaskGroupClass.taskgrouppool.each do |key, taskgroup|
        t = Thread.start(key, taskgroup) do |param1, param2|
            # 実行開始時間まで待機
            remain = param2.starttime - Time.now()
            $logger.debug("Waiting #{remain} sec for taskgroup [#{param1}]")

            if remain < 0
                $logger.warn("Start time is too old. taskgroup = #{param1}")
            else
                sleep(remain)
                $logger.info("Adapting task groups...")
                $logger.info("taskgroup = #{param1}")

                param2.adapt()
                $logger.info("adapted #{param1} successfully")
            end
        end

        threadqueue.push(t)
    end

    # 全てのtaskgroupが実行完了するまで待機
    threadqueue.each do |th|
        th.join()
    end

    $logger.info("Finish applying all taskgroups")

# プログラムの強制終了を補足
rescue Interrupt
    $logger.warn("Shutdown program...")
ensure
    $logger.info("Stop program...\n\n")
end
