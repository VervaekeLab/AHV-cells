function [hfigBHeatMap, hfigBErrorbar] = singleNeuronClassifierPlotBinfer(results,roiSelect,varargin)

hfigBHeatMap = []; hfigBErrorbar= [];

inputP = inputParser;
addRequired(inputP, 'results')
if isfield(results,'testPredictors')
    nTests = length(results.testPredictors);
    predictorNames = {results.testPredictors.predictorName}';
else nTests = 1;
end

addRequired(inputP, 'roiSelect', @(x)isnumeric(x) & ~isempty(x))
addParameter(inputP, 'tag', '', @ischar)
addParameter(inputP, 'uid', {''}, @iscell)
addParameter(inputP, 'pvalue', [], @isnumeric)
addParameter(inputP, 'plotConstant', false, @islogical)
addParameter(inputP, 'plotBinferErrorBar', true, @islogical)
addParameter(inputP, 'testSelect', 1:nTests , @(x)isnumeric(x) & x<=nTests)
parse(inputP, results, roiSelect, varargin{:});
v2struct(inputP.Results)
plotBinferErrorBar = plotBinferErrorBar;



%%

%logLiTrain = results.logLiTrain;
%logLiTest  = results.logLiTest;
if isfield(results,'sessionID')
    sessionID = results.sessionID;
else
    sessionID = '';
end
testPredictors = results.testPredictors;
compareTwoTests = results.compareTwoTests;

%N = results(1).testPredictors(1).outFold(1).N;
NplotMax = min(48,length(roiSelect));
NplotRows = 6;
NplotCols = 8;
%NplotMax = min(25, length(roiSelect));
%NplotRows = max(1,floor(sqrt(NplotMax)-1));
%NplotCols = ceil(NplotMax/NplotRows);

    

% Make plots bInfer
    
for ii = 1:length(testSelect)
    
    
   %% ii
   
   ij = testSelect(ii);
   
   %ij = find( testSelect ) ;
   if isempty(ij), error('no matching testSelect'), end 
    
    % Get relevant properties
   % two_test_idx  = compareTwoTests(ij).two_test_idx;
   % two_test_name = compareTwoTests(ij).two_test_name;
   % pWilcox       = compareTwoTests(ij).pWilcox;
   % hWilcox       = compareTwoTests(ij).hWilcox;
   % statsWilcox   = compareTwoTests(ij).statsWilcox;
    
    predictorName = results.testPredictors(ij).predictorName;
    if strcmp(predictorName,'None')
        fprintf(1, 'skip plotting constants\n')
        continue
    end
    
    infoPredictors = results.testPredictors(ij).outFold(1).infoPredictors;
    classUnique    = results.testPredictors(ij).outFold(1).classUnique;
    

    if length(classUnique) ~= length(infoPredictors)
        warning( 'Trimming classUnique from length (infoPredictors)')
        classUnique = classUnique(1:length(infoPredictors));
    end
    
    % create labels
    if plotConstant
    classUniqueAll = {'Constant'}; classUniqueAllNoCat = {''}; 
    else classUniqueAll = {}; classUniqueAllNoCat = {};
    end
    for c=1:length(classUnique)
       ctmp = classUnique{c};
       if isnumeric(ctmp), ctmp = num2str(ctmp); end
       txt = cellstr(ctmp);
       classUniqueAllNoCat = vertcat(classUniqueAllNoCat, txt );   % just numbers
       txt1 = cellfun(@(s)[ infoPredictors{c}, ' ' s], txt,'uni',false);
       classUniqueAll = vertcat(classUniqueAll, txt1 );             % categry + number
    end
    classUniqueMerge = classUniqueAllNoCat;
    
    
    % choose which rois to plot
    idxN = roiSelect;
    
    %% Collect Binfer
    clear binfer
    for iplot = 1:NplotMax
        n = idxN(iplot);
        subplot(NplotRows,NplotCols,iplot)
        
        kFold = length(results.testPredictors(ij).outFold);
        clear binferFold
        for fold = 1:kFold
            binferFold(:,fold) = (results.testPredictors(ij).outFold(fold).binfer(:,n));
        end
        binfer{iplot} = binferFold;
    end
    
    
    
    
    %% PLOT Binfer heatmap
    h1 = figure;
    set(h1,'Units','normalized','OuterPosition',[0.1,0.1,0.8,0.8])
    set(h1,'Name', sprintf('Binfer %s',predictorName) ) 
    for iplot = 1:NplotMax
        
        subplot(NplotRows,NplotCols,iplot)
        
        % binfer of one neuron, nParameters x kFold 
        binferFold = binfer{iplot};
        
        % select which variables to plot
        %if plotConstant 
        %    idx = true(size(classUniqueMerge));
        %else idx = ~contains(classUniqueMerge, {'Constant'});
        %end
        idx = 2:size(binferFold,1) ; 
        binferFoldFilter = binferFold(idx,:);
        %classUniqueFilter = classUniqueMerge(idx);
        classUniqueFilter = classUniqueMerge;
        imagesc(1:kFold,1:size(binferFoldFilter,1), binferFoldFilter)
        
        colormap jet
        cmax = max(abs(caxis)); caxis( cmax *[-1,1]);
        %axis equal tight,
        set(gca,'YTick',1:length(classUniqueFilter))
        
        % bottom row
        nrows = ceil(NplotMax/NplotCols);
        if (1)  %iplot>(nrows-1)*NplotCols
        %if iplot>(NplotRows-1)*NplotCols
            xlabel('crossval Fold')
        else           
            set(gca,'XTickLabel','')
        end 
        % left column
        if (1) %mod(iplot,NplotCols)==1, ylabel('predictor'),
            set(gca,'YTickLabel',classUniqueFilter) 
        else
            set(gca,'YTickLabel','')
        end
        
        %title(sprintf('%s roi:%d %s',sessionID,n ))
        if ~isempty(uid{1}), uidstr = uid{n}(1:7);
        else uidstr = ''; end
        if ~isempty(pvalue), pstr = sprintf('\np:%.2d',pvalue(n));
        else pstr = ''; end
        txt = sprintf('roi:%d %s %s', n, uidstr,pstr) ;
        title(txt)
        %colormap hot
        
        %colorbar('Location','manual')
        axis square
    end
    txt = sprintf('%s%s, %s', tag, sessionID, predictorName) ;
    suplabel( replace(txt,'_','\_'), 't' );
    hfigBHeatMap = [hfigBHeatMap, h1];
    
    
    
    
   
    %% plot Binfer errorbar
    if (plotBinferErrorBar)
        
        if length(classUniqueFilter)==1
            fprintf(1,'skip plotting classUniqueFilter 1\n')
            break
        end
        
        h2 = figure;
        h2axes = [];
        set(h2,'Units','normalized','OuterPosition',[0.1,0.05,0.8,0.9])
        set(h2,'Name', sprintf('Binfer Errorbar %s',predictorName) )
        for iplot = 1:NplotMax
            
            subplot(NplotRows,NplotCols,iplot)
            
            % binfer of one neuron, nParameters x kFold 
            binferFold = binfer{iplot};
            
            % select which variables to plot
            %if plotConstant, idx = true(size(classUniqueMerge))
            %else             idx = ~contains(classUniqueMerge, {'Constant'});
            %end
            idx = 2:size(binferFold,1) ;
            
            binferFoldFilter = binferFold(idx,:);
            %classUniqueFilter = classUniqueMerge(idx);
            classUniqueFilter = classUniqueMerge;
               
            h2axes = [h2axes, gca];
            x = 1:length(classUniqueFilter);
            ymean = mean(binferFoldFilter,2);
            ystd = std(binferFoldFilter,[],2) / sqrt(8);
            
            
            
            % xlabel
            %if strcmp(predictorName,'HDxV')
            %        error('predictorName not ready')
            %end                %errorbar( x, ymean, ystd)
            shadedErrorBar( x, ymean, ystd, 'lineProps', {'Color', 'b'})
            hold all
            XTick1 = 1:length(classUniqueFilter);
            XTickLabel1 = classUniqueFilter(1:end);
            
            
            
            %boxplot(binferFold', 'PlotStyle','compact')
            %linkaxes(h2axes)
            xlim( [XTick1(1), XTick1(end)] + [-0.5,0.5])
            ymax = max(abs(ylim)); ylim(ymax * [-1,1])
            hold all
            plot( xlim, [0,0], 'k','Color',[0.5,0.5,0.5])
            plot( [0,0], ylim, 'k','Color',[0.5,0.5,0.5])
            
            % bottom row
            nrows = ceil(NplotMax/NplotCols);
            if iplot>(nrows-1)*NplotCols
                %if iplot>(NplotRows-1)*NplotCols
                xlabel(predictorName)
                set(gca,'XTick', XTick1 )
                set(gca,'XTickLabel', XTickLabel1, 'XTickLabelRotation', 90)
            else
                set(gca,'XTickLabel','')
            end
            
            % TITLE
            %title(sprintf('%s roi:%d %s',sessionID,n ))
            if ~isempty(uid{1}), uidstr = uid{n}(1:7);
            else uidstr = ''; end
            if ~isempty(pvalue), pstr = sprintf('\np:%.2d',pvalue(n));
            else pstr = ''; end
            txt = sprintf('roi:%d %s %s', n, uidstr,pstr) ;
            title(txt)
            %colormap hot
            
        end
        
        txt = sprintf('%s%s, %s', tag, sessionID, predictorName) ;
        suplabel( replace(txt,'_','\_') ,'t' );
        hfigBErrorbar = [hfigBErrorbar, h2];
        
    end
end
