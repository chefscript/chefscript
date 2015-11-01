ChefScript: Time-Sequential Configuration Management Language for Operation Support
==========
Current Version: 0.2.0 (2015-10-31 03:55)

This software is Open Source Software under the MIT License.

- - -

### How to use
1. Setup Chef Workstation (included push-jobs), add target node and config knife command by knife.rb.  
  Reference: http://a-msy.jp/wiki/wiki.cgi?page=OSSChefServer  

2. Setup initial setting by chefscript/init.sh on Chef Workstation  
  Create MySQL database and user  
  Change mode client program "cscli"  
  Update PATH env for "cscli"  
  Bundle install for dependency  

3. Run the server program  
  Run on Chef Workstation: ruby chefscript/src/main.rb  

4. Manage ChefScript server by client program  
  Run on Client: cscli  

#### Caution
This software is beta version, so we may make changes to specifications.  

- - -

### Update log
* Version 0.2.0 (2015-10-31 03:55)  
Using backend storage system for failure recoverability.  
REST API implementation for daemonize and etc.  
  Run on Chef Workstation: ruby chefscript/src/main.rb  
  Run on Client: cscli  

* Version 0.1.0 (2015-06-28 01:25) [will be Discontinued]  
Minimum functions version  
  Run: ruby chefscript/OLD_VERSION/0.1.0/src/main.rb chefscript/OLD_VERSION/0.1.0/sample/dsl/dsl.rb  

- - -

