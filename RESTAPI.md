# REST API format

TODO: This page is temporary.  

/task/list?version=0.2.1  
/task/list?version=0.2.1&type=json  
/task/list?version=0.2.1&type=role  
/task/list?version=0.2.1&type=environment  
/task/list?version=0.2.1&type=databag  
/task/list?version=0.2.1&type=recipe  
/task/list?version=0.2.1&type=create  
/task/list?version=0.2.1&type=interval  

/task/show/NAME?version=0.2.1  
/task/show/NAME?version=0.2.1&type=json  
/task/show/NAME?version=0.2.1&type=role  
/task/show/NAME?version=0.2.1&type=environment  
/task/show/NAME?version=0.2.1&type=databag  
/task/show/NAME?version=0.2.1&type=recipe  
/task/show/NAME?version=0.2.1&type=create  
/task/show/NAME?version=0.2.1&type=interval  

/taskgroup/list?version=0.2.1  
/taskgroup/list?version=0.2.1&type=pending  
/taskgroup/list?version=0.2.1&type=running  
/taskgroup/list?version=0.2.1&type=done  

/taskgroup/show/NAME?version=0.2.1  
/taskgroup/show/NAME?version=0.2.1  

/shutdown?version=0.2.1  

/history?version=0.2.1  

/dsl/add/NAME?version=0.2.1&contents=DSLFILECONTENTDATA  
/dsl/delete/NAME?version=0.2.1&all=true  
/dsl/edit/NAME?version=0.2.1&all=true  
/dsl/show/NAME?version=0.2.1&all=true  
/dsl/load?version=0.2.1&all=true  
/dsl/reload?version=0.2.1&all=true  
/dsl/load/NAME?version=0.2.1&all=true  
/dsl/reload/NAME?version=0.2.1&all=true  

/dsl/list?version=0.2.1&all=true&unloaded=true  
/dsl/list?version=0.2.1&all=true&loaded=true  

/backend/convert/{json|mysql|sqlite}?version=0.2.1&mysql_host=VAL&mysql_port=VAL&mysql_user=VAL&mysql_pass=VAL&mysql_database_name=VAL&json_path=VAL&sqlite_path=VAL  
/backend/show?version=0.2.1  



