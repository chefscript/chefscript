require "./backend/backend"

require 'mysql2'
require 'mysql2-cs-bind'
require 'unindent'

class MySQLBackendClass < BackendClass
    attr_accessor :client

    def initialize()
        @client = Mysql2::Client.new(:host => $config["mysql_host"], :port => $config["mysql_port"],:username => $config["mysql_user"], :password => $config["mysql_pass"], :database => $config["mysql_database_name"])

        $logger.info("Connected to MySQL backend")

        create_table()
    end

    def execSQL(sql)
        $logger.debug("Executed MySQL Query: [#{sql}]")
        result = @client.query(sql)
        $logger.debug("Result: [#{result}]")

        return result
    end

    def execSQLwithArgs(sql, *args)
        $logger.debug("Executed MySQL Query: [#{sql} | #{args}]")
        result = @client.xquery(sql, *args)
        $logger.debug("Result: [#{result}]")

        return result
    end

    def create_table()
        $logger.debug("Create tables on MySQL backend")

        # dsl_files TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS dsl_files (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            filename VARCHAR(256) NOT NULL,
            contents TEXT NOT NULL,
            is_loaded BOOLEAN,
            cron VARCHAR(256),
            registered_at TIMESTAMP NOT NULL,
            parent INT UNSIGNED NOT NULL,
            is_deleted BOOLEAN,
            deleted_at TIMESTAMP
            );
        _EOF_
        execSQL(sql)

        # create_task TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS create_task (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskname VARCHAR(256) NOT NULL,
            file VARCHAR(256) NOT NULL,
            source_file VARCHAR(256) NOT NULL,
            cookbook VARCHAR(256) NOT NULL,
            isSite VARCHAR(16) NOT NULL,
            time VARCHAR(256),
            modify TEXT NOT NULL,
            _delete BOOLEAN NOT NULL,
            loaded_at TIMESTAMP NOT NULL,
            parent INT UNSIGNED NOT NULL
            );
        _EOF_
        execSQL(sql)

        # recipe_task TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS recipe_task (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskname VARCHAR(256) NOT NULL,
            file VARCHAR(256) NOT NULL,
            source_file VARCHAR(256) NOT NULL,
            cookbook VARCHAR(256) NOT NULL,
            isSite VARCHAR(16) NOT NULL,
            time VARCHAR(256),
            modify TEXT NOT NULL,
            _delete BOOLEAN NOT NULL,
            loaded_at TIMESTAMP NOT NULL,
            parent INT UNSIGNED NOT NULL
            );
        _EOF_
        execSQL(sql)

        # json_task TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS json_task (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskname VARCHAR(256) NOT NULL,
            node VARCHAR(256) NOT NULL,
            source_node VARCHAR(256) NOT NULL,
            time VARCHAR(256),
            modify TEXT NOT NULL,
            _delete BOOLEAN NOT NULL,
            loaded_at TIMESTAMP NOT NULL,
            parent INT UNSIGNED NOT NULL
            );
        _EOF_
        execSQL(sql)

        # role_task TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS role_task (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskname VARCHAR(256) NOT NULL,
            name VARCHAR(256) NOT NULL,
            source_name VARCHAR(256) NOT NULL,
            time VARCHAR(256),
            modify TEXT NOT NULL,
            _delete BOOLEAN NOT NULL,
            loaded_at TIMESTAMP NOT NULL,
            parent INT UNSIGNED NOT NULL
            );
        _EOF_
        execSQL(sql)

        # environment_task TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS environment_task (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskname VARCHAR(256) NOT NULL,
            name VARCHAR(256) NOT NULL,
            source_name VARCHAR(256) NOT NULL,
            time VARCHAR(256),
            modify TEXT NOT NULL,
            _delete BOOLEAN NOT NULL,
            loaded_at TIMESTAMP NOT NULL,
            parent INT UNSIGNED NOT NULL
            );
        _EOF_
        execSQL(sql)

        # databag_task TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS databag_task (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskname VARCHAR(256) NOT NULL,
            bag VARCHAR(256) NOT NULL,
            source_bag VARCHAR(256) NOT NULL,
            item VARCHAR(256) NOT NULL,
            source_item VARCHAR(256) NOT NULL,
            time VARCHAR(256),
            modify TEXT NOT NULL,
            _delete BOOLEAN NOT NULL,
            loaded_at TIMESTAMP NOT NULL,
            parent INT UNSIGNED NOT NULL
            );
        _EOF_
        execSQL(sql)

        # interval_task TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS interval_task (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskname VARCHAR(256) NOT NULL,
            every INT UNSIGNED NOT NULL,
            trials INT UNSIGNED NOT NULL,
            confirm TEXT NOT NULL,
            loaded_at TIMESTAMP NOT NULL,
            parent INT UNSIGNED NOT NULL
            );
        _EOF_
        execSQL(sql)

        # apply_task TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS apply_task (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskname VARCHAR(256) NOT NULL,
            nodename VARCHAR(256) NOT NULL,
            loaded_at TIMESTAMP NOT NULL
            );
        _EOF_
        execSQL(sql)

        # taskgroup TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS taskgroup (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskgroup_name VARCHAR(256) NOT NULL,
            starts VARCHAR(256) NOT NULL,
            state TINYINT UNSIGNED NOT NULL,
            loaded_at TIMESTAMP NOT NULL,
            parent INT UNSIGNED NOT NULL
            );
        _EOF_
        execSQL(sql)

        # proceed TABLE
        sql = <<-"_EOF_".unindent()
            CREATE TABLE IF NOT EXISTS proceed (
            id INT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT,
            taskgroup_id INT UNSIGNED NOT NULL,
            _order INT UNSIGNED NOT NULL,
            task_kind INT UNSIGNED NOT NULL,
            taskname VARCHAR(256) NOT NULL,
            is_completed BOOLEAN NOT NULL,
            completed_at TIMESTAMP NOT NULL
            );
        _EOF_
        execSQL(sql)

    end


    #################################################################################
    # For TASK operations
    #################################################################################
    def addTaskGroup(taskgrp, parentid)
        $logger.debug("Add taskgroup [#{taskgrp.taskgroupname}] to backend")

        sql = <<-"_EOF_".unindent()
            INSERT INTO taskgroup
            (taskgroup_name, starts, state, loaded_at, parent)
            VALUES
            (?, ?, 0, NOW(), ?)
        _EOF_

        execSQLwithArgs(sql, taskgrp.taskgroupname, taskgrp.starttime, parentid)

        sql = "SELECT id FROM taskgroup WHERE taskgroup_name=?"
        results = execSQLwithArgs(sql, taskgrp.taskgroupname)
        taskgrp_id = results.each[results.size() - 1]

        kind_id = 0
        order = 0
        taskgrp.pretaskqueue.each do |pair|
            if pair.left == :create
                kind_id = 0
            elsif pair.left == :recipe
                kind_id = 1
            elsif pair.left == :json
                kind_id = 2
            elsif pair.left == :role
                kind_id = 3
            elsif pair.left == :environment
                kind_id = 4
            elsif pair.left == :databag
                kind_id = 5
            elsif pair.left == :interval
                kind_id = 6
            elsif pair.left == :apply
                kind_id = 7
            end

            sql = <<-"_EOF_".unindent()
                INSERT INTO proceed
                (taskgroup_id, _order, task_kind, taskname, is_completed, completed_at)
                VALUES
                (?, ?, ?, ?, 0, NULL);
            _EOF_

            execSQLwithArgs(sql, taskgrp_id, order, kind_id, pair.right)
            order = order + 1
        end

    end

    def addRecipeTask(task, parentid)
        $logger.debug("Add recipe task [#{task.taskname}] to backend")

        sql = <<-"_EOF_".unindent()
            INSERT INTO recipe_task
            (taskname, file, source_file, cookbook, isSite, time, modify, delete, loaded_at, parent)
            VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?);
        _EOF_

        execSQLwithArgs(sql, task.taskname, task.filename, task.sourcefilename, task.cookbookname, task.site, task.time, task.proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"'), task.delete, parentid)
    end

    def addCreateTask(task, parentid)
        $logger.debug("Add create task [#{task.taskname}] to backend")

        sql = <<-"_EOF_".unindent()
            INSERT INTO create_task
            (taskname, file, source_file, cookbook, isSite, time, modify, delete, loaded_at, parent)
            VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?);
        _EOF_

        execSQLwithArgs(sql, task.taskname, task.filename, task.sourcefilename, task.cookbookname, task.site, task.time, task.proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"'), task.delete, parentid)
    end

    def addJsonTask(task, parentid)
        $logger.debug("Add json task [#{task.taskname}] to backend")

        sql = <<-"_EOF_".unindent()
            INSERT INTO json_task
            (taskname, node, source_node, time, modify, delete, loaded_at, parent)
            VALUES
            (?, ?, ?, ?, ?, ?, NOW(), ?);
        _EOF_

        execSQLwithArgs(sql, task.taskname, task.nodename, task.sourcenodename, task.time, task.proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"'), task.delete, parentid)
    end

    def addRoleTask(task, parentid)
        $logger.debug("Add role task [#{task.taskname}] to backend")

        sql = <<-"_EOF_".unindent()
            INSERT INTO role_task
            (taskname, name, source_name, time, modify, delete, loaded_at, parent)
            VALUES
            (?, ?, ?, ?, ?, ?, NOW(), ?);
        _EOF_

        execSQLwithArgs(sql, task.taskname, task.rolename, task.sourcerolename, task.time, task.proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"'), task.delete, parentid)
    end

    def addEnvironmentTask(task, parentid)
        $logger.debug("Add environment task [#{task.taskname}] to backend")

        sql = <<-"_EOF_".unindent()
            INSERT INTO environment_task
            (taskname, name, source_name, time, modify, delete, loaded_at, parent)
            VALUES
            (?, ?, ?, ?, ?, ?, NOW(), ?);
        _EOF_

        execSQLwithArgs(sql, task.taskname, task.environmentname, task.sourceenvironmentname, task.time, task.proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"'), task.delete, parentid)
    end

    def addDatabagTask(task, parentid)
        $logger.debug("Add databag task [#{task.taskname}] to backend")

        sql = <<-"_EOF_".unindent()
            INSERT INTO databag_task
            (taskname, bag, source_bag, item, source_item, time, modify, delete, loaded_at, parent)
            VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?);
        _EOF_

        execSQLwithArgs(sql, task.taskname, task.bagname, task.sourcebagname, task.itemname, task.sourceitemname, task.time, task.proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"'), task.delete, parentid)
    end

    def addIntervalTask(task, parentid)
        $logger.debug("Add interval task [#{task.taskname}] to backend")

        sql = <<-"_EOF_".unindent()
            INSERT INTO interval_task
            (taskname, every, trials, confirm, loaded_at, parent)
            VALUES
            (?, ?, ?, ?, NOW(), ?);
        _EOF_

        execSQLwithArgs(sql, task.taskname, task.every, task.trials, task.proc.source().gsub(/\n/, '\\n').gsub(/"/, '\"'), parentid)
    end

    # Set taskgroup status (pending, running, done)
    def setTaskgroupStatus(taskgroupname, state)
        $logger.debug("Set taskgroup status of [#{taskgroupname}] to #{state}")

        sql = <<-"_EOF_".unindent()
            UPDATE taskgroup SET
            state=?
            WHERE taskgroup_name=?;
        _EOF_

        execSQLwithArgs(sql, state, dslfilename)
    end

    # Update Proceeded status
    def updateProceed(taskgroupname, order)
        $logger.debug("Update proceeded status of [#{taskgroupname}] to #{order}")

        sql = <<-"_EOF_".unindent()
            UPDATE proceed SET
            is_completed=?,
            completed_at=NOW()
            WHERE taskgroup_name=? AND _order=?;
        _EOF_

        execSQLwithArgs(sql, true, taskgroupname, order)
    end

    def createTaskDataSQL(tablename)
        sql = <<-"_EOF_".unindent()
            SELECT * FROM #{tablename} AS t1
            WHERE t1.id IN (
                SELECT MAX(t2.id) FROM #{tablename} AS t2 
                GROUP BY t2.taskname
            );
        _EOF_

        return sql
    end

    # Load backend data for creating task and taskgroup objects
    def loadTaskFromBackend()
        $logger.debug("Load saved tasks from backend")

        createtasks = execSQL(createTaskDataSQL("create_task"))
        createtasks.each do |task|
            dsl = <<-"_EOF_".unindent()
                create "#{task["taskname"]}" do
                    file "#{task["file"]}"
                    source_file "#{task["source_file"]}"

                    cookbook "#{task["cookbook"]}"
                    isSite #{DSLUtils.isSite(task["isSite"])}
                    interval "#{task["time"]}"
                    modify do
                        #{task["modify"]}
                    end
                    delete #{task["delete"]}
                end
            _EOF_

            eval(dsl)
        end

        recipetasks = execSQL(createTaskDataSQL("recipe_task"))
        recipetasks.each do |task|
            dsl = <<-"_EOF_".unindent()
                recipe #{task["taskname"]} do
                    file #{task["file"]}
                    source_file #{task["source_file"]}

                    cookbook #{task["cookbook"]}
                    isSite #{DSLUtils.isSite(task["isSite"])}
                    interval #{task["time"]}
                    modify do
                        #{task["modify"]}
                    end
                    delete #{task["delete"]}
                end
            _EOF_

            eval(dsl)
        end

        jsontasks = execSQL(createTaskDataSQL("json_task"))
        jsontasks.each do |task|
            dsl = <<-"_EOF_".unindent()
                json #{task["taskname"]} do
                    node #{task["node"]}
                    source_node #{task["source_node"]}

                    interval #{task["time"]}
                    modify do
                        #{task["modify"]}
                    end
                    delete #{task["delete"]}
                end
            _EOF_

            eval(dsl)
        end

        roletasks = execSQL(createTaskDataSQL("role_task"))
        roletasks.each do |task|
            dsl = <<-"_EOF_".unindent()
                role #{task["taskname"]} do
                    name #{task["name"]}
                    source_name #{task["source_name"]}

                    interval #{task["time"]}
                    modify do
                        #{task["modify"]}
                    end
                    delete #{task["delete"]}
                end
            _EOF_

            eval(dsl)
        end

        environmenttasks = execSQL(createTaskDataSQL("environment_task"))
        environmenttasks.each do |task|
            dsl = <<-"_EOF_".unindent()
                environment #{task["taskname"]} do
                    name #{task["name"]}
                    source_name #{task["source_name"]}

                    interval #{task["time"]}
                    modify do
                        #{task["modify"]}
                    end
                    delete #{task["delete"]}
                end
            _EOF_

            eval(dsl)
        end

        databagtasks = execSQL(createTaskDataSQL("databag_task"))
        databagtasks.each do |task|
            dsl = <<-"_EOF_".unindent()
                databag #{task["taskname"]} do
                    bag #{task["bag"]}
                    item #{task["item"]}
                    source_bag #{task["source_bag"]}
                    source_item #{task["source_item"]}

                    interval #{task["time"]}
                    modify do
                        #{task["modify"]}
                    end
                    delete #{task["delete"]}
                end
            _EOF_

            eval(dsl)
        end

        intervaltasks = execSQL(createTaskDataSQL("interval_task"))
        intervaltasks.each do |task|
            dsl = <<-"_EOF_".unindent()
                interval #{task["taskname"]} do
                    confirm do
                        #{task["confirm"]}
                    end
                    every #{task["every"]}
                    trials #{task["trials"]}
                end
            _EOF_

            eval(dsl)
        end

        sql = <<-"_EOF_".unindent()
            SELECT * FROM taskgroup AS t1
            WHERE t1.id IN (
                SELECT MAX(t2.id) FROM taskgroup AS t2 
                GROUP BY t2.taskgroup_name
            );
        _EOF_
        taskgroups = execSQL(sql)

        sql = <<-"_EOF_".unindent()
            SELECT * FROM proceed AS t1
            WHERE t1.taskgroup_id IN (
                SELECT MAX(t2.id) FROM taskgroup AS t2 
                GROUP BY t2.taskgroup_name
            );
        _EOF_
        proceeds = execSQL(sql)


        taskgroups.each do |taskgrp|
            dsl = <<-"_EOF_".unindent()
                taskgroup "#{taskgrp["taskgroup_name"]}" do
                    starts "#{taskgrp["starts"]}"
            _EOF_

            # Indicate next task (0-origin)
            current_order = 0

            proceeds.each do |proceed|
                # Extract task which rerated to this taskgroup
                if proceed["taskgroup_id"] != taskgrp["id"]
                    next
                end

                if proceed["is_completed"].to_b()
                    if proceed["_order"] != current_order
                        $logger.fatal("Invalid task order is detected at taskgroup [#{taskgrp["taskgroup_name"]}].")
                    end

                    current_order = current_order + 1
                end

                case proceed["task_kind"]
                when 0
                    dsl = dsl + 'create "#{proceed["task_name"]}"\n'
                when 1
                    dsl = dsl + 'recipe "#{proceed["task_name"]}"\n'
                when 2
                    dsl = dsl + 'json "#{proceed["task_name"]}"\n'
                when 3
                    dsl = dsl + 'role "#{proceed["task_name"]}"\n'
                when 4
                    dsl = dsl + 'environment "#{proceed["task_name"]}"\n'
                when 5
                    dsl = dsl + 'databag "#{proceed["task_name"]}"\n'
                when 6
                    dsl = dsl + 'interval "#{proceed["task_name"]}"\n'
                when 7
                    dsl = dsl + 'apply "#{proceed["task_name"]}"\n'
                else
                    $logger.fatal("Invalid task_kind id is detected. taskname=[proceed['task_name']], taskgroup=[taskgrp['taskgroup_name']], task_kind=[proceed['task_kind']]")
                end
            end

            dsl = dsl + "end\n"

            eval(dsl)

            # Set progress status
            taskgroupobj = TaskGroupClass.taskgrouppool[taskgrp["taskgroup_name"]]
            taskgroupobj.setState(taskgrp["state"])
            taskgroupobj.setCurrentOrder(current_order)
        end

    end


    #################################################################################
    # For DSL operations
    #################################################################################
    def addDSLFile(dslfilename, dslfilecontent, parentid)
        $logger.debug("Add DSLFile [#{dslfilename}] to backend")

        sql = <<-"_EOF_".unindent()
            INSERT INTO dsl_files
            (filename, contents, is_loaded, cron, registered_at, parent, is_deleted, deleted_at)
            VALUES
            (?, ?, false, NULL, NOW(), ?, false, NULL);
        _EOF_
        execSQLwithArgs(sql, dslfilename, dslfilecontent, parentid)
    end

    def deleteDSLFile(dslfilename)
        $logger.debug("Delete DSLFile [#{dslfilename}] from backend")

        sql = <<-"_EOF_".unindent()
            UPDATE dsl_files SET
            is_deleted=true,
            deleted_at= NOW()
            WHERE filename=?;
        _EOF_
        execSQLwithArgs(sql, dslfilename)
    end

    # Get DSL file list
    def getDSLFileList()
        $logger.debug("Get DSLFile list from backend")

        sql = <<-"_EOF_".unindent()
            SELECT DISTINCT filename from dsl_files
            WHERE is_deleted=false;
        _EOF_

        ret = []

        results = execSQL(sql)
        results.each do |result|
            ret.push(result["filename"])
        end

        return ret
    end

    # Get DSL file list (Unloaded)
    def getUnloadedFileList()
        $logger.debug("Get unloaded DSLFile list from backend")

        sql = <<-"_EOF_".unindent()
            SELECT DISTINCT filename from dsl_files
            WHERE is_deleted=false AND is_loaded=false;
        _EOF_

        ret = []

        results = execSQL(sql)
        results.each do |result|
            ret.push(result["filename"])
        end

        return ret
    end

    # Get DSL file list (Loaded)
    def getLoadedFileList()
        $logger.debug("Get loaded DSLFile list from backend")

        sql = <<-"_EOF_".unindent()
            SELECT DISTINCT filename from dsl_files
            WHERE is_deleted=false AND is_loaded=true;
        _EOF_

        ret = []

        results = execSQL(sql)
        results.each do |result|
            ret.push(result["filename"])
        end

        return ret
    end

    # Set loaded flag to DSL file entry
    def setLoadedDSLFile(dslfilename)
        $logger.debug("Set loaded flag to DSL file [#{dslfilename}] into backend")

        sql = <<-"_EOF_".unindent()
            UPDATE dsl_files SET
            is_loaded=true
            WHERE filename=?;
        _EOF_

        execSQLwithArgs(sql, dslfilename)
    end

    # Get DSL file content
    def getDSLFileContent(dslfilename)
        $logger.debug("Get DSL file content of [#{dslfilename}] from backend")

        sql = <<-"_EOF_".unindent()
            SELECT contents from dsl_files
            WHERE filename=? AND is_deleted=false
            ORDER BY id DESC LIMIT 1;
        _EOF_

        mysqlresult = execSQLwithArgs(sql, dslfilename)

        # Return only recent contents
        return mysqlresult.each()[0]["contents"]

    end

end




