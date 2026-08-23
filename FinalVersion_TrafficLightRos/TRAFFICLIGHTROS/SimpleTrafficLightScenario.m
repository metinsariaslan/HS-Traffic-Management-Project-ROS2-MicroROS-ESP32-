classdef SimpleTrafficLightScenario < matlab.System
    % SimpleTrafficLightVisualization
    % Dashboard for one straight road, one ego vehicle, and one traffic light.
    %
    % Inputs:
    %   1. egoX               - ego X position [m]
    %   2. egoY               - ego Y position [m]
    %   3. trafficLightState  - 1=red, 2=yellow, 3=green
    %   4. distanceToLight    - distance from ego to stop line [m]
    %   5. desiredSpeed       - ego desired speed [m/s]
    %   6. emergencyDetected  - boolean flag

    properties(Nontunable)
        Ts = 0.01;
        RoadLength = 200;

        % OLD: RoadWidth = 4;
        RoadWidth = 14;         % 2 lanes each direction x 3.5m = 14m total

        TrafficLightX = 40;
        TrafficLightY = -2.3;
        StopLineX     = 35;

        LaneWidth     = 3.5;
        NumLanes      = 2;
        PavementWidth = 3;
    end

    properties(Logical)
        DisableVisualization = false;
    end

    properties(Access = private)
        Figure
        SceneAxes

        % Ego vehicle
        EgoPatch
        WindscreenPatch
        BrakeLightL
        BrakeLightR
        HeadingArrow
        DistanceLine
        DistLabel
        SpeedLabel
        TrailPlot
        TrailX
        TrailY

        % Traffic light
        TrafficLightMarker  % old invisible placeholder
        BulbRed
        BulbYellow
        BulbGreen
        GlowRed             % glow halo — drawn as patch circle, compatible approach
        GlowYellow
        GlowGreen

        StopLinePlot

        % Tables
        DataTable
        StateTable

        % Emergency overlay
        EmergencyText

        % Styles
        RedStyle
        YellowStyle
        GreenStyle
        BrakeStyle
        SafeStyle

        % Counters
        Counter
        PrevSpeed
    end

    methods(Access = protected)

        function setupImpl(obj)
            figureName = 'Simple Traffic Light Simulation';

            obj.Figure = findall(0, 'Type', 'figure', 'Tag', figureName);
            if isempty(obj.Figure)
                obj.Figure = uifigure('Name', figureName, 'Tag', figureName);
                screenSize = get(groot, 'ScreenSize');
                obj.Figure.Position = [screenSize(3)*0.02, screenSize(4)*0.05, ...
                                       screenSize(3)*0.95, screenSize(4)*0.88];
            end
            clf(obj.Figure);

            if obj.DisableVisualization
                obj.Figure.Visible = "off";
            else
                obj.Figure.Visible = "on";
            end

            % ----------------------------------------------------------------
            % PANEL LAYOUT
            % ----------------------------------------------------------------
            scenePanel = uipanel(obj.Figure, ...
                'Units', 'normalized', ...
                'Position', [0 0 0.65 1], ...
                'Title', 'Scenario View', ...
                'FontWeight', 'bold');

            statePanel = uipanel(obj.Figure, ...
                'Units', 'normalized', ...
                'Position', [0.65 0.68 0.35 0.32], ...
                'Title', 'Traffic Light State', ...
                'FontWeight', 'bold');

            dataPanel = uipanel(obj.Figure, ...
                'Units', 'normalized', ...
                'Position', [0.65 0 0.35 0.68], ...
                'Title', 'Runtime Data', ...
                'FontWeight', 'bold');

            % ----------------------------------------------------------------
            % SCENE AXES
            % ----------------------------------------------------------------
            obj.SceneAxes = axes('Parent', scenePanel);
            obj.SceneAxes.Position = [0.06 0.10 0.92 0.82];

            hold(obj.SceneAxes, 'on');
            grid(obj.SceneAxes, 'on');
            axis(obj.SceneAxes, 'equal');

            xlabel(obj.SceneAxes, 'X position [m]');
            ylabel(obj.SceneAxes, 'Y position [m]');
            title(obj.SceneAxes, 'Straight Road with Traffic Light', ...
                'FontSize', 13, 'FontWeight', 'bold');

            obj.SceneAxes.Color       = [1.0  1.0  1.0];
            obj.SceneAxes.GridColor   = [0.80 0.80 0.80];
            obj.SceneAxes.GridAlpha   = 0.6;
            obj.SceneAxes.XColor      = [0.15 0.15 0.15];
            obj.SceneAxes.YColor      = [0.15 0.15 0.15];
            obj.SceneAxes.Title.Color = [0.10 0.10 0.10];
            obj.SceneAxes.FontSize    = 10;

            obj.SceneAxes.XLim = [-15 80];
            obj.SceneAxes.YLim = [-20 16];

            % ----------------------------------------------------------------
            % ROAD
            % ----------------------------------------------------------------
            roadX = [0, obj.RoadLength, obj.RoadLength, 0];
            roadY = [-obj.RoadWidth/2, -obj.RoadWidth/2, obj.RoadWidth/2, obj.RoadWidth/2];

            % Grass strips
            grassTop = [obj.RoadWidth/2, obj.RoadWidth/2, ...
                        obj.RoadWidth/2+obj.PavementWidth, obj.RoadWidth/2+obj.PavementWidth];
            grassBot = [-obj.RoadWidth/2-obj.PavementWidth, -obj.RoadWidth/2-obj.PavementWidth, ...
                        -obj.RoadWidth/2, -obj.RoadWidth/2];
            patch(obj.SceneAxes, roadX, grassTop, [0.62 0.80 0.40], 'EdgeColor','none');
            patch(obj.SceneAxes, roadX, grassBot, [0.62 0.80 0.40], 'EdgeColor','none');

            % Asphalt
            patch(obj.SceneAxes, roadX, roadY, [0.50 0.50 0.50], 'EdgeColor','none');

            % White edge lines
            plot(obj.SceneAxes, [0, obj.RoadLength], [ obj.RoadWidth/2,  obj.RoadWidth/2], ...
                'w-', 'LineWidth', 2.5);
            plot(obj.SceneAxes, [0, obj.RoadLength], [-obj.RoadWidth/2, -obj.RoadWidth/2], ...
                'w-', 'LineWidth', 2.5);

            % Yellow dashed centre line
            dXc = []; dYc = [];
            for x = 0:10:obj.RoadLength
                dXc = [dXc, x,   x+5, NaN]; %#ok<AGROW>
                dYc = [dYc, 0.0, 0.0, NaN]; %#ok<AGROW>
            end
            plot(obj.SceneAxes, dXc, dYc, '-', 'Color', [1.0 0.85 0.0], 'LineWidth', 2.0);

            % White dashed lane dividers
            for laneY = [-obj.LaneWidth, obj.LaneWidth]
                dXl = []; dYl = [];
                for x = 0:10:obj.RoadLength
                    dXl = [dXl, x,     x+5,   NaN]; %#ok<AGROW>
                    dYl = [dYl, laneY, laneY, NaN]; %#ok<AGROW>
                end
                plot(obj.SceneAxes, dXl, dYl, 'w--', 'LineWidth', 1.2);
            end

            % Distance markers every 25m
            for x = 0:25:obj.RoadLength
                plot(obj.SceneAxes, [x, x], [-obj.RoadWidth/2, -obj.RoadWidth/2-0.6], ...
                    'w-', 'LineWidth', 1);
                text(obj.SceneAxes, x, -obj.RoadWidth/2-1.8, sprintf('%dm', x), ...
                    'Color', [0.15 0.15 0.15], 'FontSize', 7, ...
                    'HorizontalAlignment', 'center');
            end

            % ----------------------------------------------------------------
            % ZEBRA CROSSING + STOP LINE
            % ----------------------------------------------------------------
            stripeW = 0.7;
            for yi = -obj.RoadWidth/2 : 1.1 : obj.RoadWidth/2 - stripeW
                patch(obj.SceneAxes, ...
                    [obj.StopLineX-5, obj.StopLineX-5, obj.StopLineX-3, obj.StopLineX-3], ...
                    [yi, yi+stripeW, yi+stripeW, yi], ...
                    'white', 'EdgeColor','none', 'FaceAlpha', 0.65);
            end

            obj.StopLinePlot = plot(obj.SceneAxes, ...
                [obj.StopLineX, obj.StopLineX], [-obj.RoadWidth/2, obj.RoadWidth/2], ...
                'w-', 'LineWidth', 3.5);

            text(obj.SceneAxes, obj.StopLineX, obj.RoadWidth/2 + 2.0, 'Stop Line', ...
                'Color', [0.10 0.10 0.10], 'HorizontalAlignment', 'center', ...
                'FontSize', 9, 'FontWeight', 'bold');

            % ----------------------------------------------------------------
            % TRAFFIC LIGHT — pole + housing + glow patches + bulbs
            % ----------------------------------------------------------------
            poleX     = obj.TrafficLightX;
            poleBaseY = -obj.RoadWidth/2;
            houseY    = poleBaseY - 6;

            % Pole
            plot(obj.SceneAxes, [poleX, poleX], [poleBaseY, houseY], ...
                'Color', [0.30 0.30 0.30], 'LineWidth', 5);

            % Housing box
            patch(obj.SceneAxes, ...
                poleX + [-0.9,  0.9,  0.9, -0.9], ...
                houseY + [-0.2, -0.2, -4.5, -4.5], ...
                [0.12 0.12 0.12], 'EdgeColor', [0.45 0.45 0.45], 'LineWidth', 1.2);

            % Glow halos — drawn as large semi-transparent circles using patch
            % (compatible with all MATLAB versions, no undocumented MarkerHandle)
            nPts = 32;
            theta = linspace(0, 2*pi, nPts);
            glowR = 1.2;   % glow radius in axes units

            glowXRed = poleX + glowR*cos(theta);
            glowYRed = (houseY-0.9) + glowR*sin(theta);
            obj.GlowRed = patch(obj.SceneAxes, glowXRed, glowYRed, ...
                [1.0 0.0 0.0], 'EdgeColor','none', 'FaceAlpha', 0.18, 'Visible','off');

            glowXYellow = poleX + glowR*cos(theta);
            glowYYellow = (houseY-2.3) + glowR*sin(theta);
            obj.GlowYellow = patch(obj.SceneAxes, glowXYellow, glowYYellow, ...
                [1.0 0.90 0.0], 'EdgeColor','none', 'FaceAlpha', 0.18, 'Visible','off');

            glowXGreen = poleX + glowR*cos(theta);
            glowYGreen = (houseY-3.7) + glowR*sin(theta);
            obj.GlowGreen = patch(obj.SceneAxes, glowXGreen, glowYGreen, ...
                [0.0 1.0 0.2], 'EdgeColor','none', 'FaceAlpha', 0.18, 'Visible','off');

            % Bulbs on top of glows
            obj.BulbRed    = plot(obj.SceneAxes, poleX, houseY-0.9, 'o', ...
                'MarkerSize',16,'MarkerFaceColor',[0.30 0.0  0.0],'MarkerEdgeColor','none');
            obj.BulbYellow = plot(obj.SceneAxes, poleX, houseY-2.3, 'o', ...
                'MarkerSize',16,'MarkerFaceColor',[0.30 0.25 0.0],'MarkerEdgeColor','none');
            obj.BulbGreen  = plot(obj.SceneAxes, poleX, houseY-3.7, 'o', ...
                'MarkerSize',16,'MarkerFaceColor',[0.0  0.30 0.0],'MarkerEdgeColor','none');

            text(obj.SceneAxes, poleX, houseY-5.3, 'Traffic Light', ...
                'Color',[0.10 0.10 0.10],'HorizontalAlignment','center', ...
                'FontSize',8,'FontWeight','bold');

            % Old invisible placeholder
            obj.TrafficLightMarker = line(obj.SceneAxes, poleX, houseY-2.3, ...
                'Marker','none','LineStyle','none','Visible','off');

            % ----------------------------------------------------------------
            % EGO VEHICLE
            % ----------------------------------------------------------------
            vehicleLength = 4.5;
            vehicleWidth  = 1.8;

            xData = [-vehicleLength/2, vehicleLength/2, vehicleLength/2, -vehicleLength/2];
            yData = [-vehicleWidth/2,  -vehicleWidth/2,  vehicleWidth/2,  vehicleWidth/2];

            % Body
            obj.EgoPatch = patch(obj.SceneAxes, xData, yData, [0.90 0.08 0.08], ...
                'EdgeColor',[0.50 0.0 0.0],'FaceAlpha',1.0,'LineWidth',1.8);

            % Windscreen
            obj.WindscreenPatch = patch(obj.SceneAxes, ...
                [0, vehicleLength/2, vehicleLength/2, 0], ...
                [-vehicleWidth/2+0.25,-vehicleWidth/2+0.25, ...
                  vehicleWidth/2-0.25, vehicleWidth/2-0.25], ...
                [0.65 0.85 1.0],'EdgeColor','none','FaceAlpha',0.75);

            % Brake lights — small red rectangles at rear, hidden initially
            bly = vehicleWidth/2 - 0.45;
            obj.BrakeLightL = patch(obj.SceneAxes, ...
                [-vehicleLength/2-0.15,-vehicleLength/2,-vehicleLength/2,-vehicleLength/2-0.15], ...
                [ bly,  bly,  bly-0.40,  bly-0.40], ...
                [1.0 0.0 0.0],'EdgeColor','none','Visible','off');
            obj.BrakeLightR = patch(obj.SceneAxes, ...
                [-vehicleLength/2-0.15,-vehicleLength/2,-vehicleLength/2,-vehicleLength/2-0.15], ...
                [-bly, -bly, -bly+0.40, -bly+0.40], ...
                [1.0 0.0 0.0],'EdgeColor','none','Visible','off');

            % Direction arrow
            obj.HeadingArrow = quiver(obj.SceneAxes, 0, 0, 3.5, 0, 0, ...
                'Color',[0.10 0.10 0.10],'LineWidth',2.0,'MaxHeadSize',1.2);

            % Distance line + label
            obj.DistanceLine = plot(obj.SceneAxes, [0, obj.StopLineX], [0, 0], ...
                '--','Color',[0.0 0.65 0.20],'LineWidth',1.8);
            obj.DistLabel = text(obj.SceneAxes, obj.StopLineX/2, 3, '', ...
                'Color',[0.0 0.55 0.15],'FontSize',9, ...
                'HorizontalAlignment','center','FontWeight','bold');

            % Speed label
            obj.SpeedLabel = text(obj.SceneAxes, 0, 5, '0.0 m/s', ...
                'Color',[0.70 0.0 0.0],'FontSize',10, ...
                'HorizontalAlignment','center','FontWeight','bold');

            % Trail
            obj.TrailPlot = plot(obj.SceneAxes, NaN, NaN, ...
                ':','Color',[0.90 0.40 0.40],'LineWidth',1.5);
            obj.TrailX = [];
            obj.TrailY = [];

            % Emergency overlay text — centred top of scene, hidden until triggered
            obj.EmergencyText = text(obj.SceneAxes, 0.50, 0.91, '  ⚠  EMERGENCY  ⚠  ', ...
                'Units',              'normalized', ...
                'Color',              [1.0 1.0 1.0], ...
                'FontSize',           20, ...
                'FontWeight',         'bold', ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment',  'middle', ...
                'BackgroundColor',    [0.85 0.05 0.05], ...
                'EdgeColor',          [0.55 0.0  0.0], ...
                'LineWidth',          2, ...
                'Margin',             10, ...
                'Visible',            'off', ...
                'Clipping',           'off');

            % Counters
            obj.Counter   = 0;
            obj.PrevSpeed = 0;

            % ----------------------------------------------------------------
            % STATE TABLE
            % ----------------------------------------------------------------
            obj.StateTable = uitable(statePanel, ...
                'Units','normalized','Position',[0 0 1 1], ...
                'FontName','Consolas','FontSize',16);
            obj.StateTable.RowName    = {'State'};
            obj.StateTable.ColumnName = {'Value'};
            obj.StateTable.Data       = {'RED'};

            % ----------------------------------------------------------------
            % DATA TABLE
            % ----------------------------------------------------------------
            obj.DataTable = uitable(dataPanel, ...
                'Units','normalized','Position',[0 0 1 1], ...
                'FontName','Consolas','FontSize',13);

            obj.DataTable.RowName = { ...
                'egoX [m]', ...
                'egoY [m]', ...
                'Distance to stop [m]', ...
                'Speed [m/s]', ...
                'Time to stop line [s]', ...
                'Should brake?', ...
                'Emergency detected', ...
                'Sim time [s]'};
            obj.DataTable.ColumnName = {'Value'};
            obj.DataTable.Data = {0;0;0;0;0;'NO';false;0};

            % ----------------------------------------------------------------
            % UI STYLES
            % ----------------------------------------------------------------
            obj.RedStyle    = uistyle('BackgroundColor','red',   'FontColor','white');
            obj.YellowStyle = uistyle('BackgroundColor','yellow','FontColor','black');
            obj.GreenStyle  = uistyle('BackgroundColor','green', 'FontColor','white');
            obj.BrakeStyle  = uistyle('BackgroundColor',[1.0 0.55 0.55],'FontColor','black');
            obj.SafeStyle   = uistyle('BackgroundColor',[0.60 0.95 0.65],'FontColor','black');
        end

        function stepImpl(obj, egoX, egoY, trafficLightState, distanceToLight, desiredSpeed, emergencyDetected)

            if obj.DisableVisualization
                return;
            end

            vehicleLength = 4.5;
            vehicleWidth  = 1.8;

            % Keep the complete vehicle inside the road.
            % egoX is the vehicle centre, so the maximum centre position is
            % RoadLength minus half of the vehicle length.
            roadEndX = obj.RoadLength - vehicleLength/2;
            reachedRoadEnd = (double(egoX) >= roadEndX);

            if reachedRoadEnd
                egoX = roadEndX;
                desiredSpeed = 0;
                arrowLength = 0;
            else
                arrowLength = 3.5;
            end

            % ----------------------------------------------------------------
            % EGO BODY + WINDSCREEN
            % ----------------------------------------------------------------
            xData = egoX + [-vehicleLength/2, vehicleLength/2, vehicleLength/2, -vehicleLength/2];
            yData = egoY + [-vehicleWidth/2,  -vehicleWidth/2,  vehicleWidth/2,  vehicleWidth/2];
            obj.EgoPatch.XData = xData;
            obj.EgoPatch.YData = yData;

            obj.WindscreenPatch.XData = egoX + [0, vehicleLength/2, vehicleLength/2, 0];
            obj.WindscreenPatch.YData = egoY + [-vehicleWidth/2+0.25, -vehicleWidth/2+0.25, ...
                                                   vehicleWidth/2-0.25,  vehicleWidth/2-0.25];

            % ----------------------------------------------------------------
            % BRAKE LIGHTS
            % ----------------------------------------------------------------
            bly = vehicleWidth/2 - 0.45;
            obj.BrakeLightL.XData = egoX + [-vehicleLength/2-0.15,-vehicleLength/2, ...
                                             -vehicleLength/2,     -vehicleLength/2-0.15];
            obj.BrakeLightL.YData = egoY + [bly, bly, bly-0.40, bly-0.40];
            obj.BrakeLightR.XData = egoX + [-vehicleLength/2-0.15,-vehicleLength/2, ...
                                             -vehicleLength/2,     -vehicleLength/2-0.15];
            obj.BrakeLightR.YData = egoY + [-bly,-bly,-bly+0.40,-bly+0.40];

            if reachedRoadEnd || desiredSpeed < obj.PrevSpeed - 0.05
                obj.BrakeLightL.Visible = 'on';
                obj.BrakeLightR.Visible = 'on';
            else
                obj.BrakeLightL.Visible = 'off';
                obj.BrakeLightR.Visible = 'off';
            end

            % Direction arrow
            set(obj.HeadingArrow,'XData',egoX+vehicleLength/2,'YData',egoY, ...
                'UData',arrowLength,'VData',0);

            % Trail
            obj.TrailX(end+1) = egoX;
            obj.TrailY(end+1) = egoY;
            if numel(obj.TrailX) > 80
                obj.TrailX = obj.TrailX(end-79:end);
                obj.TrailY = obj.TrailY(end-79:end);
            end
            obj.TrailPlot.XData = obj.TrailX;
            obj.TrailPlot.YData = obj.TrailY;

            % Distance line + label
            obj.DistanceLine.XData = [egoX, obj.StopLineX];
            obj.DistanceLine.YData = [egoY, egoY];
            if distanceToLight < 10
                c = [0.90 0.10 0.10];
            elseif distanceToLight < 25
                c = [0.85 0.60 0.0];
            else
                c = [0.0  0.65 0.20];
            end
            obj.DistanceLine.Color    = c;
            obj.DistLabel.Color       = c;
            obj.DistLabel.Position(1) = (egoX + obj.StopLineX) / 2;
            obj.DistLabel.Position(2) = egoY + 2.8;
            obj.DistLabel.String      = sprintf('%.1f m', distanceToLight);

            % Speed label
            obj.SpeedLabel.Position(1) = egoX;
            obj.SpeedLabel.Position(2) = egoY + vehicleWidth/2 + 2.2;
            obj.SpeedLabel.String      = sprintf('%.1f m/s', desiredSpeed);

            % Auto-zoom
            obj.adjustView(egoX, egoY);

            % ----------------------------------------------------------------
            % EMERGENCY OVERLAY
            % ----------------------------------------------------------------
            if logical(emergencyDetected)
                obj.EmergencyText.Visible = 'on';
                obj.Figure.Color          = [1.0 0.82 0.82];
            else
                obj.EmergencyText.Visible = 'off';
                obj.Figure.Color          = [0.94 0.94 0.94];
            end

            % ----------------------------------------------------------------
            % TRAFFIC LIGHT — bulbs + glow
            % ----------------------------------------------------------------
            % Dim all bulbs, hide all glows
            obj.BulbRed.MarkerFaceColor    = [0.30 0.0  0.0];
            obj.BulbYellow.MarkerFaceColor = [0.30 0.25 0.0];
            obj.BulbGreen.MarkerFaceColor  = [0.0  0.30 0.0];
            obj.GlowRed.Visible    = 'off';
            obj.GlowYellow.Visible = 'off';
            obj.GlowGreen.Visible  = 'off';

            % Normalize the Simulink input to a scalar integer state.
            state = round(double(trafficLightState));

            switch state
                case 1
                    obj.BulbRed.MarkerFaceColor = [1.0  0.0  0.0];
                    obj.GlowRed.Visible         = 'on';
                    stateText = "RED";
                case 2
                    obj.BulbYellow.MarkerFaceColor = [1.0  0.90 0.0];
                    obj.GlowYellow.Visible         = 'on';
                    stateText = "YELLOW";
                case 3
                    obj.BulbGreen.MarkerFaceColor = [0.0  0.95 0.15];
                    obj.GlowGreen.Visible         = 'on';
                    stateText = "GREEN";
                otherwise
                    stateText = "UNKNOWN";
            end

            % ----------------------------------------------------------------
            % STATE TABLE
            % ----------------------------------------------------------------
            obj.StateTable.Data = {char(stateText)};
            removeStyle(obj.StateTable);
            switch state
                case 1, addStyle(obj.StateTable, obj.RedStyle,    "cell", [1 1]);
                case 2, addStyle(obj.StateTable, obj.YellowStyle, "cell", [1 1]);
                case 3, addStyle(obj.StateTable, obj.GreenStyle,  "cell", [1 1]);
            end

            % ----------------------------------------------------------------
            % DATA TABLE
            % ----------------------------------------------------------------
            if reachedRoadEnd
                timeToStop = 0;
            elseif desiredSpeed > 0.1
                timeToStop = distanceToLight / desiredSpeed;
            else
                timeToStop = Inf;
            end

            shouldBrake = reachedRoadEnd || ...
                ((distanceToLight < 30) && (state == 1));
            simTime     = obj.Counter * obj.Ts;

            if shouldBrake, brakeStr = 'YES'; else, brakeStr = 'NO'; end

            obj.DataTable.Data = { ...
                round(egoX, 2); ...
                round(egoY, 2); ...
                round(distanceToLight, 2); ...
                round(desiredSpeed, 2); ...
                round(timeToStop, 1); ...
                brakeStr; ...
                logical(emergencyDetected); ...
                round(simTime, 1)};

            removeStyle(obj.DataTable);
            if shouldBrake
                addStyle(obj.DataTable, obj.BrakeStyle, 'row', 6);
            else
                addStyle(obj.DataTable, obj.SafeStyle,  'row', 6);
            end

            obj.PrevSpeed = desiredSpeed;
            obj.Counter   = obj.Counter + 1;

            drawnow limitrate;
        end

        function icon = getIconImpl(~)
            icon = "Simple Traffic Light Visualization";
        end

        function sts = getSampleTimeImpl(obj)
            sts = obj.createSampleTime("Type","Discrete","SampleTime",obj.Ts);
        end

        function num = getNumInputsImpl(~)
            num = 6;
        end

        function num = getNumOutputsImpl(~)
            num = 0;
        end

        function validateInputsImpl(~, egoX, egoY, trafficLightState, distanceToLight, desiredSpeed, emergencyDetected)
            validateattributes(egoX,              {'numeric'},           {'scalar'});
            validateattributes(egoY,              {'numeric'},           {'scalar'});
            validateattributes(trafficLightState, {'numeric'},           {'scalar'});
            validateattributes(distanceToLight,   {'numeric'},           {'scalar'});
            validateattributes(desiredSpeed,      {'numeric'},           {'scalar'});
            validateattributes(emergencyDetected, {'numeric','logical'}, {'scalar'});
        end
    end

    methods(Access = private)

        function adjustView(obj, egoX, egoY)
            dist = abs(egoX - obj.TrafficLightX);
            if dist < 25
                offset = 20;
            elseif dist < 60
                offset = 35;
            else
                offset = 55;
            end
            obj.SceneAxes.XLim = [egoX - offset, egoX + offset];
            obj.SceneAxes.YLim = [-20, 16];
        end

    end

    methods(Access = protected, Static)
        function simMode = getSimulateUsingImpl
            simMode = "Interpreted execution";
        end
    end
end