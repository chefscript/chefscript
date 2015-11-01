interval "Multi File Include Test" do
    confirm do
        system "/root/ChefScript/stub/torf"
    end
    every 5
    trials 10
end
