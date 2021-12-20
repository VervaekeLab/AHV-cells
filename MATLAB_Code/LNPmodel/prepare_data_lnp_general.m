function [X,Y,idxY,infoY,classUnique] = prepare_data_lnp_general(session,rotate,hd,setup)
% Outputs
% X            : spikes
% Y            : class-categorical 
% idxY         : time bins used
% infoY        : name of predictor
% classUnique  : classes of Y

inputP = inputParser;
addRequired(inputP, 'session' )
addRequired(inputP, 'rotate'  )
addRequired(inputP, 'hd'      )
addRequired(inputP, 'setup'   )

%parse(inputP, session, rotate, hd, setup)
%v2struct(inputP.Results)



%% Choose spike or df/f
switch char(setup.dataType)
    case 'spike'
        display('spike data')
        X = transpose(double(session.spikemat)) ;
    case 'spikeSmooth'
        display('spike data smoothed')
        X = transpose(double(session.spikemat)) ;
        X = gaussSmooth(X, setup.spikeWindow,'normwindow',false);
    case 'dff'
        display('dfoverF data')
        X = transpose(double(session.dff)) ;
    case 'deconvolved'
        display('deconvolved')
        X = transpose(session.deconvolved) ;
    otherwise
        error('Invalid setup.dataType')
end

% add offset to improve performance
X = X + setup.spikeRateOffset;




%% Generate Classes

infoY = setup.predName;
clear classUnique
Y = cell(1,length(infoY));
classUnique1 = cell(1,length(infoY));
for iY = 1:length(infoY)
    
    clear Y1 classUnique1
    
    switch infoY{iY}
        case 'Rotation'
            Y1 = generate_class_rot(rotate);
            
        case 'HD'
            Y1 = generate_class_hd(hd);
            
        case {'Velocity','Velo','V'}
            Y1 = generate_class_velo(session,rotate,setup);
  
            
        case 'Acceleration'
            Y1 = generate_class_acceleration(session);
            
            
        case 'Activity'
            Y1 = generate_class_activity(X);
            

        %case {'HDV','combinedHDV','CombinedHDV'}
        %    Y1 = generate_class_combinedHDV(hd,rotate);
        
%         case {'HDxVelo','HDxV'}
%             YVelo = generate_class_velo(session,rotate,setup);
%             YHD   = generate_class_hd(hd);
%             uniqueVelo = unique(YVelo);
%             uniqueHD   = unique(YHD);
%             
%             clear Y1 classUnique1
%             k = 0;
%             for j = 1:length(uniqueHD)
%             for i = 1:length(uniqueVelo)
%                k=k+1;
%                classUnique1{iY}{k,1} = sprintf('HD %+04d V %+04d',round(uniqueHD(j)), uniqueVelo(i)  );
%                match = (YVelo == uniqueVelo(i)) & (YHD == uniqueHD(j));
%                Y1(match,1) = classUnique1(k);
%             end
%             end
            
        case 'pupilVelo'
            Y1 = generate_class_pupilVelo(session);
        
        case 'pupilReset'
            Y1 = generate_class_pupilReset(session);
            
        case 'time'
            Y1 = generate_class_time(session);
            
        otherwise
            error('what is info Y')
    end
    
    Y{iY} = Y1;
    
end



%% Generate idxY filters

% Use all
idxFilter = true( session.nSamples , 1 );

% Filter trial
if ~isempty(setup.filterVelo)
    trialNoFilterVelo = ismember( session.trialSummary.stageSpeed, setup.filterVelo );
    timeFilterTrialVelo = ismember(session.trialNo(:), find(trialNoFilterVelo));
    idxFilter( not(timeFilterTrialVelo) ) = 0;
end

% choose trial (rotation, head direction)
if ~setup.useStationary
    idxFilter(~rotate.moving(:)) = 0;
end

% choose rotation direction filters
switch setup.useTrials
    case 'CW'
        idxFilter(~rotate.clockwise) = 0;
    case 'CCW'
        idxFilter(~rotate.cclockwise) = 0;
    case {'all',''}
        % do nothing
    otherwise
        error('rotateFilter')
end


% % lights on / off
% switch setup.protocol
%     case 'lightsOn'
%         idxFilter ( not(session.lightsOn) ) = 0;
%     case 'lightsOff'
%         idxFilter (    (session.lightsOn) ) = 0;
%     otherwise
%         % use all
% end



% Check idxY
idxY = idxFilter(:);
for i=1:length(Y)
    if isnumeric(Y{i})
        isfinY = ~isnan(Y{i});
        %idxY = idxY & isfinY(:).'; 
        idxY(isnan(Y{i})) = 0;
        
    else
        %error('not numeric')
    end
   % sum(idxY)
   %[sum(idxY)]
end

% cutTime
if setup.cutTime
    fprintf(1,'cut time to shortest trial\n')
    uniqTrialNo = intersect( unique(session.trialNo), session.trialSummary.trialNo) ;
    
    clear P
     for i=1:length(uniqTrialNo)
        P(i) = sum( uniqTrialNo(i) == session.trialNo(idxY) );
     end
    %[P,~] = hist( session.trialNo(idxY), uniqTrialNo ) ;
    Pmin = min(P(P>0));
    for i=1:length(uniqTrialNo)
       fidxY  = find( uniqTrialNo(i) == session.trialNo );
       idxY( fidxY(Pmin+1:end) ) = 0;
    end
end





% % Downsampling
if setup.downsample 
    if setup.cutTime
        error('do not downsample and cutTime')
    end
    uniqTrialNo = intersect( unique(session.trialNo), session.trialSummary.trialNo) ;
    Xresample = []; Yresample = cell(size(Y)); idxYresample = logical([]);
    for i=1:length(uniqTrialNo)
        fidx  = find( uniqTrialNo(i) == session.trialNo );
        stageSpeed = session.trialSummary.stageSpeed(i);
        switch stageSpeed
            case 45, downsample  = 1;
            case 90,  downsample = 2;
            case 135, downsample = 3;
            case 180, downsample = 4;
        end
        ix = floor( [fidx(1) : 4/downsample : fidx(end)]' );
        
        idxYtmp = idxY(ix);
        idxYresample = vertcat(idxYresample,idxYtmp);
        
        Xtmp = resample( X(fidx,:),downsample,4);
        Xresample = vertcat(Xresample,Xtmp);
        for i=1:length(Y)
            if isnumeric(Y{i})
                Ytmp = resample( Y{i}(fidx,:),downsample,4);
            elseif ischar(Y{i})
                Ytmp = Y{i}( ix );
            end
            Yresample{i} = vertcat( Yresample{i}, Ytmp );
        end
    end
    
    idxY = idxYresample;
    X = Xresample;
    Y = Yresample;
end



% Label unused Y as NAN and gather unique classes
clear classUnique
for i=1:length(Y)
    if isnumeric(Y{i})
        Y{i}(~idxY) = nan;
    else
        Y{i}(~idxY) = {''};
    end
    classUnique{i,1} = sort( unique(Y{i}(idxY)) );
end

% Take classUnique after all filtering
%for iY=1:length(Y)
%     if ~isempty(classUnique1{iY})
%         classUnique{iY,1} = classUnique1{iY};
%     else
%        classUnique{iY,1} = sort( unique(Y{iY}(idxY)) );
%    end
%end

for i=1:length(Y)
display(classUnique{i}(:)')
 end

end 





%%% ----------------------------------------------------------------
%%%
%%% SUPPORTING FUNCTIONS 
%%%
%%% ----------------------------------------------------------------


function Y = generate_class_rot(rotate)

%Y = nan( session.nSamples, 1);
Y( rotate.clockwise )  = {'CW'};
Y( rotate.cclockwise ) = {'CCW'};
Y( rotate.stationary ) = {'Stationary'};
%infoY = {'Rotation'};
Y= Y(:);

end

%%% ----------------------------------------------------------------

function Y = generate_class_hd(hd)

Y = hd.binmiddle(hd.binidx);
Y = Y(:);
% infoY = {'HD'};

end

%%% ----------------------------------------------------------------


function Y =  generate_class_combinedHDV(hd,rotate)

YHD = hd.binmiddle(hd.binidx);
YAHV( rotate.clockwise )  = {'CW'};
YAHV( rotate.cclockwise ) = {'CCW'};
YAHV( rotate.stationary ) = {'Stationary'};
Y = cell(length(YHD),1);
for i=1:length(YHD)
   Y{i} = sprintf('%s %03d',YAHV{i},YHD(i)) ;
end
%Y = Y(:);
% infoY = {'HD'};

end

%%% ----------------------------------------------------------------

%    case 'conjunctiveBM'
%        Y{1} = hd.binmiddle(hd.binidx);
%        Y{2}(rotate.clockwise)  = +1 ; %{'CW'} ;
%        Y{2}(rotate.cclockwise) = -1 ; %{'CCW'};
%        absBM = abs(session.bodyMovement);
%        qval = 0.5;
%        Y{3}(absBM <= quantile(absBM,qval)) = 0;
%        Y{3}(absBM > quantile(absBM,qval)) = 1;
%        idxY = (isfinite(Y{1}(:)) & idxFilter);
%        infoY = {'HD','Rotation','BodyMovement'};

%%% ----------------------------------------------------------------

function Y = generate_class_velo(session,rotate,setup)


speedBinWidth = setup.speedBinWidth;
if isempty(setup.filterVelo)
    uniqVelo = [-180:speedBinWidth:180];
else
    uniqVelo = setup.filterVelo; 
end

if not(setup.useStationary)
    uniqVelo(uniqVelo==0) = [];
end

% use speed not velocity
if (setup.absoluteSpeed)
    uniqVelo = uniqVelo(uniqVelo>=0);
    session.velocity = abs(session.velocity); 
end

% makes edges that go a little over min/max velocity
edgesVelo = horzcat(uniqVelo - speedBinWidth/2, uniqVelo(end)+speedBinWidth/2);


[hBin,~,speedBin] = histcounts(session.velocity, edgesVelo);
Y = nan( session.nSamples, 1);
for i=1:length(uniqVelo)
    Y( speedBin==i ) = uniqVelo(i);
end

% if setup.useStageSpeed  % check with stageSpeed
%     
%     error('fix this') % ---------------------------------------------
%     
%     Y2 = Y;
%     
%     if ~isfield(session.trialSummary,'stageSpeed')
%         fprintf(1,'stageSpeed not available\n')
%         X=[]; Y=[]; idxY=[];
%         return
%     end
%     
%     uniqTrialNo = unique(session.trialSummary.trialNo);
%     uniqSpeed = unique(session.trialSummary.stageSpeed);
%     for k = 1:length(uniqTrialNo)
%         trialNo = uniqTrialNo(k);
%         speed = session.trialSummary.stageSpeed(k);
%         if setup.downsample
%             switch speed
%                 case 45, downsample=4;
%                 case 90, downsample=2;
%                 case 135, downsample=1;
%                 case 180, downsample=1;
%             end
%         else
%             downsample=1;
%         end
%         idxDownsample = mod(1:session.nSamples,downsample)==0;
%         Y(rotate.cclockwise & session.trialNo==trialNo & idxDownsample  ) = speed * (+1);
%         Y(rotate.clockwise  & session.trialNo==trialNo & idxDownsample  ) = speed * (-1);
%     end
%     
%     %if conflict, then remove
%     notMatch = ( Y ~= Y2 );
%     Y(notMatch) = nan;
%     
% %else % calculate stageSpeed self
%     
%     % display('Prepare data LNP: Make Speed Uniform')
%     % uniqTrialNo = (unique(session.trialNo));
%     % for i=1:length(uniqTrialNo)
%     %     idx = session.trialNo==uniqTrialNo(i);
%     %     medianVelocity = median(session.velocity(idx));
%     %     session.velocity(idx) = medianVelocity;
%     % end
%     
% end

end





%%% ----------------------------------------------------------------



function Y = generate_class_velo_continuous(session)

Y = session.velocity;

Y = Y(:);

end

%%% ----------------------------------------------------------------


function Y = generate_class_acceleration(session)

    Y = nan( session.nSamples, 1);
    % accelBinWidth = setup.speedBinWidth;
    % uniqAccel = [-90:speedBinWidth:90];
    % edgesVelo = horzcat(uniqVelo - accelBinWidth/2, uniqAccel(end)+accelBinWidth/2);
    % [hBin,~,speedBin] = histcounts(session.acceleration, edgesVelo);
    
    accThresh = 45;
    Y( session.acceleration <  -accThresh ) = -1 ; %{'CW'};
    Y( session.acceleration >= -accThresh & session.acceleration < accThresh  ) = 0; %{'Stationary'};    
    Y( session.acceleration >= +accThresh )  = +1 ; %{'CCW'};
    
    Y = Y(:);
    
end


%%% ----------------------------------------------------------------


function Y = generate_class_speed(session,setup)

Y = generate_class_velo(session,setup);
Y = abs(Y);
Y = Y(:);

end


%%% ----------------------------------------------------------------


function Y = generate_class_activity(X)

meanX = mean(X,2);
quanX = quantile(meanX, [0,0.25,0.5,0.75,1]);
[~,~,bin] = histcounts(meanX,quanX);
Y = quanX(bin);
Y= Y(:);

end

%%% ----------------------------------------------------------------



function Y = generate_class_pupilVelo(session)
% 
% pupil  = squeeze(session.pupilCenter(:,:,1));
% dpupil = [0, diff(pupil)];
% 
% quanX = quantile(dpupil, [0.05,0.5,0.75,1]);
% [~,~,bin] = histcounts(dpupil,quanX);
% 
% %Y = quanX(bin);
% uniqBin = unique(bin(bin>0)); 
% Y = nan(length(dpupil),1);
% for i=uniqBin(:)'
%     %Y(bin==i) = quanX(i); %
%     %%%%Y = Y(randperm(length(Y)));
%     %%%%Y(bin==i) = randi(length(uniqBin)); display('test random')
% end
% Y(bin==0) = nan;

error('not ready')

end


function Y = generate_class_pupilReset(session)

vPupilReset = velocityFromPupilReset(session);
vPupilThresh = quantile(abs(vPupilReset),0.8);

Y = zeros( length(vPupilReset),1);
Y( vPupilReset < -vPupilThresh ) = -2*vPupilThresh;
Y( vPupilReset > +vPupilThresh ) = +2*vPupilThresh;

Y = Y(:);

end

function Y = generate_class_time(session)

nbins = 10;
time = zeros( session.nSamples, 1);
uniqTrialNo = intersect( unique(session.trialNo), unique( session.trialSummary.trialNo ));
for i=1:length(uniqTrialNo)
    idxTrial = find( session.trialNo == uniqTrialNo(i) );
    time(idxTrial) = [0:length(idxTrial)-1] * session.dt;
end
maxTime = max(time);
edges = [ 0 : maxTime/nbins : maxTime ];

%uniqTrialSummary = structfun(@(x)unique(x),session.trialSummary, 'UniformOutput',false);
uniqRotatingCW = unique(session.trialSummary.rotatingCW);
uniqStageSpeed = unique(session.trialSummary.stageSpeed);

for i=1:length(uniqTrialNo)
    idxTrial = find( session.trialNo == uniqTrialNo(i) );
    for j=1:length(idxTrial)
        time(idxTrial)
    end
end

end

%% Shuffle time  (assuming independent data, for train/test purposes)
% idRandperm = [];
% if(param.shuffleTime)
%     display('Shuffle time before train/test')
%     idRandperm = randperm(length(Y));
%     X0 = X0(idRandperm,:);
%     Y  = Y(idRandperm);
% end





%%





function spikesSmooth = gaussSmooth(spikes, onestd, varargin)

inputP = inputParser;
addRequired(inputP, 'spikes')
addRequired(inputP, 'std1')   % one standard deviation in number of bins
addOptional(inputP, 'normwindow', true)
parse(inputP, spikes, onestd, varargin{:})
v2struct(inputP.Results)

threestd = onestd * 3; % three standard deviations
N = 2 * threestd;    % size of gaussian window
smoothWindow = gausswin( N );

if normwindow
    smoothWindow = smoothWindow / sum(smoothWindow);
end

spikesSmooth = convn(spikes,smoothWindow,'same');



end