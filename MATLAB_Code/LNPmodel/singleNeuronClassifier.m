function results = singleNeuronClassifier(spikes, predictors, infoPredictors,trialNo, setup, varargin)

% Input structure (required)
%   spikes          : N x T-matrix                     - signal 
%   predictors      : 1 x #Behavior cell array         - behaviors 
%   infoPredictors  : 1 x #Behavior cell array of char - name of covariates 
%   trialNo         : 1 x T vector                     - trial numbers 
%
% Input (optional)
%   predNameSelect  : 1 x #Tests cell array of cells      - combination testing 
%                     example = { {'None'}, {'Place'}, {'Speed'}, {'Place','Speed'} }
%
% Example
%    spikes          = sData.imdata.roiArray(2).dff
%    predictors      = { sData.behavior.wheelPosDs, sData.behavior.speed }
%    infoPredictors  = { 'Place','Speed' }
%    trialNo         = sData.trialNo
%    results = singleNeuronClassifier(spikes, predictors, infoPredictors,trialNo)
%
% Output structure
%
%   results
%   .tag
%   .sessionID
%   .sessionMeta
%   .testPredictors( testnum )
%      .predictorName
%      .outputLNP( fold )
%   .compareTwoTests ( comparenum )
%      .two_test_idx
%      .two_test_name
%      .pWilcox
%      .hWilcox
%      .statsWilcox );
%   .logLiTrain
%   .logLiTest

defaultOutputDir = 'tmp/';


%% INPUTS

% Required inputs
inputP = inputParser;
addRequired(inputP, 'spikes', @(x)size(x,2)<size(x,1))
[ T,N ] = size(spikes);
addRequired(inputP, 'predictors', @(y)all(cellfun(@(x)length(x)==T,y)) )
addRequired(inputP, 'infoPredictors', @(x)iscell(x) & length(x)==length(predictors) )
addRequired(inputP, 'trialNo', @(x) isinteger(x) & length(x)==T )

% Optional inputs
defaultSetupLNP = setupLNPClass;
addOptional(inputP,'setup'         , defaultSetupLNP)

% Parameters
addParameter(inputP, 'predNameSelect', {}, @iscell)
addParameter(inputP, 'session', struct([]),@isstruct)
addParameter(inputP, 'sessionID','',@ischar)
addParameter(inputP, 'idxTime' , logical([]), @islogical)
addParameter(inputP, 'tag','',@ischar)
addParameter(inputP, 'Nmax', N,@(x)isinteger(x) && x >0 && x<=N )
addParameter(inputP, 'uniqPredictors', {} , @iscell);
addParameter(inputP, 'forceOutputDate' , '', @ischar)
addParameter(inputP, 'outputdir', defaultOutputDir, @ischar)
addParameter(inputP, 'makePlots', true, @islogical)
parse(inputP,spikes,predictors,infoPredictors,trialNo,varargin{:})
v2struct(inputP.Results)

% predictorNames
if isempty(predNameSelect)
    predNameSelect = defaultPredNameSelect(infoPredictors);
end
setup.predNameSelect = predNameSelect;

% Overwrite setup
if ~isempty(tag)            , setup.tag = tag; end

% Overwrite sessionID
if ~isempty(session)        , sessionID = session.sessionID; end

% Select neurons
spikes = spikes(:,1:Nmax);


%% Iterate through tests
nTestNum = length(predNameSelect);
for testNum = 1:nTestNum
    
    %% Run each predictor test set
    
    % Select predictors for this test
    infoPredSelect = predNameSelect{testNum};
    [pred, uniqPred] = selectPredictors(predictors, infoPredictors, infoPredSelect, uniqPredictors);
    
    % Cross validation
    for k = 1:setup.kfoldMax
        
        % Spew something out
        fprintf(1,'\nTest %s %d (%s) fold %d/%d\n', sessionID, testNum, [infoPredSelect{:}], k, setup.kfold)
        
        % Choose trials to include
        [idxTrainTest, idxTrialTrain, idxTrialTest] = set_idxTrainTest( k, trialNo, setup );
        
        % Process
        out = method_lnp(spikes,pred,setup,'idxTrainTest',idxTrainTest,'trialNo',trialNo,...
            'infoPredictors', infoPredSelect , 'uniqPred', uniqPred,'session',session, 'idxY', idxTime, 'kfold', k );
        
        % Decode
        classUnique = out.classUnique;
        binfer = out.binfer;
        [classInfer, logL, movieFrames, classInferSubset, movieLogLSubset ] = ...
            method_lnp_decode( classUnique, spikes, pred, binfer,setup);
        
        
        % Gather
        s1.outFold(k) = out;
        s1.idxTrainTest{k}  = idxTrainTest;
        s1.idxTrialTrain{k} = idxTrialTrain;
        s1.idxTrialTest{k}  = idxTrialTest;
        s1.trialNo{k}       = trialNo;
        s1.predictorName    = [infoPredSelect{:}] ;
        testPredictors(testNum) = s1;
    end
end



%% Organize results nicely

% organize as logLiTrain{ test }( cell, fold)
clear logLiTrain logLiTest
for testNum = 1:nTestNum
    for k = 1:setup.kfoldMax
        logLiTrain{testNum}(:,k) = testPredictors(testNum).outFold(k).logLiTrain';
        logLiTest{testNum}(:,k)  = testPredictors(testNum).outFold(k).logLiTest';
    end
end
data = setup.data;
if ~isempty(session)
    sessionMeta = session_meta(session);
else
    sessionMeta = [];
end
dateCreated = datestr(now);
results = v2struct(dateCreated,data,tag,sessionID,sessionMeta,setup,testPredictors,logLiTrain,logLiTest,idxTime);


%% Compare test set LL
compareTwoTests = singleNeuronClassifierWilcoxon(results);
results.compareTwoTests = compareTwoTests;


%% Save file
if ~exist(outputdir,'dir')
    mkdir(outputdir)
    fprintf(1,'Mkdir %s\n',outputdir)
end


%% Print outputDate
if isempty(forceOutputDate)
    datenow = datestr(now,'yyyymmdd');
else
    datenow = forceOutputDate ;
    warning(1,'\n\nForce to print date to %s!\n\n',forceOutputDate)
end

savedir = sprintf('%s/%s_neuronClassifier_%s_kfold%d/',...
    outputdir,datenow,setup.tag,setup.kfold);
savename = sprintf('%s/%s_resultsClassifier_%s_kfold%d_N%03d_nTrialTrain%03d',...
    savedir,sessionID,setup.protocol,setup.kfold,Nmax, length(idxTrialTrain));
results.outputdir = outputdir;
results.savedir   = savedir;
results.savename = savename;
if ~exist(savedir,'dir')
    mkdir(savedir);
    fprintf(1,'Make directory %s\n',savedir)
end
save(savename,'results');
fprintf(1,'Saved to %s\n',savename)
fprintf(1,'Done\n')

%% Make plots
if makePlots
    singleNeuronClassifierPlot(results)
end

end












%%%% Supporting functions

function infoPredictors = defaultInfoPredictors( nPred)

for i=1:nPred
    infoPredictors{i} = sprintf('Var%d',i);
end

end


function predNameSelect = defaultPredNameSelect( infoPredictors )
% generates example: predNameSelect = {{'None'},{'Var1'},{'Var2'}, {'Var1',Var2'} }

nPred = length(infoPredictors);

% No variable
predNameSelect{1} = {'None'};

% Single variable
for i=1:nPred
    predNameSelect{1 + i} = infoPredictors(i);
end

% Double variable
for i=1:nPred
    for j=i+1:nPred
        k = 1 + nPred*i + j-1;
        predNameSelect{k} = { infoPredictors{i}, infoPredictors{j} };
    end
end

end


function [idxTrainTest, idxTrialTrain, idxTrialTest] = set_idxTrainTest( k, trialNo,setup )

k = round(k);
kfold = setup.kfold;
crossValMethod     = setup.crossValMethod;
monteCarloPctTrain = setup.monteCarloPctTrain;
nTrialTrain = setup.nTrialTrain;
nTrialTest  = setup.nTrialTest;


% Choose train and test sets
switch crossValMethod
    
    % case 'leaveOneOut'
    %
    %     quantileT = floor(linspace(1,T,kfold+1));
    %     idxTest  = quantileT(k):quantileT(k+1)-1 ;
    %     idxTrain = 1:T; idxTrain(idxTest) = [];
    %     idxTrainTest  = {idxTrain, idxTest};
    % case 'keepOneIn'
    %
    %     quantileT = floor(linspace(1,T,kfold+1));
    %     idxTrain = quantileT(k):quantileT(k+1)-1 ;
    %     idxTest  = 1:T; idxTest(idxTrain) = [];
    %     idxTrainTest  = {idxTrain, idxTest};
    
    case 'monteCarlo'
        if isempty(trialNo), error('setup.crossValMethod %s need trialNumbers',crossValMethod), end
        
        % Find unique trials
        uniqTrialNo = unique(trialNo);
        nUniqTrial = length(uniqTrialNo);
        nTrialMC = floor( monteCarloPctTrain * nUniqTrial);
        
        % Select train and test trials
        idxTrialTrain = randperm(nUniqTrial, nTrialMC);
        idxTrialTest = 1:nUniqTrial; idxTrialTest(idxTrialTrain) = [];
        
        
        % trim Train/Test
        if ~isempty(nTrialTrain)
            maxTrialTrain = min( length(idxTrialTrain), nTrialTrain );
            idxTrialTrain = idxTrialTrain( 1:maxTrialTrain) ;
        end
        if ~isempty(nTrialTest)
            maxTrialTest = min( length(idxTrialTest), nTrialTest );
            idxTrialTest = idxTrialTest( 1:maxTrialTest) ;
        end
        
        % Sort
        idxTrialTrain = sort(idxTrialTrain,'ascend');
        idxTrialTest  = sort(idxTrialTest,'ascend');
        
        % Assign trialNos onto time stamps
        idxTrain = ismember(trialNo,idxTrialTrain);
        idxTest = ismember(trialNo,idxTrialTest);
        idxTrainTest  = {idxTrain, idxTest};
        
        
    case 'leaveOneOutTrial'
        
        if isempty(trialNo),  error('setup.crossValMethod %s need trialNumbers',crossValMethod), end
        uniqTrialNo = unique(trialNo);
        nUniqTrial = length(uniqTrialNo);
        
        quantileTrial = floor(linspace(1,nUniqTrial+1,kfold+1));
        %idxTrialTest  = quantileTrial(k):quantileTrial(k+1)-1 ;
        %idxTrialTrain  = 1:nUniqTrial; idxTrialTrain(idxTrialTest) = [];
        
        % Build up trials
        idxTrialTest = []; idxTrialTrain = [];
        nTrialTrain = floor(nTrialTrain/kfold)*kfold;
        for kk=1:kfold
            idxTrial = quantileTrial(kk):quantileTrial(kk+1)-1;
            if kk==k
                if ~isempty(nTrialTest)
                    maxTrial = min( length(idxTrial) , nTrialTest/kfold );
                    idxTrial = idxTrial( 1: maxTrial );
                end
                idxTrialTest = [idxTrialTest, idxTrial ];
            else
                if ~isempty(nTrialTrain)
                    maxTrial = min( length(idxTrial) , nTrialTrain/kfold );
                    idxTrial = idxTrial( 1: maxTrial );
                end
                idxTrialTrain = [idxTrialTrain, idxTrial];
            end
        end
        
        % Assign trialNos onto time stamps
        idxTrain = ismember(trialNo,uniqTrialNo(idxTrialTrain));
        idxTest  = ismember(trialNo,uniqTrialNo(idxTrialTest ));
        idxTrainTest  = {idxTrain, idxTest};
        
    case 'keepOneInTrial'
        
        if isempty(trialNo),  error('setup.crossValMethod %s need trialNumbers',crossValMethod), end
        uniqTrialNo = unique(trialNo);
        nUniqTrial = length(uniqTrialNo);
        quantileTrial = floor(linspace(1,nUniqTrial,kfold+1));
        %idxTrialTrain = quantileTrial(k):quantileTrial(k+1)-1 ;
        %idxTrialTest  = 1:nUniqTrial; idxTrialTest(idxTrialTrain) = [];
        
        % Build up trials
        idxTrialTest = []; idxTrialTrain = [];
        nTrialTrain = floor(nTrialTrain/kfold)*kfold;
        for kk=1:kfold
            idxTrial = quantileTrial(kk):quantileTrial(kk+1)-1;
            if kk==k
                if ~isempty(nTrialTrain)
                    maxTrial = min( length(idxTrial) , nTrialTrain/kfold );
                    idxTrial = idxTrial( 1: maxTrial );
                end
                idxTrialTrain = [idxTrialTrain, idxTrial ];
            else
                if ~isempty(nTrialTest)
                    maxTrial = min( length(idxTrial) , nTrialTest/kfold );
                    idxTrial = idxTrial( 1: maxTrial );
                end
                idxTrialTest = [idxTrialTest, idxTrial];
            end
        end
        
        
        % Assign trialNos onto time stamps
        idxTest     = ismember(trialNo,uniqTrialNo(idxTrialTest));
        idxTrain    = ismember(trialNo,uniqTrialNo(idxTrialTrain ));
        idxTrainTest  = {idxTrain, idxTest};
        
    otherwise
        error('crossvalMethod?')
end

end






%% Filter Predictors
function [pred, uniqPred] = selectPredictors(predictors, infoPredictors, infoPredSelect, uniqPredictors)

if ~iscell(infoPredSelect), error('infoPred should be array of cells'), end

% build predictor cell array
pred = cell(1,length(infoPredSelect));
clear uniqPred
for i=1:length(infoPredSelect)
    
    % extract the test [pred] out of the complete [predictors]
    if strcmp( {'None'}, infoPredSelect{i} )
        pred{i} = ones( size(predictors{1}) );
        uniqPred = {};
    else
        idx =  find( ismember( infoPredictors, infoPredSelect ) );
        if isempty(idx)
            error('name is not available in infoPredictors')
        else
            pred{i} = predictors{idx};
            if ~isempty(uniqPredictors)
                uniqPred{i} = uniqPredictors;
            else
                uniqPred{i} = unique(pred{i});
            end
        end
    end
end

end