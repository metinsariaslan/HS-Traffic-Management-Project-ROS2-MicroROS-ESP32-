clear
clc

rrApp = roadrunnerSetup;

openScene(rrApp,"OneWayJunctionWithSignal.rrscene");
openScenario(rrApp,"scenario_01_OneTrafficSignalObserver");

rrSim = createSimulation(rrApp);

pause(2)

set(rrSim,Logging="on")

Ts = 0.1;
set(rrSim,StepSize=Ts)


open_system("TrafficSignalObserver.slx")
set(rrSim,SimulationCommand="Start")
while strcmp(rrSim.get("SimulationStatus"),"Running")
    pause(1)
end