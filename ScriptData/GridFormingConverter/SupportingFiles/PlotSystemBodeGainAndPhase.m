
%% Plot Controller Open Loop Bode Plot
% Copyright 2023 The MathWorks, Inc.
if ~exist('controllerName', 'var');controllerName = 'VdController'; end

% Load the GFM input parameters
run('GridFormingConverterInputParameters');
temprySampleData = gridInverter.measurementSampleTime; % Store measurement sample time data
gridInverter.measurementSampleTime = 0; % Make measurement continuous

testCondition.activePowerMethod  = 'Virtual Synchronous Machine'; % Selecting the active power control method
testCondition.currentLimitMethod = 'Virtual Impedance'; % Selecting the fault ride through method
testCondition.XbyR = 5; % Selecting the grid X/R ratio
testCondition.SCR = 2.5; % Selecting the grid SCR value
testCondition.testCondition = 'Normal operation'; % Selecting the operating scenarios

% Setting the solver
set_param(sprintf(['GridFormingConverter','/Solver\nConfiguration']),'UseLocalSolver','off'); % Changing the solver to global solver
set_param('GridFormingConverter','Solver','ode1be'); % Chosing fixed step global solver for faster simulation

run('GridFormingConverterTestCondition');
% Plotting the system bode plot 
marginTable = plotBodeForController(controllerName,1);

% Revert back the solver settings
set_param(sprintf(['GridFormingConverter','/Solver\nConfiguration']),'UseLocalSolver','on');
gridInverter.measurementSampleTime = temprySampleData;



    











