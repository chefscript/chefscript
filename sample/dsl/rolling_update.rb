#####################################################################
# Case of ChefScript
#####################################################################
1:  nodes = ["node1", "node2", "node3"]
2:  nodes.each do |nodeX|
3:    json "JSON task #{nodeX}" do
4:      node nodeX
5:      modify do
6:       content["normal"]["memcached"]["version"] = "2.2.3-1.el5"
7:      end
8:    end
9:   interval "Check cache #{nodeX}" do
10:    confirm do
11:     system "/usr/local/bin/checkcache.sh #{nodeX}"
12:    end
13:    every 10
14:  end
15: end
16: taskgroup "Rolling update" do
17:   starts "2015-01-03 04:18:30"
18:   nodes.each do |nodeX|
19:     json "JSON task #{nodeX}"
20:     interval "Check cache #{nodeX}"
21:     apply nodeX
22:   end
23: end


#####################################################################
# Case of Bash
#####################################################################
1:  #!/bin/bash
2:  nodes="node1 node2 node3"
3:  time=`date`
4:  now=`date +"%Y-%m-%d %H:%M:%S"`
5:  starts="2015-01-08 13:25:15"
6:  remain=$(expr `date -d"${starts}" +%s` - `date -d"${now}" +%s`)
7:  sleep ${remain}
8:  for nodeX in ${nodes}
9:    do
10:   result=$(EDITOR=cat knife node edit ${nodeX} 2> /dev/null)
11:   if [ -z "${str}" ]; then
12:     result=$(EDITOR=cat knife node create ${nodeX} 2> /dev/null | sed -e '$d)
13:   fi
14:   echo ${result} > ${resultfile}
15:   perl -pi -e 's|^(      "version":) "1.1"|$1 "1.2"|' ${resultfile}
16:   knife node from file ${resultfile}
17:   knife job start chef-client ${nodeX}
18:   while true
19:   do
20:     if /usr/local/bin/checkcache.sh ${nodeX}; then
21:       break
22:     fi
23:     sleep 10
24:   done
25: done

