class BackendClass

    #################################################################################
    # For TASK operations
    #################################################################################
    def addTaskGroup(taskgrp, parentid)
        $logger.debug("Add taskgroup [#{taskgrp.taskgroupname}] to backend")
        raise("Not been implemented [addTaskGroup] methods.")
    end

    def addRecipeTask(task, parentid)
        $logger.debug("Add recipe task [#{task.taskname}] to backend")
        raise("Not been implemented [addRecipeTask] methods.")
    end

    def addCreateTask(task, parentid)
        $logger.debug("Add create task [#{task.taskname}] to backend")
        raise("Not been implemented [addCreateTask] methods.")
    end

    def addJsonTask(task, parentid)
        $logger.debug("Add json task [#{task.taskname}] to backend")
        raise("Not been implemented [addJsonTask] methods.")
    end

    def addRoleTask(task, parentid)
        $logger.debug("Add role task [#{task.taskname}] to backend")
        raise("Not been implemented [addRoleTask] methods.")
    end

    def addEnvironmentTask(task, parentid)
        $logger.debug("Add environment task [#{task.taskname}] to backend")
        raise("Not been implemented [addEnvironmentTask] methods.")
    end

    def addDatabagTask(task, parentid)
        $logger.debug("Add databag task [#{task.taskname}] to backend")
        raise("Not been implemented [addDatabagTask] methods.")
    end

    def addIntervalTask(task, parentid)
        $logger.debug("Add interval task [#{task.taskname}] to backend")
        raise("Not been implemented [addIntervalTask] methods.")
    end

    # Set taskgroup status (pending, running, done)
    def setTaskgroupStatus(taskgroupname, state)
        $logger.debug("Set taskgroup status of [#{taskgroupname}] to #{state}")
        raise("Not been implemented [setTaskgroupStatus] methods.")
    end

    # Update Proceeded status
    def updateProceed(taskgroupname, order)
        $logger.debug("Update proceeded status of [#{taskgroupname}] to #{order}")
        raise("Not been implemented [updateProceed] methods.")
    end

    # Load backend data for creating task and taskgroup objects
    def loadTaskFromBackend()
        $logger.debug("Load saved tasks from backend")
        raise("Not been implemented [loadTaskFromBackend] methods.")
    end


    #################################################################################
    # For DSL operations
    #################################################################################
    def addDSLFile(dslfilename, dslfilecontent, parentid)
        $logger.debug("Add DSLFile [#{dslfilename}] to backend")
        raise("Not been implemented [addDSLFile] methods.")
    end

    def deleteDSLFile(dslfilename)
        $logger.debug("Delete DSLFile [#{dslfilename}] from backend")
        raise("Not been implemented [deleteDSLFile] methods.")
    end

    # Get DSL file list
    def getDSLFileList()
        $logger.debug("Get DSLFile list from backend")
        raise("Not been implemented [getDSLFileList] methods.")
    end

    # Get DSL file list (Unloaded)
    def getUnloadedFileList()
        $logger.debug("Get unloaded DSLFile list from backend")
        raise("Not been implemented [getUnloadedFileList] methods.")
    end

    # Get DSL file list (Loaded)
    def getLoadedFileList()
        $logger.debug("Get loaded DSLFile list from backend")
        raise("Not been implemented [getUnloadedFileList] methods.")
    end

    # Set loaded flag to DSL file entry
    def setLoadedDSLFile(dslfilename)
        $logger.debug("Set loaded flag to DSL file [#{dslfilename}] into backend")
        raise("Not been implemented [setLoadedDSLFile] methods.")
    end

    # Get DSL file content
    def getDSLFileContent(dslfilename)
        $logger.debug("Get DSL file content of [#{dslfilename}] from backend")
        raise("Not been implemented [getDSLFileContent] methods.")
    end

end

