clc;
clear;

setenv("ROS_DOMAIN_ID","0");
setenv("ROS_LOCALHOST_ONLY","0");

node = ros2node("/matlab_traffic_monitor");

pause(5);

disp("Topics seen by MATLAB:");
disp(ros2("topic","list"));

topicNames = {
    "/traffic/input/pedestrian/light1"
    "/traffic/input/road/emergency"
    "/traffic/input/road/register"
    "/traffic/input/road/status"
    "/traffic/input/status/light1"
    "/traffic/output/light1/cmd"
};

messageTypes = {
    "std_msgs/Bool"
    "std_msgs/Bool"
    "std_msgs/String"
    "std_msgs/String"
    "std_msgs/String"
    "std_msgs/String"
};

subscribers = cell(size(topicNames));
lastMessages = cell(size(topicNames));

disp("Creating subscribers...");

for i = 1:length(topicNames)

    try
        subscribers{i} = ros2subscriber(node, topicNames{i}, messageTypes{i}, ...
            "Reliability", "besteffort", ...
            "Durability", "volatile", ...
            "History", "keeplast", ...
            "Depth", 10);

        lastMessages{i} = [];

        fprintf("[OK] %s | %s\n", topicNames{i}, messageTypes{i});

    catch ME
        subscribers{i} = [];
        fprintf("[ERROR] %s\n", topicNames{i});
        fprintf("%s\n", ME.message);
    end
end

disp("Live monitor started. Press CTRL+C to stop.");

while true

    fprintf("\n========================================\n");
    fprintf("       MATLAB ROS 2 TRAFFIC MONITOR\n");
    fprintf("========================================\n");
    fprintf("Time: %s\n", datestr(now));
    fprintf("========================================\n\n");

    for i = 1:length(topicNames)

        fprintf("Topic: %s\n", topicNames{i});

        if isempty(subscribers{i})
            fprintf("Subscriber not available.\n");
            fprintf("----------------------------------------\n");
            continue;
        end

        try
            [msg, status, statustext] = receive(subscribers{i}, 3);

            if status
                lastMessages{i} = msg;

                fprintf("New message received:\n");
                disp(msg);

                if isfield(msg, "data")
                    fprintf("Data value:\n");
                    disp(msg.data);
                elseif isprop(msg, "data")
                    fprintf("Data value:\n");
                    disp(msg.data);
                end

            else
                fprintf("No new message.\n");
                fprintf("Status: %s\n", statustext);

                if ~isempty(lastMessages{i})
                    fprintf("Last known message:\n");
                    disp(lastMessages{i});
                else
                    fprintf("No previous message stored.\n");
                end
            end

        catch ME
            fprintf("Receive failed.\n");
            fprintf("%s\n", ME.message);
        end

        fprintf("----------------------------------------\n");
    end

    pause(0.5);
end