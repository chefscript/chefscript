# Copyright (c) 2015 Masaya Aoyama, released under the MIT license
# http://opensource.org/licenses/mit-license.php

require "./dsl/interval_task"
require "./dsl/recipe_task"
require "./dsl/json_task"
require "./dsl/databag_task"
require "./dsl/create_task"
require "./dsl/taskgroup"
require "./dsl/environment_task"
require "./dsl/role_task"
require "./backend/json_backend"
require "./backend/mysql_backend"
require "./backend/sqlite_backend"

require "logger"
require "time"
require "json"
require 'fileutils'
require 'digest/md5'
require 'sinatra'
require 'sqlite3'
require 'mysql2'
require 'mysql2-cs-bind'

require "./util/monkey_patch"
require "./util/extension_patch"

$version = "0.2.0"


#################################################################################
# How to Use
#################################################################################
# Please visit below sites.
# http://chefscript.github.io/chefscript/


#################################################################################
# Load default settings
#################################################################################
CONFIG_FILE = "./chefscript.conf"
$config = Hash.new()
$config["dsldir"] = "/root/chefscript-dir"
$config["repodir"] = "/root/chef-repo"
$config["pidfile"] = "/var/run/chefscript.pid"
$config["logfile"] = "/var/log/chefscript.log"
$config["loglevel"] = Logger::DEBUG
$config["force_recover"] = "false"
$config["knife_cmd"] = "/opt/chef/embedded/bin/knife"
$config["rest_port"] = "1125"
$config["rest_bind_ip"] = "0.0.0.0"
$config["backend"] = "mysql"
$config["json_dir"] = "/var/run/"
$config["sqlite_path"] = "/var/run/db_chefscript.sqlite3"
$config["mysql_user"] = "csuser"
$config["mysql_pass"] = "cspass"
$config["mysql_database_name"] = "db_chefscript"
$config["mysql_host"] = "localhost"
$config["mysql_port"] = "3306"


#################################################################################
# Load settings from configration file
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
# Load settings from launch options
#################################################################################
# TODO


#################################################################################
# Generate logger and set log level
#################################################################################
# $logger = tmplogger
$logger = Logger.new($config["logfile"])
$logger.level = $config["loglevel"].to_i
$logger.info("Start program...")


#################################################################################
# Generate backend object
#################################################################################
if $config["backend"].downcase() == "json"
    $backend =  JsonBackendClass.new()
elsif $config["backend"].downcase() == "sqlite"
    $backend =  SQLiteBackendClass.new()
elsif $config["backend"].downcase() == "mysql"
    $backend =  MySQLBackendClass.new()
else
    $logger.warn("Backend option [#{$config["backend"]}] is not corrected.")
    shutdown_program()
end


#################################################################################
# Generate PID file and signal handling
#################################################################################
if File.exist?($config["pidfile"]) && !$config["force_recover"].to_b
    $logger.warn("PID file is exist, and force_recover option is false.\n\n")
    exit()
elsif File.exist?($config["pidfile"])
    $logger.warn("PID file is exist, but force_recover option is true, so we attempt recover...")
    File.delete($config["pidfile"])
    $isRecovering = true
end

# Create new PID file
FileUtils.touch($config["pidfile"])
outfile = open($config["pidfile"], "w")
outfile.write(Process.pid)
outfile.close()

# Trap ^C Interrupt signal
Signal.trap("INT") { 
    shutdown_program()
    exit()
}

# Trap Terminate signal
Signal.trap("TERM") {
    shutdown_program()
    exit()
}


################################################################################
# Functions
################################################################################

# Shutdown handling
def shutdown_program()
    $logger.info("Stop program...\n\n")

    # Delete PID file
    File.delete($config["pidfile"])

    # Send Kill signal (9) to myself
    Process.kill("KILL", Process.pid)
end

# Load a DSL file by name
def loadDSL(dslfilename, isForce)
    eval($backend.getDSLFileContent(dslfilename))
    $backend.setLoadedDSLFile(dslfilename)
    $logger.info("File [dslfilename] is loaded")

    linkingUnlinkiedAllTaskgroup()
end

# Load all DSL files
def loadAllDSL()
    $logger.info("All DSL file is loading from now...")
    $backend.getDSLFileList().each do |dslfilename|
        loadDSL(dslfilename, true)
    end

    linkingUnlinkiedAllTaskgroup()
end

# Load all unloaded DSL files
def loadUnloadedAllDSL()
    $logger.info("All Unloaded DSL file is loading from now...")
    $backend.getUnloadedFileList().each do |dslfilename|
        loadDSL(dslfilename, false)
    end

    linkingUnlinkiedAllTaskgroup()
end


# Do linking() for all taskgroups, which does not linking()
def linkingUnlinkiedAllTaskgroup()
    TaskGroupClass.taskgrouppool.each do |key, taskgroup|
        taskgroup.linking()
    end
end

# Do linking() for a taskgroup, which do not linking()
def linkingTaskgroup(taskgroupname)
    TaskGroupClass.taskgrouppool[taskgroupname].linking()
end


# Run taskgroup after waiting start time as other thread.
def taskgroup_start(key, taskgroup)
    th = Thread.start(key, taskgroup) do |param1, param2|
        # Wait until execution time (start time).
        remain = param2.starttime - Time.now()
        $logger.debug("Waiting #{remain} sec for taskgroup [#{param1}]")

        if remain < 0 && param2.state == 0
            $logger.warn("Start time is too old. taskgroup = #{param1}")
        elsif param2.state == 2
            $logger.info("This taskgroup is already finished. taskgroup = #{param1}")
        else
            sleep(remain)
            $logger.info("Adapting task groups...")
            $logger.info("taskgroup = #{param1}")

            param2.adapt()
            $logger.info("adapted #{param1} successfully")
        end
    end
    taskgroup.setThread(th)
end


#################################################################################
# Sub-main threads for something
#################################################################################
Thread.start() do
    # If we want to do something by sub-main threads, write program here.
    # Truthly, main threads is used by Sinatra for REST API daemon.
end

# Load all saved tasks and taskgroups from backend.
$backend.loadTaskFromBackend()
# Ralate and verificate all tasks and taskgroupds
linkingUnlinkiedAllTaskgroup()

TaskGroupClass.taskgrouppool.each do |key, taskgroup|
    taskgroup_start(key, taskgroup)
end


#################################################################################
# Run REST API daemon
#################################################################################
set :bind, $config["rest_bind_ip"]
set :port, $config["rest_port"]


get '/:subcmd/:op/:name' do
    request_parse(params['subcmd'], params['op'], params['name'], params)
end

get '/:subcmd/:op' do
    request_parse(params['subcmd'], params['op'], nil, params)
end

get '/:subcmd' do
    request_parse(params['subcmd'], nil, nil, params)
end

# Analyse request constitution, and return JSON format data
def request_parse(subcmd, op, name, params)
    json = JSON.parse("{}")
    json["params"] = params

    if $version != params["version"]
        json["message"] = "Version is not matched between server version [#{$version}] and client version [#{params['version']}]."
        return JSON.pretty_generate(json)
    end

    case subcmd
    when "taskgroup" then
        case op

        when "list" then
            case params['type']

            when "pending" then
                json["message"] = "taskgroup list --type=pending is implemented" 
                ary = []
                i = 0
                TaskGroupClass.taskgrouppool.each do |key, taskgroup|
                    if taskgroup.state != 0
                        next
                    end
                    ary[i] = key
                    i += 1
                end
                json["taskgroups"] = ary
                json["taskgroup_size"] = ary.length

            when "running" then
                json["message"] = "taskgroup list --type=running is implemented"
                ary = []
                i = 0
                TaskGroupClass.taskgrouppool.each do |key, taskgroup|
                    if taskgroup.state != 1
                        next
                    end
                    ary[i] = key
                    i += 1
                end
                json["taskgroups"] = ary
                json["taskgroup_size"] = ary.length

            when "done" then
                json["message"] = "taskgroup list --type=done is implemented"
                ary = []
                i = 0
                TaskGroupClass.taskgrouppool.each do |key, taskgroup|
                    if taskgroup.state != 2
                        next
                    end
                    ary[i] = key
                    i += 1
                end
                json["taskgroups"] = ary
                json["taskgroup_size"] = ary.length

            else
                json["message"] = "taskgroup list is implemented"
                ary = []
                i = 0
                TaskGroupClass.taskgrouppool.each do |key, taskgroup|
                    ary[i] = key
                    i += 1
                end
                json["taskgroups"] = ary
                json["taskgroup_size"] = ary.length
            end


        when "show" then
            json["message"] = "taskgroup show #{params['name']} is implemented"
            json["taskgroup"] = TaskGroupClass.taskgrouppool[params['name']].getJsonInfo()
        end



    when "task" then
        case op

        when "list" then
            case params['type']

            when "json" then
                json["message"] = "task list --type=#{params['type']} is implemented"
                ary = []
                i = 0
                JsonTaskClass.jsonpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["jsontasks"] = ary
                json["jsontask_size"] = ary.length

            when "role" then
                json["message"] = "task list --type=#{params['type']} is implemented"
                ary = []
                i = 0
                RoleTaskClass.rolepool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["roletasks"] = ary
                json["roletask_size"] = ary.length

            when "environment" then
                json["message"] = "task list --type=#{params['type']} is implemented"
                ary = []
                i = 0
                EnvironmentTaskClass.environmentpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["environmenttasks"] = ary
                json["environmenttask_size"] = ary.length

            when "databag" then
                json["message"] = "task list --type=#{params['type']} is implemented"
                ary = []
                i = 0
                DatabagTaskClass.databagpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["databagtasks"] = ary
                json["databagtask_size"] = ary.length

            when "recipe" then
                json["message"] = "task list --type=#{params['type']} is implemented"
                ary = []
                i = 0
                RecipeTaskClass.recipepool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["recipetasks"] = ary
                json["recipetask_size"] = ary.length

            when "create" then
                json["message"] = "task list --type=#{params['type']} is implemented"
                ary = []
                i = 0
                CreateTaskClass.createpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["createtasks"] = ary
                json["createtask_size"] = ary.length

            when "interval" then
                json["message"] = "task list --type=#{params['type']} is implemented"
                ary = []
                i = 0
                IntervalTaskClass.intervalpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["intervaltasks"] = ary
                json["intervaltask_size"] = ary.length

            else
                json["message"] = "task list is implemented"
                ary = []
                i = 0
                JsonTaskClass.jsonpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["jsontasks"] = ary
                json["jsontask_size"] = ary.length
                ary = []
                i = 0
                RoleTaskClass.rolepool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["roletasks"] = ary
                json["roletask_size"] = ary.length
                ary = []
                i = 0
                EnvironmentTaskClass.environmentpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["environmenttasks"] = ary
                json["environmenttask_size"] = ary.length
                ary = []
                i = 0
                DatabagTaskClass.databagpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["databagtasks"] = ary
                json["databagtask_size"] = ary.length
                ary = []
                i = 0
                RecipeTaskClass.recipepool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["recipetasks"] = ary
                json["recipetask_size"] = ary.length
                ary = []
                i = 0
                CreateTaskClass.createpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["createtasks"] = ary
                json["createtask_size"] = ary.length
                ary = []
                i = 0
                IntervalTaskClass.intervalpool.each do |key, task|
                    ary[i] = key
                    i += 1
                end
                json["intervaltasks"] = ary
                json["intervaltask_size"] = ary.length
            end


        when "show" then
            case params['type']

            when "json" then
                json["message"] = "task show #{params['name']} --type=#{params['type']} is implemented"
                json["json_task"] = JsonTaskClass.jsonpool[params['name']].getJsonInfo()

            when "role" then
                json["message"] = "task show #{params['name']} --type=#{params['type']} is implemented"
                json["role_task"] = RoleTaskClass.rolepool[params['name']].getJsonInfo()

            when "environment" then
                json["message"] = "task show #{params['name']} --type=#{params['type']} is implemented"
                json["environment_task"] = EnvironmentTaskClass.environmentpool[params['name']].getJsonInfo()

            when "databag" then
                json["message"] = "task show #{params['name']} --type=#{params['type']} is implemented"
                json["databag_task"] = DatabagTaskClass.databagpool[params['name']].getJsonInfo()

            when "recipe" then
                json["message"] = "task show #{params['name']} --type=#{params['type']} is implemented"
                json["recipe_task"] = RecipeTaskClass.recipepool[params['name']].getJsonInfo()

            when "create" then
                json["message"] = "task show #{params['name']} --type=#{params['type']} is implemented"
                json["create_task"] = CreateTaskClass.createpool[params['name']].getJsonInfo()

            when "interval" then
                json["message"] = "task show #{params['name']} --type=#{params['type']} is implemented"
                json["interval_task"] = IntervalTaskClass.intervalpool[params['name']].getJsonInfo()

            else
                json["message"] = "task show #{params['name']} is NOT implemented"
            end
        end



    when "dsl" then
        case op

        when "list" then
            json["message"] = "dsl list is implemented"
            if params["unloaded"].to_b()
                json["dsllist"] = $backend.getUnloadedFileList()
            elsif params["loaded"].to_b()
                json["dsllist"] = $backend.getLoadedFileList()
            else
                json["dsllist"] = $backend.getDSLFileList()
            end
            json["succeeded"] = true


        when "show" then
            json["message"] = "dsl show #{params['name']} is implemented"
            json["dslfilename"] = params['name']
            json["dslcontent"] = $backend.getDSLFileContent(params['name'])
            json["succeeded"] = true


        when "add" then
            json["message"] = "dsl add #{params['name']} is implemented"
            $backend.addDSLFile(params['name'], params['contents'], 0)
            json["succeeded"] = true


        when "delete" then
            json["message"] = "dsl delete #{params['name']} is implemented"
            $backend.deleteDSLFile(params['name'])
            json["succeeded"] = true


        when "edit" then
            json["message"] = "dsl edit #{params['name']} is NOT implemented"
            # $backend.addDSLFile(params['name'], params['contents'])
            json["succeeded"] = true


        when "load" then
            if params['all'].to_b
                json["message"] = "dsl load --all is implemented"
                loadUnloadedAllDSL()
                json["succeeded"] = true
            else
                json["message"] = "dsl load #{params['name']} is NOT implemented"
                # loaddsl(params['name'], false)
                json["succeeded"] = true
            end


        when "reload" then
            if params['all'].to_b
                json["message"] = "dsl reload --all is NOT implemented"
                # loadalldsl()
                json["succeeded"] = true
            else
                json["message"] = "dsl reload #{params['name']} is NOT implemented"
                # loaddsl(params['name'], true)
                json["succeeded"] = true
            end
        end



    when "backend" then
        case op

        when "convert" then
            json["message"] = "backend convert #{params['name']} is NOT implemented"


        when "show" then
            json["message"] = "backend show is implemented"
            json["backend"] = $config["backend"].downcase()
            if $config["backend"].downcase() == "json"
                json["json_dir"] = $config["json_dir"]
            elsif $config["backend"].downcase() == "sqlite"
                json["sqlite_path"] = $config["sqlite_path"]
            elsif $config["backend"].downcase() == "mysql"
                json["mysql_user"] = $config["mysql_user"]
                json["mysql_pass"] = $config["mysql_pass"]
                json["mysql_database_name"] = $config["mysql_database_name"]
                json["mysql_host"] = $config["mysql_host"]
                json["mysql_port"] = $config["mysql_port"]
            end
        end



    when "history" then
        json["message"] = "history is implemented"
        json["history"] = `tail -100 #{$config["logfile"]}`



    when "shutdown" then
        shutdown_program()
        exit()
    end

    JSON.pretty_generate(json)
end




