#####################################################################
# ChefScript の場合
#####################################################################
# nodes = ["node1", "node2", "node3"]
# nodes.each do |nodeX|
#     json "JSON task #{nodeX}" do
#         node nodeX
#         modify do
#             content["normal"]["memcached"]["version"] = "2.2.3-1.el5"
#         end
#         interval "check"
#     end
# end
# interval "check" do
#     confirm do
#         system "/usr/local/bin/checkcache.sh"
#     end
#     every 10
# end
# taskgroup "Rolling update" do
#     starts "2015-01-03 04:18:30"
#     nodes.each do |nodeX|
#         json "JSON task #{nodeX}"
#         push nodeX
#     end
# end

#####################################################################
# Bash の場合
#####################################################################
#!/bin/bash
# nodes="node1 node2 node3"
# time=`date`
# now=`date +"%Y-%m-%d %H:%M:%S"`
# starts="2015-01-08 13:25:15"
# remain= $(expr `date -d"${starts}" +%s` - `date -d"${now}" +%s`)
# sleep ${remain}
# for nodeX in ${nodes} do
#     EDITOR=vi knife node edit ${nodeX}
#     knife job start chef-client ${nodeX}
#     while true
#         do
#         if /usr/
#             local/bin/checkcache.sh; then
#             break
#          fi
#             sleep 10
#             done
#             done
