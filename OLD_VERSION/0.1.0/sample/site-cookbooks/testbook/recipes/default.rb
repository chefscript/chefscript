package "httpd" do
    action :install
    version node["httpd"]["version"]
end
service "httpd" do
    supports :status => true, :restart => true, :reload => true
    action [:disable , :start]
end
