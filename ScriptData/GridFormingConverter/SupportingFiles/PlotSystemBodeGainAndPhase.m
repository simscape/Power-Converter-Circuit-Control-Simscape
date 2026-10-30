
%% Plot Controller Open Loop Bode Plot
% Copyright 2023 The MathWorks, Inc.
% Set controllerName to 'VdController', 'VqController', 'IdController', or 'IqController'.
% The controller analysis uses its own settings. Afterwards the workspace variables and the
% model settings return to the values set for the workflow.
if ~exist('controllerName', 'var');controllerName = 'VdController'; end

% Loading the model first: its load callbacks create the workflow parameters
load_system('GridFormingConverter');

% Store the workflow workspace variables, so they can be restored afterwards
userVariableNames = setdiff(who,{'marginTable'}); % The margin table is the result, not a setting
userWorkspace = struct();
for userVariableIdx = 1:numel(userVariableNames)
    userWorkspace.(userVariableNames{userVariableIdx}) = eval(userVariableNames{userVariableIdx});
end

% Store the workflow model settings, so they can be restored afterwards
controlBlockPath = 'GridFormingConverter/Grid-Forming Converter/Grid-Forming Converter Control';
converterBlockPath = 'GridFormingConverter/Grid-Forming Converter/Grid-Forming Converter Power Circuit';
solverBlockPath = ['GridFormingConverter/Solver' newline 'Configuration'];
savedModelDirty = get_param('GridFormingConverter','Dirty');
savedSolver = get_param('GridFormingConverter','Solver');
savedLocalSolver = get_param(solverBlockPath,'UseLocalSolver');
savedConverterVariant = get_param(converterBlockPath,'LabelModeActiveChoice');
savedPowerControl = get_param(controlBlockPath,'powerControl');
savedCurrentLimit = get_param(controlBlockPath,'currentLimit');
savedFrequencyOption = get_param(controlBlockPath,'freqOption');

% Controller analysis settings
run('GridFormingConverterInputParameters');
testCondition.activePowerMethod  = 'Virtual Synchronous Machine'; % Selecting the active power control method
testCondition.currentLimitMethod = 'Virtual Impedance'; % Selecting the fault ride through method
testCondition.XbyR = 5; % Selecting the grid X/R ratio
testCondition.SCR = 2.5; % Selecting the grid SCR value
testCondition.testCondition = 'Normal operation'; % Selecting the operating scenarios

% Setting the solver. Linearization does not support the Simscape local solver, so the
% power circuit is solved by the fixed-step global solver.
set_param('GridFormingConverter','Solver','ode1be'); % Choosing fixed step global solver for faster simulation
set_param(solverBlockPath,'UseLocalSolver','off');

% The test condition selects the average converter model and reloads the input parameters,
% so the continuous power measurement is set after it
run('GridFormingConverterTestCondition');
gridInverter.measurementSampleTime = 0; % Make measurement continuous

% Plotting the system bode plot. A failure is rethrown after the settings are restored.
bodeError = [];
try
    marginTable = plotBodeForController(controllerName,1);
catch bodeError
end

% Restore the workflow model settings
set_param('GridFormingConverter','Solver',savedSolver);
set_param(solverBlockPath,'UseLocalSolver',savedLocalSolver);
set_param(converterBlockPath,'LabelModeActiveChoice',savedConverterVariant);
set_param(controlBlockPath,'powerControl',savedPowerControl,'currentLimit',savedCurrentLimit, ...
    'freqOption',savedFrequencyOption);
set_param('GridFormingConverter','Dirty',savedModelDirty);

% Restore the workflow workspace variables. The margin table is kept as the result.
analysisVariableNames = setdiff(who,[userVariableNames; {'marginTable'; 'bodeError'; 'userWorkspace'; 'userVariableNames'}]);
clear(analysisVariableNames{:});
for userVariableIdx = 1:numel(userVariableNames)
    eval([userVariableNames{userVariableIdx} ' = userWorkspace.(userVariableNames{userVariableIdx});']);
end
clear userWorkspace userVariableIdx userVariableNames analysisVariableNames
if ~isempty(bodeError)
    rethrow(bodeError);
end
clear bodeError
