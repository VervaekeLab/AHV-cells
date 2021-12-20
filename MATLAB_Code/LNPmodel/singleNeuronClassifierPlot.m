function singleNeuronClassifierPlot(results)

%% Compare train and test LL

hfigTrainTest = singleNeuronClassifierPlotLogLTrainTest(results);
for i = 1:length(hfigTrainTest)
    h1 = hfigTrainTest(i);
    savename = sprintf('%s_%s',results.savename,h1.Name);
    saveas(gcf,[savename,'.png'],'png');
    fprintf(1,'Saved to %s\n',savename)
end

%% Plot logL comparison

%uid = {sessionMeta.roiArray.uid}';
%hfigLogL = singleNeuronClassifierPlotLogL(results,'uid',uid);
hfigLogL = singleNeuronClassifierPlotLogL(results);
for i = 1:length(hfigLogL)
    h1 = hfigLogL(i);
    savename = sprintf('%s_%s',results.savename,h1.Name);
    %saveas(h1,savenamefig,'png');
    %saveas(h1,savenamefig,'fig');
    saveas(h1,[savename,'.fig'],'fig');
    saveas(h1,[savename,'.png'],'png');
    fprintf(1,'Saved to %s\n',savename)
    close(h1)
end



%% Make Binfer
savebinferdir = sprintf('%s/Binfer/',results.savedir);
if ~exist(savebinferdir,'dir')
    mkdir(savebinferdir);
    fprintf(1,'Make directory %s\n',savebinferdir)
end

if ~isempty(results.sessionMeta)
    N = results.sessionMeta.nRois;
else
    N = []; 
end
subfigMax = 48;
nfigs = ceil(N/subfigMax);

clear hfigBHeatmap hfigBErrorbar
for n1 = 1:nfigs
    
    roiID = (n1-1) * subfigMax + [1:subfigMax]; roiID(roiID>N)= [];
    %Nmax = min(30,N);
    if ~isempty(results.sessionMeta)
        uid = {results.sessionMeta.roiArray.uid}';
        [hfigBHeatmap{n1}, hfigBErrorbar{n1}] = singleNeuronClassifierPlotBinfer(results, roiID ,'uid', uid );
    else
        [hfigBHeatmap{n1}, hfigBErrorbar{n1}] = singleNeuronClassifierPlotBinfer(results, roiID );
    end
    
    for h1 = hfigBHeatmap{n1}(:).'
        nTrialTrain = length(results.testPredictors(end).idxTrialTrain{end});
        savenamefigB = sprintf('%s/%s_nTrialTrain%03d_%s_roi%03d-%03d',...
            savebinferdir,results.sessionID, nTrialTrain,h1.Name, roiID(1),roiID(end));
        saveas(h1,[savenamefigB,'.png'],'png');
        fprintf(1,'Saved to %s\n',[savenamefigB,'.png'])
       % close(h1)
    end
    for h1 = hfigBErrorbar{n1}(:).'
        
        nTrialTrain = length(results.testPredictors(end).idxTrialTrain{end});
        savenamefigB = sprintf('%s/%s_nTrialTrain%03d_%s_errorbar_roi%03d-%03d',...
            savebinferdir,results.sessionID, nTrialTrain,h1.Name, roiID(1),roiID(end));
        saveas(h1,[savenamefigB,'.png'],'png');
        fprintf(1,'Saved to %s\n',[savenamefigB,'.png'])
        %close(h1)
    end
end





