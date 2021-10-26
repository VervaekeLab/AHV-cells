function [ pupilResetIdx, dpupil, pupil ] = markPupilReset(session, varargin)

inputP = inputParser;
addRequired(inputP, 'session')
addParameter(inputP, 'deltaT', 3) % how many intervals to get velocity
%addParameter(inputP, 'intv', 3)   % 
%addParameter(inputP, 'smoothdpupilSize',3)
addParameter(inputP, 'threshStdDPupil', 5)
addParameter(inputP, 'windowSize', 33)
addParameter(inputP, 'quantileReset', 0.95) % what percentile considered a fast reset
addParameter(inputP, 'quantileClass', 0.95) % what percentile to be discretized
addParameter(inputP, 'showPlots', false)
addParameter(inputP, 'showHistogram', false)
addParameter(inputP, 'removeConsecutive', true)
%addParameter(inputP, 'removeConsecutiveWindow', 0.2) % in seconds
addParameter(inputP, 'maxFrequency', 5) % in seconds
addParameter(inputP, 'useFindpeaks', false)
parse(inputP, session, varargin{:})
v2struct(inputP.Results)
p = inputP.Results;


%% Get pupil tracking and velocity

[pupil, dpupil] = get_pupil_data(session, 'deltaT',p.deltaT);


%%

% Find resets
%qAbsDPupil = quantile( abs(dpupilSmooth), quantileReset );
%pupilResetIdx = ( abs(dpupilSmooth) > qAbsDPupil );
%qAbsDPupil1 = quantile( abs(dpupilSmooth(dpupilSmooth>0)), quantileReset );
%qAbsDPupil2 = quantile( abs(dpupilSmooth(dpupilSmooth<0)), quantileReset );

% find st.d. without resets, mark resets as 3x std
idx = abs(dpupil) < quantile( abs(dpupil), quantileReset ) ; 
stdDPupil = nanstd( dpupil( idx ) );
thresh = threshStdDPupil * stdDPupil;
pupilResetIdx0 = abs(dpupil) > thresh;

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



% % Pupil reset start and end
% pupilResetIdx = pupilResetIdx0;
% idxReset = find(pupilResetIdx0);
% for i=1:length(idxReset)
%     %idxwindow = [idxReset(i) : idxReset(i)+intv];
%     %pupilResetStart = find( pupilResetIdx );
%      
%      idxstart = max( idxReset(i)-intv , 1 );
%      idxend   = min( idxReset(i)+intv , length(pupilResetIdx) );
%      idxwindow = [ idxstart : idxend ];
%      idxwindow(idxwindow < 1) = [];
%      idxwindow(idxwindow > length(pupilResetIdx)) = [];
%      [~, imax] = nanmax( abs(dpupilSmooth(idxwindow)) );   % find biggest displacement within interval
%      idxmax = idxwindow(imax);
%     % pupilResetIdx( idxwindow ) = 0;
%     % pupilResetIdx( idxmax ) = 1;
%     
%     dpupilsign = sign(dpupilSmooth(idxwindow));
%     
%     figure(99),
%     yyaxis left
%     
%     hold off
%     plot(idxwindow,dpupilSmooth(idxwindow))
%     hold all
%     plot(idxwindow(imax),dpupilSmooth(idxwindow(imax)),'o')
% 
%     yyaxis right
%     hold off
%     plot(idxwindow,sign(dpupilSmooth(idxwindow)))
%     ylim([-2,2])
%     pause
%     
% end
     
 

% 
% RemoveConsecutvive - Filter only the maximum change
pupilResetIdx = pupilResetIdx0;
if removeConsecutive  
    %intv = round( removeConsecutiveWindow / session.dt / 2 );
    intv =  1 / maxFrequency;
    intvbin = intv / session.dt ;
    idxReset = find(pupilResetIdx0);
    for i=1:length(idxReset)
        idxstart = max( idxReset(i)- round(intvbin/2) ); 
        idxend   = min( idxReset(i)+ round(intvbin/2) ); 
        idxwindow = [ idxstart : idxend ];
        idxwindow(idxwindow < 1) = [];
        idxwindow(idxwindow > length(pupilResetIdx)) = [];
        [~, imax] = nanmax( abs(dpupil(idxwindow)) );   % find biggest displacement within interval
        pupilResetIdx( idxwindow ) = 0;
        pupilResetIdx( idxwindow(imax) ) = 1; 
    end
    %pupilResetIdx = diff([pupilResetIdx 0])==1;
end
 
% use matlab findpeaks
if useFindpeaks
    intv =  1 / maxFrequency;
    intvbin = intv / session.dt ;
    [pks,locs] = findpeaks( abs(dpupil),'MinPeakDistance', intvbin, 'MinPeakHeight', thresh);
    pupilResetIdx = false(size(dpupil));
    pupilResetIdx(locs) = true;
end



if (showPlots || nargout==0)
    %%
    T = length(session.velocity);
    xaxis = [0:T-1] *session.dt; 
    
    hfig = figure();
    set(hfig, 'units','Normalized', 'outerposition', [0.2,0.2,0.6,0.6]); 
   
    
    subplot(2,1,1),
    %plot(xaxis,session.velocity),
    %legend({'velocity'})
    h1 = plot(xaxis,pupil, '.-');
    hold all
    plot(xaxis(pupilResetIdx),pupil(pupilResetIdx),'o','Color',h1.Color);
    grid minor, 
    legend({'velocity'})
    ax = gca;
  
    
    subplot(2,1,2),
    yyaxis left
    h1 = plot(xaxis,dpupil,'-.');
    hold all
    plot(xaxis(pupilResetIdx),dpupil(pupilResetIdx),'o','Color',h1.Color);
    hold all
    plot( [ xaxis(1), xaxis(end) ], thresh * -[1,1], 'k--')
    hold all
    plot( [ xaxis(1), xaxis(end) ], thresh * +[1,1], 'k--')
    hold all
    %x  = [ xaxis(1),xaxis(end) ];
    %plot(x,vPupilThresh*[-1,-1],'k--')
    %plot(x,vPupilThresh*[+1,+1],'k--')
    ymax = max(abs(dpupil));
    ylim([-ymax,ymax]*1.1)
    grid minor, 
   % yyaxis right
   % h2 = plot(xaxis,freqPupilReset,'LineWidth',2);
   % hold all
   % plot(x,[0,0],':','Color',h2.Color)
    %plot(xlim,vPupilThresh*[-1,-1],'k--')
    %plot(xlim,vPupilThresh*[+1,+1],'k--')
   % ymax = max(abs(freqPupilReset));
   % ylim([-ymax,ymax]*1.1)
   % grid minor, 
   % legend([h1],{'pupil movement','inferred velocity'})
   % legend([h1,h2],{'pupil movement','inferred velocity'})
    ax = [ax, gca]; 
    
    
   
    
    %subplot(2,2,[4]),
    %plot(session.velocity,vPupil, '.'),
    %xlabel('velocity')
    %ylabel('velocity(pupilReset)')
    
    linkaxes(ax,'x')
end

end
