# Abstract

ChefScript can use 3 backend datastore.  
0. MySQL  
1. SQLite  
2. JSON  


# Memo

Interval Task objects for waiting X seconds are not saved.  
Because, it is generate by simple way in linking() phase and it is consisted by single attribute (wait secound).  

Apply Task objects are not saved.  
Because, it is generate in linking() phase and it is consisted by single attribute (node name).  

task_kind id  
0: create  
1: recipe  
2: json  
3: role  
4: environment  
5: databag  
6: interval  
7: apply  

state id  
0: pending  
1: running  
2: done  


# MySQL backend

## Used datatype in MySQL
TINYINT UNSIGNED  
INT UNSIGNED  
VARCHAR(256)  
TEXT  
BOOLEAN  
TIMESTAMP  

## Table List

### dsl_files TABLE
```
id [INT UNSIGNED]
filename [VARCHAR(256)]
contents [TEXT]
is_loaded [BOOLEAN]
cron [VARCHAR(256)]
registered_at [TIMESTAMP]
parent [INT UNSIGNED]
is_deleted [BOOLEAN]
deleted_at [TIMESTAMP]
```

### create_task TABLE
```
id [INT UNSIGNED]
taskname [VARCHAR(256)]
file [VARCHAR(256)]
source_file [VARCHAR(256)]
cookbook [VARCHAR(256)]
isSite [VARCHAR(16)]
time [VARCHAR(256)]
modify [TEXT]
delete [BOOLEAN]
loaded_at [TIMESTAMP]
parent [INT UNSIGNED]
```

### recipe_task TABLE
```
id [INT UNSIGNED]
taskname [VARCHAR(256)]
file [VARCHAR(256)]
source_file [VARCHAR(256)]
cookbook [VARCHAR(256)]
isSite [VARCHAR(16)]
time [VARCHAR(256)]
modify [TEXT]
delete [BOOLEAN]
loaded_at [TIMESTAMP]
parent [INT UNSIGNED]
```

### json_task TABLE
```
id [INT UNSIGNED]
taskname [VARCHAR(256)]
node [VARCHAR(256)]
source_node [VARCHAR(256)]
time [VARCHAR(256)]
modify [TEXT]
delete [BOOLEAN]
loaded_at [TIMESTAMP]
parent [INT UNSIGNED]
```

### role_task TABLE
```
id [INT UNSIGNED]
taskname [VARCHAR(256)]
name [VARCHAR(256)]
source_name [VARCHAR(256)]
time [VARCHAR(256)]
modify [TEXT]
delete [BOOLEAN]
loaded_at [TIMESTAMP]
parent [INT UNSIGNED]
```

### environment_task TABLE
```
id [INT UNSIGNED]
taskname [VARCHAR(256)]
name [VARCHAR(256)]
source_name [VARCHAR(256)]
time [VARCHAR(256)]
modify [TEXT]
delete [BOOLEAN]
loaded_at [TIMESTAMP]
parent [INT UNSIGNED]
```

### databag_task TABLE
```
id [INT UNSIGNED]
taskname [VARCHAR(256)]
bag [VARCHAR(256)]
source_bag [VARCHAR(256)]
item [VARCHAR(256)]
source_item [VARCHAR(256)]
time [VARCHAR(256)]
modify [TEXT]
delete [BOOLEAN]
loaded_at [TIMESTAMP]
parent [INT UNSIGNED]
```

### interval_task TABLE
```
id [INT UNSIGNED]
taskname [VARCHAR(256)]
every [INT UNSIGNED]
trials [INT UNSIGNED]
confirm [TEXT]
loaded_at [TIMESTAMP]
parent [INT UNSIGNED]
```

### taskgroup TABLE
```
id [INT UNSIGNED]
taskgroup_name [VARCHAR(256)]
starts [VARCHAR(256)]
state [TINYINT UNSIGNED]
loaded_at [TIMESTAMP]
parent [INT UNSIGNED]
```

### proceed TABLE
```
id [INT UNSIGNED]
taskgroup_id [INT UNSIGNED]
_order [INT UNSIGNED]
task_kind [INT UNSIGNED]
task_name [VARCHAR(256)]
is_completed [BOOLEAN]
completed_at [TIMESTAMP]
```





# SQLite backend (NOT implemented)

## Used datatype in SQLite
INTEGER  
TEXT  
TIMESTAMP  

## Table List





# JSON backend (NOT implemented)

## Used datatype in json
int  
String  
bool  

## File List

### dsl_files.json
```
{
    "nowID": 3,
    "dsl1.rb": {
        1: {
            "contents": "CONTENTS...",
            "is_reload": "true",
            "cron": "CRON",
            "registered_at": "YYYY-MM-DD HH:MM:SS",
            "parent": 0
        },
        3: {
            "contents": "CONTENTS...",
            "is_reload": "true",
            "cron": "CRON",
            "registered_at": "YYYY-MM-DD HH:MM:SS",
            "parent": 1
        }
    },
    "dsl2.rb": {
        2: {
            "contents": "CONTENTS...",
            "is_reload": "true",
            "cron": "CRON",
            "registered_at": "YYYY-MM-DD HH:MM:SS",
            "parent": 0
        }
    }
}
```

### interval_task.json
```
{}
```

### taskgroup.json
```
{
    "nowID": 3,
    "taskgroup1": {
        1: {
            "loaded_at": "YYYY-MM-DD HH:MM:SS",
            "state": 0,
            "parent": 0,
            "proceed": [
                {
                    "task_kind": 0,
                    "task_id": 0,
                    "is_completed": true,
                    "completed_at": "YYYY-MM-DD HH:MM:SS"
                },
                {
                    "task_kind": 0,
                    "task_id": 0,
                    "is_completed": true,
                    "completed_at": "YYYY-MM-DD HH:MM:SS"
                }
            ]
        },
        3: {
            "loaded_at": "YYYY-MM-DD HH:MM:SS",
            "state": 0,
            "parent": 1,
            "proceed": [
                {
                    "task_kind": 0,
                    "task_id": 0,
                    "is_completed": true,
                    "completed_at": "YYYY-MM-DD HH:MM:SS"
                },
                {
                    "task_kind": 0,
                    "task_id": 0,
                    "is_completed": true,
                    "completed_at": "YYYY-MM-DD HH:MM:SS"
                }
            ]
        }
    },
    "taskgroup2": {
        2: {
            "loaded_at": "YYYY-MM-DD HH:MM:SS",
            "state": 0,
            "parent": 0,
            "proceed": [
                {
                    "task_kind": 0,
                    "task_id": 0,
                    "is_completed": true,
                    "completed_at": "YYYY-MM-DD HH:MM:SS"
                },
                {
                    "task_kind": 0,
                    "task_id": 0,
                    "is_completed": true,
                    "completed_at": "YYYY-MM-DD HH:MM:SS"
                }
            ]
        }
    }
}
```


