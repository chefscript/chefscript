class TaskClass
    #################################################################################
    # Running at register phase
    #################################################################################

    # Save task constitution to backend
    def register()
        raise("Not been implemented [register] methods.")
    end


    #################################################################################
    # Running at linking phase
    #################################################################################

    # Linking object from taskgroup to each tasks or from each tasks to interval tasks
    def linking()
        raise("Not been implemented [linking] methods.")
    end

    # Get Task objects by task name
    def getInstance(name)
        raise("Not been implemented [getInstance] methods.")
    end

    # Get JSON data of task constitution
    def getJsonInfo()
        raise("Not been implemented [getJsonInfo] methods.")
    end


    #################################################################################
    # Running at adapt phase
    #################################################################################

    # Adapt task
    def adapt()
        raise("Not been implemented [adapt] methods.")
    end
end

