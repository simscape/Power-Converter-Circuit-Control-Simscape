
classdef GridFormingConverterMainLiveScriptTest < matlab.unittest.TestCase
    % Test for main MATLAB Live Scipt and controller bode plot function
    % Test for the GridFormingConverterMain Live Script
    methods (Test)
        function GFMRunMainLiveScript(~)
            GridFormingConverterMain;
            close all
            bdclose all
        end
        % Test for the GFMRunPlotSystemBodeGainAndPhase MATLAB function
        function GFMRunPlotSystemBodeGainAndPhase(~)
            mdl = "GridFormingConverter";
            load_system(mdl)
            % Select the operating scenario
            controllerName = 'VdController';
            PlotSystemBodeGainAndPhase;

            bdclose all
            mdl = "GridFormingConverter";
            load_system(mdl)
            controllerName = 'VqController'; %#ok<*NASGU>
            PlotSystemBodeGainAndPhase;

            bdclose all
            mdl = "GridFormingConverter";
            load_system(mdl)
            controllerName = 'IdController';
            PlotSystemBodeGainAndPhase;

            bdclose all
            mdl = "GridFormingConverter";
            load_system(mdl)
            controllerName = 'IqController';
            PlotSystemBodeGainAndPhase;
            close all
            bdclose all
        end
    end
end
% Copyright 2023 The MathWorks, Inc.
