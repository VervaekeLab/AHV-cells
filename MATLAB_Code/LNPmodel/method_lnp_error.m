function [ error, meanError, binSquareError, binRmsError, stats ]  = method_lnp_error(predictors,classX,classInfer,varargin)

inputP = inputParser;
addRequired(inputP, 'predictors')
addRequired(inputP, 'classX')
addRequired(inputP, 'classInfer')
addParameter(inputP, 'circular', [], @islogical)
addParameter(inputP, 'doErrorShuffle', true, @islogical)
addParameter(inputP, 'errorShuffleBinMax', [], @isnumeric) % max bin to shuffle (default:333 for 10 s)  
addParameter(inputP, 'plotErrorShuffle', false, @islogical)
addParameter(inputP, 'kShuffle', 10000, @isnumeric)    % max number of shuffle  
parse( inputP, predictors, classX, classInfer , varargin{:} )
v2struct(inputP.Results)


if ~iscell(predictors)
    predictors = {predictors};
end
nPredictors = length(predictors);
nPredictors = size(classX,2);
Ptrain = length(classX);


error = zeros( Ptrain,nPredictors);
meanError = zeros( 1,nPredictors);
for j=1:nPredictors
    error(:,j) = not(classX(:,j)==classInfer(:,j));
    meanError(j) = mean(error(:,j),1);   
end

binSquareError = zeros(Ptrain,nPredictors);
binRmsError = zeros(1,nPredictors);
for j=1:nPredictors
    uniqY1 = unique(predictors{j});
    nBins = length(uniqY1); %classUnique{j});
    dBin = abs(classX(:,j)-classInfer(:,j));
    
    % circular error calculation
    if numel(circular) == nPredictors
        if circular(j)
            dBin = min( dBin, nBins-dBin) ;
        end
    end
    
    binSquareError(:,j) = (dBin.^2) ;
    binRmsError(j) = sqrt(mean(binSquareError(:,j),1)); 
end

% Struct output
stats.meanError = meanError;
stats.binRmsError = binRmsError;

%% Shuffle
if doErrorShuffle
    
    if isempty(errorShuffleBinMax)
        errorShuffleBinMax = Ptrain;
    end
    
    meanErrorShuffle   = zeros(kShuffle,nPredictors);
    binRmsErrorShuffle = zeros(kShuffle,nPredictors);
    for j=1:nPredictors
        uniqY1 = unique(predictors{j});
        nBins = length(uniqY1); 
            
        circular = circular; % explicit re-define for parfor
        parfor k=1:kShuffle
            
            randshift = randi(errorShuffleBinMax) - floor(errorShuffleBinMax/2);
            classXshift = circshift( classX(:,j) , [randshift, 0] );
            errorShuffle = not(classXshift==classInfer(:,j));
            meanErrorShuffle(k,j) = mean(errorShuffle,1); 
        
            dBin = abs( classXshift-classInfer(:,j));
            
            % circular error calculation
            if numel(circular) == nPredictors
                if circular(j)
                    dBin = min( dBin, nBins-dBin) ;
                end
            end
            
            binSquareErrorShuffle = (dBin.^2) ;
            binRmsErrorShuffle(k,j) = sqrt(mean(binSquareErrorShuffle,1));
        end
    end
    
    for j=1:nPredictors
        stats.meanError_p05(j)   = quantile( meanErrorShuffle(:,j), 0.5);
        stats.binRmsError_p05(j) = quantile( binRmsErrorShuffle(:,j), 0.5);
        stats.meanError_p005(j)   = quantile( meanErrorShuffle(:,j), 0.05);
        stats.binRmsError_p005(j) = quantile( binRmsErrorShuffle(:,j), 0.05);
        stats.pvalError(j)        = mean( meanError(j) >= meanErrorShuffle(:,j) );
        stats.pvalRmsError(j)     = mean( binRmsError(j) >= binRmsErrorShuffle(:,j) );
    end
    
    if plotErrorShuffle
        
        %%
        for j=1:nPredictors
            
            figure
            subplot(1,2,1), histogram(meanErrorShuffle(:,j))
            hold all
            plot( meanError(:,j)*[1 1], ylim )
            title(sprintf('predictor %d \n mean error %.2f (p=%.2f)',j,meanError(:,j), stats.pvalError(:,j)))
            
            subplot(1,2,2), histogram(binRmsErrorShuffle(:,j))
            hold all
            plot( binRmsError(:,j)*[1 1], ylim )
            title(sprintf('predictor %d \n rms error %.2f (p=%.2f)',j,binRmsError(:,j), stats.pvalRmsError(:,j)))
            
        end
    end
    
end

return
