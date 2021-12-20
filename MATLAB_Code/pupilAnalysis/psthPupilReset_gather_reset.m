%% 


function [  nReset, tWindow, PSTH, ...
    trialNo, trialSpeed, trialVelocity , meanDeconvPupil, stdDeconvPupil, seDeconvPupil, ...
    yquantile, ymean0, ymean0margin, ypass, pmean0, pmean0margin, pupilCell, pupilCellShuffle, statsShuffle ] = ...
    psthPupilReset_gather_reset( pupilResetIdx, pupil, dpupil, intv, tmargin, pthresh, session)


fPupilResetIdx = find(pupilResetIdx);

deconv = session.deconvolved;

Nw = 21;
stdms = 100; % 100ms
stdbin = stdms/1000 / session.dt;
%stdev = (N-1)/(2*alpha);
alpha = (Nw-1)/(2*stdbin);
w = gausswin(Nw,alpha);
deconvSmooth = filter(w,1,deconv')';


nReset =  length(fPupilResetIdx);
tWindow = length( [ -intv : +intv ] );
DeconvPupilMat = nan( nReset, tWindow, session.nRois );
DeconvPupilOriginalMat = nan( nReset, tWindow, session.nRois );
dPupilMat = nan(  nReset, tWindow );
pupilMat  = nan(  nReset, tWindow );
pupilResetMat  = nan(  nReset, tWindow );
bodyMovementMat  = nan(  nReset, tWindow );
lickResponsesMat  = nan(  nReset, tWindow );
velocityMat  = nan(  nReset, tWindow );
accelerationMat  = nan(  nReset, tWindow );
trialNo  = nan(  nReset,1 );
trialSpeed  = nan(  nReset,1 );
trialVelocity  = nan(  nReset,1 );

for i=1:length(fPupilResetIdx)
    
    f = fPupilResetIdx(i);
    
    % create vector of time around pupilReset,
    % make nan to parts which exceeds boundaries
    timeidx = f + [ -intv : +intv ] ;
    timeidx( timeidx < 1 ) = nan;
    timeidx( timeidx > session.nSamples ) = nan;
    %timeidx( ismember(timeidx, find(session.rotatingplus)) ) = nan;  % make to nan parts close to rotation?
    
    % fill in deconvPupil
    isfin = isfinite( timeidx ) ;
    for n=1:session.nRois
        DeconvPupilMat(i, isfin  ,n) =  deconvSmooth(n, timeidx(isfin)) ;
        DeconvPupilOriginalMat(i, isfin  ,n) =  deconv(n, timeidx(isfin)) ;
    end
    
    trialNo(i) = session.trialNo(f);
    if trialNo(i)==0
        trialSpeed(i) = 0;
        trialVelocity(i) = 0;
    else
        trialSpeed(i) = session.trialSummary.stageSpeed(trialNo(i));
        rotatingCW = session.trialSummary.rotatingCW(trialNo(i));
        if (rotatingCW),  trialVelocity(i) = trialSpeed(i) * -1;
        else,             trialVelocity(i) = trialSpeed(i) * +1;
        end
    end
    
    dPupilMat(i, isfin )        = dpupil(timeidx(isfin));
    pupilMat(i, isfin )         = pupil(timeidx(isfin));
    pupilResetMat(i, isfin )    = pupilResetIdx(timeidx(isfin));
    bodyMovementMat(i, isfin )  = session.bodyMovement(timeidx(isfin));
    lickResponsesMat(i, isfin ) = session.lickResponses(timeidx(isfin));
    velocityMat(i,isfin)        = session.velocity(timeidx(isfin));
    accelerationMat(i,isfin)    = session.acceleration(timeidx(isfin));
    
end

PSTH = v2struct( DeconvPupilMat, ...
    DeconvPupilOriginalMat, ...
    dPupilMat, ...
    pupilMat, ...
    pupilResetMat, ...
    bodyMovementMat, ...
    lickResponsesMat, ...
    velocityMat, ...
    accelerationMat  );



%% PEAK ABOVE 95

pthreshvec = logspace(-3,0,20);
clear meanDeconvPupil stdDeconvPupil seDeconvPupil yquantile ymean0 pmean0 pmean0margin
margin = ceil( tmargin/1000 / session.dt);
for n=1:session.nRois
    meanDeconvPupil(n,:) = nanmean( DeconvPupilMat(:,:,n) , 1 ) ;
    stdDeconvPupil(n,:)  = nanstd( DeconvPupilMat(:,:,n), [], 1 ) ;
    seDeconvPupil(n,:)   = stdDeconvPupil(n,:) / sqrt(size(DeconvPupilMat,1))  ;
    yquantile(n,:) = quantile(meanDeconvPupil(n,:), 1-pthreshvec);
    ymean0(n,1)    = meanDeconvPupil(n, (intv+1) );  % pick the middle
    pmean0(n,1)    = mean( ymean0(n) < meanDeconvPupil(n,:) ) ;
end

%time  margin to check for pupil cell
ymean0margin  = meanDeconvPupil(:, intv+[1:margin] );

for n=1:session.nRois
    pmean0margin(n,1)    = mean( max(ymean0margin(n,:),[],2) < meanDeconvPupil(n,:) ) ;
end
[~, ixcol] = min( abs(pthresh - pthreshvec) );
ypass = yquantile( :, ixcol );
pupilCell = any( ymean0margin > ypass , 2) ;
%fprintf(1,'#pupil resets: %d, mean pupil-tuned cell: %.2f%%\n', length(fPupilResetIdx), mean(pupilCell) * 100 )
fprintf(1,'#pupil resets: %d, mean pupil-tuned cell: %.2f%%\n', length(fPupilResetIdx), mean(pupilCell) * 100 )


%% SHUFFLE

% create big shuffled deconvolved data

%timeShiftMax = intvT ;%1000; % ms
%binShiftMax = ceil( (timeShiftMax/1000)/session.dt );
binShiftMax = 2*intv;

clear DeconvMeanData DeconvMeanShuffle
nIter = 500;
%DeconvPupilShuffle = zeros( [size(DeconvPupilMat) , nIter ]);
DeconvMeanShuffle = zeros( session.nRois, tWindow, nIter );
fprintf(1,'Shuffling..\n')

Dtmp = zeros( nReset, tWindow, session.nRois );
for iter = 1:nIter
   if mod(iter,50)==0, fprintf(1,'%d / %d\n',iter, nIter), end
   rounding = 1;
   shif = randperm( ceil(binShiftMax/rounding), nReset) * rounding;
%    for iR = 1:nReset
%        DeconvPupilShuffle(iR,:,:,iter) = circshift( DeconvPupilMat(iR,:,:) , [0 shif(iR) 0]);
%    end
   for iR = 1:nReset
       Dtmp(iR,:,:) = circshift( squeeze(DeconvPupilMat(iR,:,:)) , [0 shif(iR)]);
   end
   DeconvMeanShuffle(:,:, iter) = transpose( squeeze( nanmean(Dtmp,1) )); 
end
%DeconvMeanShuffle = permute( squeeze(nanmean(DeconvPupilShuffle,1)), [2 1 3]  ) ; %nRois, tWindow, nIter
% average deconvolved data over pupil resets
DeconvMeanData = transpose( squeeze(nanmean(DeconvPupilMat,1)) ); 



qthresh = 1-pthresh;
qthreshvec = 1-pthreshvec;

% compare data and shuffle
idx = intv+[1:margin];
clear scoreData scoreShuffle scorePercentile scoreQuantile
for n=1:session.nRois
    scoreData(n,1)      = max( DeconvMeanData(n,idx),[],2 )  ;
    scoreShuffle(n,:)   = squeeze( max( DeconvMeanShuffle(n,idx,:),[],2) );
    
    %scoreData(n,1)      = max( DeconvMeanData(n,idx),[],2 ) /   nanmean( DeconvMeanData(n,:),2 ) ;
    %scoreShuffle(n,:)   = squeeze( max( DeconvMeanShuffle(n,idx,:),[],2) )  ./ squeeze( nanmean( DeconvMeanShuffle(n,:,:),2) ) ;
    scorePercentile(n,1) = mean(scoreData(n) > scoreShuffle(n,:));
    quantile95(n)  = quantile(scoreShuffle(n,:), 0.95);
    quantile99(n)  = quantile(scoreShuffle(n,:), 0.99);
    quantile999(n)  = quantile(scoreShuffle(n,:), 0.999);
    %quantileDeconvPupilShuffle(n,:) = quantile( squeeze(DeconvMeanShuffle(n,:,:)) , qthresh, 2 ) ;
    quantileDeconvPupilShuffle(n,:) = quantile( scoreShuffle(n,:) , qthresh ) ;
    
    scoreQuantile(n,:) = quantile( scoreShuffle(n,:), 1-pthreshvec );
end

pupilCellShuffle = scorePercentile(:) > qthresh;
statsShuffle = v2struct( scoreData, scoreShuffle, scorePercentile, scoreQuantile, quantile95,quantile99,quantile999, qthresh, pupilCellShuffle,  quantileDeconvPupilShuffle );

fprintf(1,'pupilCell: %.2g%%\n', mean(pupilCellShuffle)*100 )

%%

fprintf(1,'done\n')
pause(0)