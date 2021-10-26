function [hd] = head_direction(s,varargin)
% Calculate head direction after trimming with idxRoi and idxTime
% INPUT
% s    : session information containing
%   s.spikemat       : N x T-spike counts
%   s.stagePositions : 1 x T-head direction
% idxRoi  : index of selected cells
% idxTime : index of selected timestamps
%
% OUTPUT
% hd : structure containing
%    hd.ncells          : number of cells
%    hd.nsamples        : number of samples (time bins)
%    hd.stagePositions  : head direction
%    hd.frame           : frame of reference (0 to 360 / -180 to 180)
%    hd.binranges       : range of HD-bins
%    hd.binmiddle       : center of HD-bins
%    hd.binidx          : bin index of each cell
%    hd.bincount        : number of cells in bin i
%    hd.nspike, hd.nspike_1st, hd.nspike_2nd   : number of spikes (all/1st half/2nd half)
%    hd.occupancy       : time spent on particular bin
%
% handles : handles to figures

inputs = inputParser;
addRequired(inputs, 's')
addOptional(inputs, 'nbins'  , 60 )
addOptional(inputs, 'idxRoi' , 1:size(s.spikemat,1) )
addOptional(inputs, 'idxTime', 1:size(s.spikemat,2) )
%addOptional(inputs, 'hdParameterSet', [] )
addParameter(inputs, 'frame', [0,360], @(x)length(x)==2 ) %0, @(x)ismember(x,[0,-180,-360]) )  %start from 0 or -180 or -360
addParameter(inputs, 'hdcircular', true , @islogical)
addParameter(inputs, 'smoothNormalize', true , @islogical) 
addParameter(inputs, 'smoothStdDegree', 6)
addParameter(inputs, 'egocentric', false, @islogical) % egocentric time instead of allocentric
parse(inputs, s, varargin{:})

v2struct(inputs.Results)
%if ~isempty(hdParameterSet{1})
%    v2struct(hdParameterSet{1})
%    fprintf(1,'Parameters override with hdParameterSet\n')
%end

%% PREP

% % Create idxX and idxY if not given
% if nargin < 3
%     [N,T] = size(s.spikemat);
%     idxRoi = 1:N;
%     idxTime = 1:T;
% else
     if islogical(idxRoi), idxRoi = find(idxRoi); end
     if islogical(idxTime), idxTime = find(idxTime); end
     N = length(idxRoi);
     T = length(idxTime);
% end

if N==0
    fprintf(1,'Empty roi index\n')
    return,
end

% Trim the data
spikes = s.spikemat(idxRoi,idxTime);
head   = s.stagePositions(idxTime);

% Create struct
sessionMeta = session_meta(s);
hd.sessionID = s.sessionID;
hd.sessionMeta = sessionMeta;
hd.idxX      = idxRoi;
hd.idxY     = idxTime;
hd.ncells   = N;
hd.nsamples = T;
hd.frame    = frame;
hd.hdcircular = hdcircular;

if (1)
    persistent warning_hdframe
    if isempty(warning_hdframe)
        fprintf(1,'hd.frame = [%d %d]\n',hd.frame(1),hd.frame(2))
        warning_hdframe=0;
    end
end




%% HEAD DIRECTION BINNING
% Identify which cells go into each bin

if diff(hd.frame) == 180 && ( min(head) < min(hd.frame)  || max(head) > max(hd.frame) )
    fprintf(1, 'head_direction.m: hd.frame redefined \n')
    hd.frame = [ min(head), max(head)];
    %pause(0) %keyboard
end

% Unwrap angles
esc=0;
head = round(head); % round to degree
if diff(hd.frame) == 360
    while any( head < min(hd.frame) | head > max(hd.frame))
        idx = head < min(hd.frame);
        head(idx) = head(idx)+360;
        idx = head > max(hd.frame);
        head(idx) = head(idx)-360;
        esc = esc+1;
        if esc>100, warning('Stuck in loop')
            head(head < min(hd.frame)) = min(hd.frame);
            head(head > max(hd.frame)) = max(hd.frame);
        end
    end
end

hd.stagePositions = head;

% Place time indices into HD-bins
hd.nbins = nbins;
hd.binwidth = diff(hd.frame)/nbins;
hd.binmiddle = min(hd.frame) : hd.binwidth : max(hd.frame); 
hd.binranges = min(hd.frame)-hd.binwidth/2 : hd.binwidth : max(hd.frame)+hd.binwidth/2;
%hd.binranges = min(hd.frame) : hd.binwidth : max(hd.frame)+hd.binwidth;

if hd.hdcircular
    hd.binmiddle(end) = [];
    hd.binranges(end) = [];
end
hd.nbins = length(hd.binmiddle); nbins = hd.nbins;
%hd.binranges = linspace( min(hd.frame) , max(hd.frame), nbins+1);
%hd.binmiddle = (hd.binranges(2:end) + hd.binranges(1:end-1)) /2;
hd.binidx = zeros(1,numel(head),1);

for bin=1:hd.nbins
    
    % tweak so small negatives to zero is grouped into one
    idxTweak = head > (max(hd.frame)-(hd.binwidth/2));
    headTweak = head;
    headTweak(idxTweak) = head(idxTweak) - 360;
    
    idxT = (headTweak >= hd.binranges(bin)) & (headTweak <= hd.binranges(bin+1)) ;
    hd.binidx(idxT)  = bin;
    hd.bincount(bin) = sum(idxT);
end




%% TUNING CURVE
% Count the occupancy for each bin
% Count the spikes for each bin
% Divide spikecount by occupancy to get firing rate / tuning curve
for j=1:nbins
    
    % Sometimes add occupancy buffer > 0 to prevent divide by zeros.
    buffer = 0;
    
    % ALL
    idxT = (hd.binidx==j);
    hd.nspike(:,j) = sum(spikes(:,idxT),2);
    hd.occupancy(j) = (sum(idxT)+buffer) * s.dt;
    hd.firerate(:,j) = hd.nspike(:,j) ./ hd.occupancy(j) ;
    hd.reliability(:,j) = mean(spikes(:,idxT)>0,2);
    
    % First half
    idxT_1st = ([1 : T] < floor(T/2))  & idxT;
    hd.nspike_1st(:,j) = sum(spikes(:,idxT_1st),2);
    hd.occupancy_1st(j) = (sum(idxT_1st)+buffer) * s.dt;
    hd.firerate_1st(:,j) = hd.nspike_1st(:,j) ./ hd.occupancy_1st(j) ;
    hd.reliability_1st(:,j) = mean(spikes(:,idxT_1st)>0,2);
    
    % Second half
    idxT_2nd = ([1 : T] >= floor(T/2)+1 ) & idxT;
    hd.nspike_2nd(:,j) = sum(spikes(:,idxT_2nd),2);
    hd.occupancy_2nd(j) = (sum(idxT_2nd)+buffer) * s.dt;
    hd.firerate_2nd(:,j) = hd.nspike_2nd(:,j) ./ hd.occupancy_2nd(j) ;
    hd.reliability_2nd(:,j) = mean(spikes(:,idxT_2nd)>0,2);
    
end


%% SMOOTH THE TUNING CURVE

% Smoothing standard deviation
hd.smoothStdDegree = smoothStdDegree;                 % s.d. (degrees)

% create smoothing function by normalized Gaussian at sigma
% parameter alpha = (N � 1)/(2 sigma)
sigma = hd.smoothStdDegree/hd.binwidth; % s.d. in bins
nwin = round(sigma*10+1) ;     % make filter wide enough

%alpha = (nwin-1) / (2* sigma);
%smoothwin = gausswin(nwin,alpha);
nw = -(nwin-1)/2 : (nwin-1)/2;
smoothwin = exp(-nw .* nw / (2 * sigma * sigma))';
if smoothNormalize
    smoothwin = smoothwin/sum(smoothwin);  % DON'T normalize to prevent clipping
end
%figure, bar( [-(nwin-1)/2:(nwin-1)/2]*hd.binwidth,  smoothwin )
%xlim([-24,24])

for j=1:N
    
    if hdcircular
        % expand sides so smoothing is circular
        %idx = [ 1:hd.nbins , 1:hd.nbins, 1:hd.nbins ];
        firerate_expand = repmat(hd.firerate(j,:),1,3); 
        firerate_1st_expand = repmat(hd.firerate_1st(j,:),1,3); 
        firerate_2nd_expand = repmat(hd.firerate_2nd(j,:),1,3); 
        reliability_expand = repmat(hd.reliability(j,:),1,3); 
        reliability_1st_expand = repmat(hd.reliability_1st(j,:),1,3); 
        reliability_2nd_expand = repmat(hd.reliability_2nd(j,:),1,3); 
    else
        % expand sides with zeros
        %idx = [ zeros(1,nbins), 1:hd.nbins, zeros(1,nbins) ];
        firerate_expand     =  [ zeros(1,nbins) ,  hd.firerate(j,:)     , zeros(1,nbins)] ; 
        firerate_1st_expand =  [ zeros(1,nbins) ,  hd.firerate_1st(j,:) , zeros(1,nbins)] ; 
        firerate_2nd_expand =  [ zeros(1,nbins) ,  hd.firerate_2nd(j,:) , zeros(1,nbins)] ; 
        reliability_expand     =  [ zeros(1,nbins) ,  hd.reliability(j,:)     , zeros(1,nbins)] ; 
        reliability_1st_expand =  [ zeros(1,nbins) ,  hd.reliability_1st(j,:) , zeros(1,nbins)] ; 
        reliability_2nd_expand =  [ zeros(1,nbins) ,  hd.reliability_2nd(j,:) , zeros(1,nbins)] ; 
        
    end
    % smooth
    z = conv( firerate_expand, smoothwin , 'same');
    hd.smoothrate(j,:) = z( hd.nbins+1 : hd.nbins*2 ); % pick up the middle
    z = conv( reliability_expand, smoothwin , 'same');
    hd.smoothreliability(j,:) = z( hd.nbins+1 : hd.nbins*2 ); % pick up the middle
    
    % 1st half
    z = conv( firerate_1st_expand, smoothwin , 'same');
    hd.smoothrate_1st(j,:) = z( hd.nbins+1 : hd.nbins*2 );
    z = conv( reliability_1st_expand, smoothwin , 'same');
    hd.smoothreliability_1st(j,:) = z( hd.nbins+1 : hd.nbins*2 );
    
    % 2nd half
    z = conv( firerate_2nd_expand, smoothwin , 'same');
    hd.smoothrate_2nd(j,:) = z( hd.nbins+1 : hd.nbins*2 );
    z = conv( reliability_2nd_expand, smoothwin , 'same');
    hd.smoothreliability_2nd(j,:) = z( hd.nbins+1 : hd.nbins*2 );
    
end


% Check actual firerate and smoothed
if (0)
    for n = 1:N
        h1 = figure('Name','FireRateSmoothing');
        handles = [ handles, h1 ];
        t1 = hd.binmiddle([1:end,1]) *2*pi/360;
        r1 = hd.firerate(n,[1:end,1]);
        subplot(1,2,1)
        polarplot( t1 ,r1 )
        t1 = hd.binmiddle([1:end,1]) *2*pi/360;
        r1 = hd.smoothrate(n,[1:end,1]);
        subplot(1,2,2)
        polarplot( t1 ,r1 )
        %pause()
    end
end


%% STABILITY 1st HALF 2nd HALF
for n = 1:N
    C = corrcoef(hd.smoothrate_1st(n,:),hd.smoothrate_2nd(n,:));
    hd.stability(n,1) = C(1,2);
end



%% CALCULATE HD-Index
% Normalize Smoothrate by sum of Smoothrate for all bins
% Decompose Smoothrate into vector of Head Direction and sum into one mean vector
% Calculate the length of sum vector
for n = 1:N
    
    % HD Score All
    hd.meanvec(n,:)   = hd.smoothrate(n,:)/sum(hd.smoothrate(n,:)) * [ cosd(hd.binmiddle(:)) , sind(hd.binmiddle(:)) ] ;
    hd.hdscore(n,1)   = sqrt(sum(hd.meanvec(n,:).^2,2));
    hd.prefangle(n,1) = atan2d( hd.meanvec(n,2), hd.meanvec(n,1) );
    
    % HD Score 1st half
    hd.meanvec_1st(n,:)   = hd.smoothrate_1st(n,:)/sum(hd.smoothrate_1st(n,:)) * [ cosd(hd.binmiddle(:)) , sind(hd.binmiddle(:)) ] ;
    hd.hdscore_1st(n,1)   = sqrt(sum(hd.meanvec_1st(n,:).^2,2));
    hd.prefangle_1st(n,1) = atan2d( hd.meanvec_1st(n,2), hd.meanvec_1st(n,1) );
    
    % HD Score 2nd half
    hd.meanvec_2nd(n,:)   = hd.smoothrate_2nd(n,:)/sum(hd.smoothrate_2nd(n,:)) * [ cosd(hd.binmiddle(:)) , sind(hd.binmiddle(:)) ] ;
    hd.hdscore_2nd(n,1)   = sqrt(sum(hd.meanvec_2nd(n,:).^2,2));
    hd.prefangle_2nd(n,1) = atan2d( hd.meanvec_2nd(n,2), hd.meanvec_2nd(n,1) );
    
end

% Put mean vector inside hd.frame

ix = hd.prefangle < min(hd.frame);
hd.prefangle( ix ) = hd.prefangle( ix ) + 360;

ix = hd.prefangle_1st < min(hd.frame);
hd.prefangle_1st( ix ) = hd.prefangle_1st( ix ) + 360;

ix = hd.prefangle_2nd < min(hd.frame);
hd.prefangle_2nd( ix ) = hd.prefangle_2nd( ix ) + 360;

ix = hd.prefangle > max(hd.frame);
hd.prefangle( ix ) = hd.prefangle( ix ) - 360;

ix = hd.prefangle_1st > max(hd.frame);
hd.prefangle_1st( ix ) = hd.prefangle_1st( ix ) - 360;

ix = hd.prefangle_2nd > max(hd.frame);
hd.prefangle_2nd( ix ) = hd.prefangle_2nd( ix ) - 360;




%% INFORMATION Skaggs McNaughton
% I_neuron = sum_x lambda(x) log2(lambda(x)/lambda0) p(x)

px = hd.bincount / sum(hd.bincount);
lambdax = hd.firerate;
lambda0 = mean(spikes,2) ./ s.dt;
for n=1:N
    idbin = lambdax(n,:)>0;
    ISkaggs(n,1) = lambdax(n,idbin) * (log2( lambdax(n,idbin) / lambda0(n)) .* px(idbin))';
    if isnan(ISkaggs(n)), error('NaN found in entropy'), end
end
hd.ISkaggs = ISkaggs;


%1st half
lambdax = hd.firerate_1st;
idx = 1 : floor(T/2);
lambda0 = mean(spikes(:,idx),2) ./ s.dt;
for n=1:N
    idbin = lambdax(n,:)>0;
    ISkaggs_1st(n,1) = lambdax(n,idbin) * (log2( lambdax(n,idbin) / lambda0(n)) .* px(idbin))';
    if isnan(ISkaggs(n)), error('NaN found in entropy'), end
end
hd.ISkaggs_1st = ISkaggs_1st;

%2nd half
lambdax = hd.firerate_2nd;
idx = floor(T/2)+1 : T;
lambda0 = mean(spikes(:,idx),2) ./ s.dt;
for n=1:N
    idbin = lambdax(n,:)>0;
    ISkaggs_2nd(n,1) = lambdax(n,idbin) * (log2( lambdax(n,idbin) / lambda0(n)) .* px(idbin))';
    if isnan(ISkaggs(n)), error('NaN found in entropy'), end
end
hd.ISkaggs_2nd = ISkaggs_2nd;

