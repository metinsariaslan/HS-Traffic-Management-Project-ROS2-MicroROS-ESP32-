clc;
clear;

%% ROS 2 SETTINGS
setenv("ROS_DOMAIN_ID","0");
setenv("ROS_LOCALHOST_ONLY","0");

%% CREATE MATLAB ROS 2 NODE
node = ros2node("/matlab_live_topic_monitor");

disp("Starting MATLAB ROS 2 Live Topic Monitor...");
pause(3);   % wait for DDS discovery

%% GET TOPICS
topics = ros2("topic","list");

if isempty(topics)
    disp("No ROS 2 topics found.");
    return;
end

%% FILTER TOPICS
filteredTopics = {};

for i = 1:length(topics)
    topicName = topics{i};

    if topicName == "/parameter_events" || topicName == "/rosout"
        continue;
    end

    filteredTopics{end+1} = topicName;
end

%% CREATE SUBSCRIBERS ONLY ONCE
subscribers = cell(size(filteredTopics));
lastMessages = cell(size(filteredTopics));

disp("Creating subscribers...");

for i = 1:length(filteredTopics)
    topicName = filteredTopics{i};

    try
        subscribers{i} = ros2subscriber(node, topicName);
        lastMessages{i} = [];
        fprintf("[OK] Subscriber created: %s\n", topicName);
    catch ME
        subscribers{i} = [];
        fprintf("[ERROR] Could not create subscriber: %s\n", topicName);
        fprintf("Reason: %s\n", ME.message);
    end
end

disp(" ");
disp("Live reading started. Press CTRL + C to stop.");
pause(2);

%% CONTINUOUS LIVE READING
while true
    
    fprintf("========================================\n");
    fprintf("       LIVE ROS 2 TOPIC MONITOR\n");
    fprintf("========================================\n");
    fprintf("Time: %s\n", datestr(now));
    fprintf("Refresh: continuous\n");
    fprintf("========================================\n\n");

    for i = 1:length(filteredTopics)

        topicName = filteredTopics{i};
        sub = subscribers{i};

        fprintf("Topic: %s\n", topicName);

        if isempty(sub)
            fprintf("Subscriber not available.\n");
            fprintf("----------------------------------------\n");
            continue;
        end

        try
            % Your topic rate is 0.5 Hz, so timeout must be > 2 seconds
            msg = receive(sub, 3);

            lastMessages{i} = msg;

            fprintf("New message received:\n");
            disp(msg);

        catch
            fprintf("No new message in this cycle.\n");

            if ~isempty(lastMessages{i})
                fprintf("Last known message:\n");
                disp(lastMessages{i});
            else
                fprintf("No previous message stored yet.\n");
            end
        end

        fprintf("----------------------------------------\n");
    end

    pause(0.2);
end