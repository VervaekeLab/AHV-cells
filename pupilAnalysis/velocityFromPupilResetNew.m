function [freqPupilReset, pupilResetIdx, dpupilSmooth, pupil] = velocityFromPupilResetNew(session, varargin)

inputP = inputParser;
addRequired(inputP, 'session')
addParameter(inputP, 'smoothdpupilSize',3)
addParameter(inputP, 'threshStdDPupil', 4)
addParameter(inputP, 'windowSize', 33)
addParameter(inputP, 'quantileReset', 0.95) % what percentile considered a fast reset
addParameter(inputP, 'quantileClass', 0.95) % what percentile to be discretized
addParameter(inputP, 'showPlots', false)
addParameter(inputP, 'removeConsecutive', true)
addParameter(inputP, 'removeConsecutiveWindow', 0.2) % in seconds
parse(inputP, session, varargin{:})
v2struct(inputP.Results)

% Get pupil tracking and velocity
pupil  = squeeze(session.pupilCenter(:,:,1)); pupil(pupil==0)=nan;
velocity = session.velocity;
stagePositions = session.stagePositions;
rotationLength = session.trialSummary.rotationLength;

% Normalize to a range [0,1]
pupil = normalize(pupil, 'range');
%pupil = 2*pupil -1; % from [0,1] to [-1,1]
pupil = pupil - nanmedian(pupil);

% Get velocity
dpupil = [0, diff(pupil)];
%b = (1/smoothdpupilSize)*ones(1,smoothdpupilSize);
%a = 1;
%dpupilSmooth = filter(b,a,dpupil);
%dpupilSmooth = smooth(dpupil, smoothdpupilSize)';
dpupilSmooth = (dpupil); fprintf(1,'no smoothing dpupil\n');

% Find resets
%qAbsDPupil = quantile( abs(dpupilSmooth), quantileReset );
%pupilResetIdx = ( abs(dpupilSmooth) > qAbsDPupil );
%qAbsDPupil1 = quantile( abs(dpupilSmooth(dpupilSmooth>0)), quantileReset );
%qAbsDPupil2 = quantile( abs(dpupilSmooth(dpupilSmooth<0)), quantileReset );

% find st.d. without resets, mark resets as 3x std
qAbsDPupil = quantile( abs(dpupilSmooth), quantileReset );
idx = abs(dpupilSmooth) < qAbsDPupil ; 
stdDPupil = nanstd( dpupilSmooth( idx ) );
thresh = threshStdDPupil * stdDPupil;
pupilResetIdx0 = abs(dpupilSmooth) > thresh ;

% % Filter only the last of consecutive 1s
% if removeConsecutive
%     idx = find(pupilResetIdx);
%     intv = 1;
%     for i=1:intv
%         %idx1 = max( 1, idx - i );
%         idx1 = min( idx + i , length(pupilResetIdx) );
%         pupilResetIdx( idx1 ) = 0;
%     end
%     %pupilResetIdx = diff([pupilResetIdx 0])==1;
% end

% RemoveConsecutvive - Filter only the maximum change
pupilResetIdx = pupilResetIdx0;
if removeConsecutive  
    intv = round( removeConsecutiveWindow / session.dt / 2 );
    idxReset = find(pupilResetIdx0);
    for i=1:length(idxReset)
        idxstart = max( idxReset(i)-intv ); 
        idxend   = min( idxReset(i)+intv ); 
        idxwindow = [ idxstart : idxend ];
        idxwindow(idxwindow < 1) = [];
        idxwindow(idxwindow > length(pupilResetIdx)) = [];
        [~, imax] = nanmax( abs(dpupilSmooth(idxwindow)) );   % find biggest displacement within interval
        idxmax = idxwindow(imax);
        pupilResetIdx( idxwindow ) = 0;
        pupilResetIdx( idxmax ) = 1; 
    end
    %pupilResetIdx = diff([pupilResetIdx 0])==1;
end

 

% Mark resets
dpupilReset = zeros(size(dpupilSmooth));
%dpupilReset(pupilResetIdx) = dpupil(pupilResetIdx);
dpupilReset(pupilResetIdx) = sign(dpupilSmooth(pupilResetIdx));


% Velocity ignoring resets (susceptible to false negatives)
% dpupilNoReset = dpupil;
% dpupilNoReset(pupilResetIdx) = 0;
% pupilNoReset = pupil(1) + cumsum(dpupilNoReset,'omitnan');


% Turn resets into a velocity by smoothing
%smoothfactor = 133; %66;
%freqPupilReset = smooth(dpupilReset,windowSize)';
b = (1/windowSize)*ones(1,windowSize);
a = 1;
freqPupilReset = filter(b,a,dpupilReset) / session.dt;

% Set velocity classes
%vPupilThresh = quantile(abs(vPupil),0.5);
vPupilThresh = nanmean(abs(freqPupilReset));
Y = zeros(size(freqPupilReset));
Y( freqPupilReset < -vPupilThresh ) = -vPupilThresh*2;
Y( freqPupilReset > +vPupilThresh ) = +vPupilThresh*2;


if (showPlots || nargout==0)
    %%
    T = length(session.velocity);
    xaxis = [0:T-1] *session.dt; 
    
    figure
    subplot(2,2,1),
    plot(xaxis,session.velocity),
    
    grid minor, 
    legend({'velocity'})
    ax1 = gca;
    
    
    
    subplot(2,2,2),
    yyaxis left
    h1 = plot(xaxis,dpupilSmooth,'-');
    hold all
    plot(xaxis(pupilResetIdx),dpupilSmooth(pupilResetIdx),'o','Color',h1.Color);
    hold all
    plot( [ xaxis(1), xaxis(end) ], thresh * -[1,1], 'k--')
    hold all
    plot( [ xaxis(1), xaxis(end) ], thresh * +[1,1], 'k--')
    hold all
    x  = [ xaxis(1),xaxis(end) ];
    plot(x,vPupilThresh*[-1,-1],'k--')
    plot(x,vPupilThresh*[+1,+1],'k--')
    ymax = max(abs(dpupilSmooth));
    ylim([-ymax,ymax]*1.1)
    grid minor, 
    yyaxis right
    h2 = plot(xaxis,freqPupilReset,'LineWidth',2);
    hold all
    plot(x,[0,0],':','Color',h2.Color)
    %plot(xlim,vPupilThresh*[-1,-1],'k--')
    %plot(xlim,vPupilThresh*[+1,+1],'k--')
    ymax = max(abs(freqPupilReset));
    ylim([-ymax,ymax]*1.1)
    grid minor, 
    legend([h1,h2],{'pupil movement','inferred velocity'})
    ax2 = gca; 
    
    
    subplot(2,2,3),
    %yyaxis left
    h1 = plot(xaxis,freqPupilReset,'-');
    hold all
    ymax = max(abs(freqPupilReset));
    ylim([-ymax,ymax]*1.5)
    grid minor, 
    %%yyaxis right
    h2 = plot(xaxis,Y,'LineWidth',1);
    x  = [ xaxis(1),xaxis(end) ];
    plot( x , vPupilThresh*[-1,-1],'k--')
    plot( x , vPupilThresh*[+1,+1],'k--')
    ymax = max(abs(Y));
    ylim([-ymax,ymax]*1.5)
    grid minor, 
    legend([h1,h2],{'velocity inferred from pupil resets','quantized'})
    ax3 = gca;   
    
    
    
    subplot(2,2,[4]),    
    yyaxis left
    h1 = plot( xaxis,session.velocity);
    ymax = max(abs(session.velocity));
    ylim([-ymax,ymax]*1.5)
    yyaxis right
    h2 = plot( xaxis, Y );
    hold all
    plot(x,[0,0],':','Color',h2.Color)
    ymax = max(abs(Y));
    ylim([-ymax,ymax]*1.5)
    hold all
    grid minor, 
    legend([h1,h2],{'velocity','velocity(pupilReset)'})
    ax4 = gca;
    
    %Link subplots,
    linkaxes([ax1,ax2,ax3,ax4],'x')
    xlim([0,300])
    
    %subplot(2,2,[4]),
    %plot(session.velocity,vPupil, '.'),
    %xlabel('velocity')
    %ylabel('velocity(pupilReset)')
end

end
