create "File Test" do
    file "files/file1.conf"
    source_file "files/file1.conf"

    cookbook "testbook"
    isSite true
    interval "Interval Test"
    modify do
        content[1] = "# file1-2"
    end
    delete false
end

recipe "Recipe Test" do
    file "default.rb"
    source_file "default.rb"

    cookbook "testbook"
    isSite true
    interval "Interval Test"
    modify do
        content[1] = "    action :upgrade"
    end
    delete false
end

json "JSON Test" do
    node "sandbox.a-msy.jp"
    source_node "sandbox.a-msy.jp"

    modify do
        if content["normal"]["apache"] == "apache"
            content["normal"]["apache"] = "apache2"
        else
            content["normal"]["apache"] = "apache"
        end
    end
    interval "Interval Test"
    delete false
end

databag "Databag Test" do
    bag "testbag"
    item "testitem"
    source_bag "testbag"
    source_item "testitem"

    modify do
        content["databag_test_key"] = "databag_test_val2"
    end
    interval "Interval Test"
    delete false
end

environment "Environment Test" do
    name "testenv"
    source_name "testenv"

    modify do
        content["default_attributes"]["enviromnent_test_key"] = "enviromnent_test_val2"
    end
    interval "Interval Test"
    delete false
end

role "Role Test" do
    name "testrole"
    source_name "testrole"

    modify do
        content["default_attributes"]["role_test_key"] = "role_test_val2"
    end
    interval "Interval Test"
    delete false
end

interval "Interval Test" do
    confirm do
        system "/root/ChefScript/stub/torf"
    end
    every 1
    trials 100
end

taskgroup "Taskgroup Test" do
    # starts "2015-01-03 04:18:30"
    starts (Time.now() + 3).to_s

    create "File Test"
    recipe "Recipe Test"
    json "JSON Test"
    databag "Databag Test"
    environment "Environment Test"
    role "Role Test"
    interval "Interval Test"
    apply "sandbox.a-msy.jp"
end
