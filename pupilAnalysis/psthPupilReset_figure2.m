%function [hfig2]  = psthPupilReset_figure2( pupilCellShuffle, fPupilResetIdx, intv, nShowPlots, ...
%    PSTH, meanDeconvPupil, stdDeconvPupil,seDeconvPupil, session, hfig2 , plotOnlySignificant, ...
%    tag1, pthresh, pmean0margin,statsShuffle, useImagesc, tmargin,noutplot)
function [hfig2] = psthPupilReset_figure2( pupilCellShuffle, fPupilResetIdx, intv, nShowPlots, ...
        PSTH, meanDeconvPupil, stdDeconvPupil,seDeconvPupil, session, hfig2 , plotOnlySignificant, ...
        tag1, pthresh, statsShuffle , useImagesc, tmargin, noutplot)
    

tracesMode = false;
nShowPlots = 12;
if isempty(noutplot)
    noutplot = [1 : session.nRois];
end
switch plotOnlySignificant
    case 0
        noutplot = noutplot;
    case 1
        findh = find(pupilCellShuffle);
        noutplot = intersect( findh, noutplot );
    case 2
        findh = find(pupilCellShuffle);
        noutplotPupil = intersect( noutplot, findh );
        findh = find(~pupilCellShuffle);
        noutplotNoPupil = intersect( noutplot, findh );

        %noutplot = [noutplotNoPupil(1); noutplotPupil(2)];
        noutplotPupil   = noutplotPupil(1: min(2,length(noutplotPupil)) );
        noutplotNoPupil = noutplotNoPupil(1: 3 );
        noutplot = [noutplotPupil(:) ; noutplotNoPupil(:)];   
    otherwise
        error('wrong switch')
end
%noutplot =  unique([1; noutplot(:)],'stable');  % the first is a simulation
t = [ -intv : +intv ] * session.dt;




%% Setup figure properties
if isempty(hfig2)
    hfig2 = figure( 'Units','normalized', 'OuterPosition', [0.1,0.1,0.4,0.8] );
end
figure(hfig2)
ncols = 2;
nsp = nShowPlots;
nrows = ceil(nsp/ncols);
xl = [-intv, intv] * session.dt; xticks = [-5:1:5];


%% Pupil velocity
subplot( nrows,ncols,1)  %1st col, 1st row
A = PSTH.dPupilMat;
ymean = nanmean( A,1);
ystd = nanstd( A,[],1);
yse  = ystd / sqrt(size(A,1));
if(~tracesMode)
    htmp = shadedErrorBar(t,ymean,yse);
    h4 = htmp.mainLine;
else
    warning('debug mode\n')
    plot(t,A,'Color', 0.8*[1,1,1])
    hold all
    h4 = plot(t,nanmean(A,1),'-','Color', 0.0*[1,1,1]);
end
hold all
yl = ylim;
plot([0,0],yl, 'Color', 0.5* [1,1,1])
ylim(yl)
xlim( xl )
title('Pupil velocity')
ylabel('Velocity (a.u.)')
set(gca, 'XTick',xticks ) , % grid on
plot([-0.5,-0.5], yl,'Color', 0.5*[1,1,1])
box off
p = patch( [-0.5, -0.5, 0, 0 ], [min(ylim) max(ylim) max(ylim) min(ylim)], 0.8* [1,1,1], 'FaceAlpha',0.5, 'LineStyle','none');


axes('Position', [.4, .95, .1, 0.075])
plot(xl,[0,0],'Color', 0.0*[1,1,1])
hold all
plot([0,0], yl,'Color', 0.5*[1,1,1])
hold all
plot([-0.5,-0.5], yl,'Color', 0.5*[1,1,1])
hold all
plot(t,nanmean(A,1),'-','Color', 0.0*[1,1,1]);
hold all
p = patch( [-0.5, -0.5, 0, 0 ], [min(ylim) max(ylim) max(ylim) min(ylim)], 0.8* [1,1,1], 'FaceAlpha',0.5, 'LineStyle','none');
ylim(yl)
xlim([-0.6,0.1] )
set(gca, 'XTick', [-0.5,0] )
box off


%% Velocity Profile
subplot( nrows,ncols,1 + ncols*1)  %1st col, 2nd row
A = PSTH.velocityMat;
ymean = nanmean( A,1);
ystd = nanstd( A,[],1);
yse  = ystd / sqrt(size(A,1));
if(~tracesMode)
    htmp = shadedErrorBar(t,ymean,yse);
    h4 = htmp.mainLine;
else
    warning('debug mode\n')
    plot(t,A,'Color', 0.8*[1,1,1])
    hold all
    h4 = plot(t,nanmean(A,1),'-','Color', 0.0*[1,1,1]);
end
hold all
ylim([-150,150])
yl = ylim;
plot([0,0],yl, 'Color', 0.5* [1,1,1])
ylim(yl)
xlim( xl )
title('Angular velocity')
ylabel( sprintf('Velocity (%s/s)', char(176)) )
set(gca, 'XTick',xticks )
box off


%% Mean Pupil Activity
subplot( nrows,ncols, 1 + ncols*2)  %1st col, 3rd row
A = nanmean(PSTH.DeconvPupilMat(:,:,:),3) ;  
ymean = nanmean( A,1);  
ystd = nanstd( A,[],1); 
yse  = ystd / sqrt(size(A,1));
htmp = shadedErrorBar(t,ymean,yse);
h4 = htmp.mainLine;
hold all
yl = ylim;
plot([0,0],yl, 'Color', 0.5* [1,1,1])
xlim(xl )
title('Neural activity')
ylabel('Rate (a.u.)')
set(gca, 'XTick',xticks ) 
xlabel('Time(s)')
box off

%% Neural activity
for in = 1 : length(noutplot)  
    
    % Select neuron
    n = noutplot(in); 
    
    % Subplot
    i = 2 + ncols*(in-1);
    if i > nsp, break, end
    subplot( nrows,ncols,i)
    scoreShuffle = quantile(statsShuffle.scoreShuffle(n,:), statsShuffle.qthresh );
    
    yyaxis left
    t = [-intv:intv] * session.dt;
    nReset = size(PSTH.DeconvPupilMat,1);
    y = 1:nReset;
    %y = yl;
    imagesc( t, y, PSTH.DeconvPupilMat(:,:,n) )
    set(gca,'YDir','normal')
    colormap(gca,flipud(gray))
    %set(gca,'YTick',[])
    %ylabel('Pupil reset');
    set(gca,'YColor','k')
    hold all
    if n==1
        %title(sprintf('Simulated Cell, p:%.02g',pmean0margin(n) ))
        %ylabel('Activity');
    end
    %ylabel('Activity');
    ylabel('Pupil Reset');
    
    yyaxis right
    plot( t, nanmean(PSTH.DeconvPupilMat(:,:,n),1), 'k' , 'LineWidth', 2)
    hold all
    scoreData = statsShuffle.scoreData(n);
    %h1=plot( [t(1), t(end)], scoreData * [1,1], 'k-' );
    %hold all
    h1=plot( [t(1), t(end)], scoreShuffle * [1,1], 'r-' ); hold all
    %y = statsShuffle.quantileDeconvPupilShuffle(n,:);
    %h1=plot( t, y, 'r-' );
    
    yl = ylim;
    ylim( [0, yl(2) * 2])
    yl = ylim;
    color = 0.5* [1,1,1] ;
    plot([-tmargin,-tmargin]/1000,yl, '-' ,'Color', color)
    plot([0,0],yl, '-' ,'Color', color)
    plot([tmargin,tmargin]/1000,yl, '-' ,'Color', color)
    
    
    xlim( xl )
    ylim( yl )
    set(gca,'YTick',[])
    title(sprintf('roi: %d',n))
    set(gca, 'XTick',xticks ) , %grid on
    %title(sprintf('Cell #%d',n))
    title(sprintf('Cell #%d p:%.3f',n, 1-statsShuffle.scorePercentile(n) ))
    %title(sprintf('Cell #%d, p:%.02g',n, pmean0margin(n)))
    if n==1
        %title(sprintf('Simulated Cell'))
        %title( sprintf('Simulated Cell p:%.3f',1-statsShuffle.scorePercentile(n)) )
        %ylabel('Activity');
    end
    %ylabel('Activity');
    set(gca,'YColor','k')
    box off
    
    %if i+ncols > nsp || in+ncols > length(noutplot),  xlabel('time(sec)'); end
    if i+ncols > nsp,  xlabel('Time(s)'); end
    
    
    
end
%suptitle( sprintf('%s resets:%d pupilCell: %.2f%% (thresh:%.02f)', tag1, length(fPupilResetIdx), mean(pupilCellShuffle) * 100 , pthresh))
suptitle( sprintf('%s resets:%d pupilCell: %.2f%% (thresh:%.02f)', tag1, length(fPupilResetIdx), mean(pupilCellShuffle) * 100 , pthresh))

pause(0)