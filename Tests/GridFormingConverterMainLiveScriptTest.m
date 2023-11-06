classdef GridFormingConverterMainLiveScriptTest < matlab.unittest.TestCase
    % The class tests the |.mlx| and |.m| files present in this project.

    % Copyright 2023 The MathWorks, Inc.

    properties
        openfigureListBefore;
        openModelsBefore;
    end

    methods(TestMethodSetup)

        function listOpenFigures(test)
            % List all open figures
            test.openfigureListBefore = findall(0,'Type','Figure');
        end

        function listOpenModels(test)
            % List all open simulink models
            test.openModelsBefore = get_param(Simulink.allBlockDiagrams('model'),'Name');
        end

    end

    methods(TestMethodTeardown)

        function closeOpenedFigures(test)
            % Close all figure opened during test
            figureListAfter = findall(0,'Type','Figure');
            figuresOpenedByTest = setdiff(figureListAfter, test.openfigureListBefore);
            arrayfun(@close, figuresOpenedByTest);
        end

        function closeOpenedModels(test)
            % Close all models opened during test
            openModelsAfter = get_param(Simulink.allBlockDiagrams('model'),'Name');
            modelsOpenedByTest = setdiff(openModelsAfter, test.openModelsBefore);
            close_system(modelsOpenedByTest, 0);
        end

    end

    methods (Test)

        function GFMRunMainLiveScript(~)
            % Run main live script

            GridFormingConverterMain;
        end

        function GFMRunPlotSystemBodeGainAndPhaseVdController(~)
            % Test for the GFMRunPlotSystemBodeGainAndPhase MATLAB script
            % for 'VdController'.

            % Load model
            modelname = "GridFormingConverter";
            load_system(modelname);

            % Select the operating scenario
            controllerName = 'VdController'; %#ok<*NASGU>
            % Run script
            PlotSystemBodeGainAndPhase;
        end

        function GFMRunPlotSystemBodeGainAndPhaseVqController(~)
            % Test for the GFMRunPlotSystemBodeGainAndPhase MATLAB script
            % for 'VqController'.

            % Load model
            modelname = "GridFormingConverter";
            load_system(modelname)

            % Select the operating scenario
            controllerName = 'VqController';
            % Run script
            PlotSystemBodeGainAndPhase;
        end

        function GFMRunPlotSystemBodeGainAndPhaseIdController(~)
            % Test for the GFMRunPlotSystemBodeGainAndPhase MATLAB script
            % for 'IdController'.

            % Load model
            modelname = "GridFormingConverter";
            load_system(modelname);

            % Select the operating scenario
            controllerName = 'IdController';
            % Run script
            PlotSystemBodeGainAndPhase;
        end

        function GFMRunPlotSystemBodeGainAndPhaseIqController(~)
            % Test for the GFMRunPlotSystemBodeGainAndPhase MATLAB script
            % for 'IdController'.

            % Load model
            modelname = "GridFormingConverter";
            load_system(modelname)

            % Select the operating scenario
            controllerName = 'IqController';
            % Run script
            PlotSystemBodeGainAndPhase;
        end
    end
end
