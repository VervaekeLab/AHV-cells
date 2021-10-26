function pupilVeloSession_plots(Results,sData,pupilData,varargin)
%p.plotfig1 = true; %false;
%p.plotfig2 = false;
%p.plotfig3 = false;
%p.plotfig3 = false;

inputP = inputParser;
addRequired(inputP, 'Results')
addRequired(inputP, 'sData')
addRequired(inputP,'pupilData')
addParameter(inputP, 'windowSize', 33)
addParameter(inputP, 'smoothFactor',5)
addParameter(inputP, 'plotfig1',false)
addParameter(inputP, 'plotfig2',true)
addParameter(inputP, 'plotfig3',true)
addParameter(inputP, 'savedir', '../tmp')
addParameter(inputP, 'tag', '')
parse( inputP, Results, sData, pupilData, varargin{:})
p = inputP.Results;

pupil1 = pupilData.pupil1;
pupil2 = pupilData.pupil2;
dpupil1 = pupilData.dpupil1;
dpupil2 = pupilData.dpupil2;
freqPupilReset = pupilData.freqPupilReset;
pupilResetIdx = pupilData.pupilResetIdx;
quantileReset = pupilData.quantileReset;


%%

if p.plotfig2, hfig2 = figure('Units','normalized','OuterPosition',[0.05,0.1,0.45,0.8]); end
%if p.plotfig3, hfig3 = figure('Units','normalized','OuterPosition',[0.05,0.1,0.45,0.8]); end
if p.plotfig3, hfig3 = figure('Units','normalized','OuterPosition',[0.1,0.1,0.45,0.8]); end


uniqTrialFactor = unique([p.Results.trialFilter]);

%if p.plotfig3, hfig3 = figure(1000); set(hfig3,'Units','normalized','OuterPosition',[0.05,0.1,0.45,0.5]); end

AN = [];
cw_ccw_mat = {'CW','CCW'};



for icw = 1:2
    
    hfig1 = [];
    cw_ccw = cw_ccw_mat(icw);
    
    %Collect
    switch char(cw_ccw)
        case 'CW' , col2 = 1;
        case 'CCW', col2 = 2;
        otherwise
            error('')
    end
    
    %%
        
    nTrialFactor = size(p.Results,1);
    for iFactor = 1:nTrialFactor
        
        trials = p.Results(iFactor,col2).trials;
        idxT = p.Results(iFactor,col2).idxT;
        tmax = p.Results(iFactor,col2).tmax;
        velocity =  p.Results(iFactor,col2).velocity;
        M.PMat = p.Results(iFactor,col2).PMat;
        M.VMat = p.Results(iFactor,col2).VMat;
        M.ZMat = p.Results(iFactor,col2).ZMat;
        M.OmegaMat = p.Results(iFactor,col2).OmegaMat;
        M.meanDeconvolvedMat = p.Results(iFactor,col2).meanDeconvolvedMat;
        M.meanDffMat = p.Results(iFactor,col2).meanDffMat;
        M.bodyMovementMat = p.Results(iFactor,col2).bodyMovementMat;
        M.dpupilMat = p.Results(iFactor,col2).dpupilMat;
        
        %% FIGURE 1
        if p.plotfig1
            hfig1 = plot_figure1(trials,sData,iFactor,nTrialFactor,pupilData,M,idxT,tmax,hfig1,p);
        end
        
        
        
        %% FIGURE 2 - SUMMARY
        if (p.plotfig2)
           hfig2 = plot_figure2(trials,idxT,hfig2,cw_ccw,M,uniqTrialFactor,iFactor,sData,nTrialFactor,tmax,p);
        end
        
        
        %% FIGURE 4 
        if (p.plotfig3)
            [ hfig3,AN ] = plot_figure3_collect(hfig3,M,p,iFactor,icw,tmax,AN);
        end
        
        drawnow
        
        
    end % nTrialFactor
    
    % Save dir
    %subdir = sprintf('%s/%s-pupilResetQ%2d-%s/', p.savedir, datestr(now,'yyyymmdd'), quantileReset*100, p.tag);
    subdir = sprintf('%s/%s-pupilResetQ%2g-%s/', p.savedir, datestr(now,'yyyymmdd'), quantileReset*100, p.tag);
    %subdir = sprintf('%s/',p.savedir);
    if ~exist(subdir,'dir'),  mkdir(subdir), end
    
    % Save Figure 1
    if(p.plotfig1)
        figure(hfig1)
        %suptitle( sprintf('%s (%s) Rotating %d deg/s', ...
        %    sessionID, fovLocationName, uniqTrialFactor(iFactor)) )
        fov = regexprep(sData.fovLocationName,'[^a-zA-Z0-9]','');
        suptitle( sprintf('%s (%s) %s, Rotating %s', ...
            sData.sessionID, fov , p.tag, char(cw_ccw)) )
        
        subdirname = sprintf('%s/velo', subdir);
        if ~exist(subdirname,'dir'),  mkdir(subdirname), end
        savename = sprintf('%s/%s_%s_windowSize%d_%s', subdirname, sData.sessionID, p.tag, p.windowSize,char(cw_ccw));
        saveas(hfig1,savename,'png')
        %saveas(hfig1,savename,'fig')
        fprintf(1,'saved to %s\n',savename)
    end
    
end % CW CCW




%% ----

% PLOT FIGURE 4
if(p.plotfig3)    
     plot_figure3(hfig3,AN)
end





%% Retitle and save

if p.plotfig2
    % Save Figure 2
    figure(hfig2)
    suptitle( sprintf('%s (%s), %s', ...
        sData.sessionID, sData.fovLocationName, p.tag) )
    fov = regexprep(sData.fovLocationName,'[^a-zA-Z0-9]','');
    savename = sprintf('%s/%s_%s_windowSize%d', subdir, sData.sessionID, p.tag, p.windowSize);
    saveas(hfig2,savename,'png')
    saveas(hfig2,savename,'fig')
    fprintf(1,'saved to %s\n',savename)
end


if p.plotfig3
    % Figure vestibular vs pupil
    figure(hfig3)
    suptitle( sprintf('%s (%s), %s', ...
        sData.sessionID, sData.fovLocationName, p.tag) )
    drawnow
    fov = regexprep(sData.fovLocationName,'[^a-zA-Z0-9]','');
    savename = sprintf('%s/scatterV_%s_%s_windowSize%d', subdir, sData.sessionID, p.tag, p.windowSize);
    saveas(hfig3,savename,'png')
    %saveas(hfig3,savename,'fig')
    fprintf(1,'saved to %s\n',savename)
end




end



%%

function hfig1 = plot_figure1(trials,sData,iFactor,nTrialFactor,pupilData,M,idxT,tmax,hfig1,p)


if isempty(hfig1)
    hfig1 = figure('Units','normalized','OuterPosition',[0.0,0.1,0.8,0.8]);
end
axfig1.ax1 = [];
axfig1.ax2 = [];
axfig1.ax3 = [];
axfig1.ax4 = []; axfig1.ylim4 = [];
axfig1.ax4r = []; axfig1.ylim4r = [];
axfig1.ax5 = []; axfig1.ylim5 = [];
axfig1.ax5r = []; axfig1.ylim5r = [];


    
for j = 1:length(trials)
    
    %i = trials{j};
    %try
        idxT1 = idxT{j};
    %catch
    %    keyboard
    %    pause
    %end
    
    lengthT = length(find(idxT1));
    T = [0:lengthT-1] * sData.dt ;
    xl = [T(1),T(tmax)];
    
    
    
    
    % plotfig1
    figure(hfig1)
    set(gcf,'Name', 'Figure1')
    nrows = 7;
    
    %% SUBPLOT 1
    % Actual velocity
    row = 1;
    col = iFactor;
    sbnum = (row-1) * nTrialFactor + col;
    
    subplot(nrows,nTrialFactor,sbnum)
    hv = plot( T, sData.velocity(idxT1) , '.-');
    hold all
    xlim(xl)
    title('velocity')
    xlabel('seconds')
    ylabel('deg/s')
    axfig1.ax1 = [axfig1.ax1, gca];
    grid on
    grid minor
    
    %plot( T, ZCell , '--', 'Color', hv.Color);
    
    
    %% SUBPLOT 2
    % Pupil tracking
    row = 2;
    col = iFactor;
    sbnum = (row-1) * nTrialFactor + col;
    
    subplot(nrows,nTrialFactor,sbnum)
    h=plot( T, pupilData.pupil1(idxT1),'.-');
    hold all
    xlim(xl)
    y = pupilData.pupil1(idxT1);
    idxReset = pupilData.pupilResetIdx(idxT1);
    plot( T(idxReset), y(idxReset) , 'o', 'Color', h.Color)
    title('pupil tracking')
    xlabel('seconds')
    ylabel('pupil coordinate (a.u.)')
    axfig1.ax2 = [axfig1.ax2, gca];
    grid on
    grid minor
    
    
    %% SUBPLOT 2b (6)
    % Pupil tracking
    row = 6;
    col = iFactor;
    sbnum = (row-1) * nTrialFactor + col;
    
    subplot(nrows,nTrialFactor,sbnum)
    h=plot( T, pupilData.dpupil2(idxT1),'.-');
    hold all
    xlim(xl)
    %y = pupil2(idxT1);
    %idxReset = pupilResetIdx(idxT1);
    %plot( T(idxReset), y(idxReset) , 'o', 'Color', h.Color)
    title('pupil velocity (y-axis)')
    xlabel('seconds')
    ylabel('')
    grid on
    grid minor
    
    %% SUBPLOT 7
    % Pupil tracking
    row = 7;
    col = iFactor;
    sbnum = (row-1) * nTrialFactor + col;
    
    subplot(nrows,nTrialFactor,sbnum)
    h=plot( T, sData.bodyMovement(idxT1),'.-');
    hold all
    xlim(xl)
    title('body movement')
    xlabel('seconds')
    ylabel('')
    grid on
    grid minor
    
    
    
    %% SUBPLOT 3
    % Pupil movement
    row = 3;
    col = iFactor;
    sbnum = (row-1) * nTrialFactor + col;
    
    subplot(nrows,nTrialFactor,sbnum)
    yyaxis left
    h = plot( T, pupilData.dpupil1(idxT1) ,'.-');
    hold all
    y = pupilData.dpupil1(idxT1);
    idxReset = pupilData.pupilResetIdx(idxT1);
    plot( T(idxReset), y(idxReset) , 'o', 'Color', h.Color)
    axfig1.ax3 = [axfig1.ax3, gca];
    yyaxis right
    plot( T, pupilData.freqPupilReset(idxT1) ,'.-');
    axfig1.ax3 = [axfig1.ax3, gca];
    xlim(xl)
    title('pupil velocity')
    xlabel('seconds')
    grid on
    grid minor
    
    %%% SUBPLOT WAVELET
    %if (0) % wavelet
    %    x1 = pupil1(idxT); x1(isnan(x1)) = 0;
    %    figure('Position',[1000,918,560,420])
    %    cwt(x1)
    %    hfig1.ax1 = gca;
    %    figure('Position',[1000,410,560,420])
    %    plot(x1)
    %    colorbar
    %    hfig1.ax2 = gca;
    %    linkaxes([hfig1.ax1,hfig1.ax2],'x')
    %    pause
    %end
    
    
    
    
    
    
end % trials


% SUBPLOT 4

% Add average plots
row = 4;
col = iFactor;
sbnum = (row-1) * nTrialFactor + col;

subplot(nrows,nTrialFactor,sbnum)
hold all
yyaxis left
hA = plot(T(1:tmax), nanmean(M.PMat(:,1:tmax),1), 'LineWidth',3, 'Color','r');
%suptitle( sprintf('%s (%s) Rotating %d degrees', ...
%    sessionID, fovLocationName, uniqTrialFactor(irot)) )
xlim(xl)
title('reset frequency')
xlabel('seconds')
ylabel('Hz')
grid on
grid minor
axfig1.ax4 = [axfig1.ax4, gca] ;
axfig1.ylim4 = [axfig1.ylim4; ylim];

drawnow
linkaxes( axfig1.ax1,'xy')
linkaxes( axfig1.ax2,'xy')
linkaxes( axfig1.ax3,'xy')
%linkaxes( hfig1.ax4,'xy')
%linkaxes([hfig1.ax1,hfig1.ax3,hfig1.ax5],'x')
%linkaxes([hfig1.ax3,hfig1.ax5],'y')
%ymax = max([hfig1.ax4.YLim]');
%ymin = min([hfig1.ax4.YLim]');
ymin = min(axfig1.ylim4(:));
ymax = max(axfig1.ylim4(:));
ylim([ ymin,ymax ]);

yyaxis right
plot( T(1:tmax), nanmean(M.ZMat(:,1:tmax),1) , '--', 'Color', hA.Color);
axfig1.ax4r = [axfig1.ax4r, gca];
axfig1.ylim4r = ylim;
%linkaxes( hfig1.ax4r,'xy')
%ymax = max([hfig1.ax4r.YLim]');
%ymin = min([hfig1.ax4r.YLim]');
%ylim([ymin,ymax]);
ymin = min(axfig1.ylim4r(:));
ymax = max(axfig1.ylim4r(:));
ylim([ ymin,ymax ]);


% SUBPLOT 5

% Add average plots
row = 5;
col = iFactor;
sbnum = (row-1) * nTrialFactor + col;

subplot(nrows,nTrialFactor,sbnum)
hold all
yyaxis left
yy = nanmean(M.meanDeconvolvedMat(:,1:tmax),1);
hA = plot(T(1:tmax), smooth( yy, p.smoothFactor ), 'LineWidth',1, 'Color','b');
%suptitle( sprintf('%s (%s) Rotating %d degrees', ...
%    sessionID, fovLocationName, uniqTrialFactor(irot)) )
xlim(xl)
title('Neural Activity')
xlabel('seconds')
ylabel('Deconvolved')
grid on
grid minor
axfig1.ax5 = [axfig1.ax5, gca] ;
axfig1.ylim5 = [axfig1.ylim5; ylim];

drawnow
linkaxes( axfig1.ax1,'xy')
linkaxes( axfig1.ax2,'xy')
linkaxes( axfig1.ax3,'xy')
%linkaxes( hfig1.ax4,'xy')
%linkaxes([hfig1.ax1,hfig1.ax3,hfig1.ax5],'x')
%linkaxes([hfig1.ax3,hfig1.ax5],'y')
%ymax = max([hfig1.ax4.YLim]');
%ymin = min([hfig1.ax4.YLim]');
ymin = min(axfig1.ylim5(:));
ymax = max(axfig1.ylim5(:));
ylim([ ymin,ymax ]);

yyaxis right
yy =  nanmean(M.meanDffMat(:,1:tmax),1);
plot( T(1:tmax), smooth( yy, p.smoothFactor ) , '-', 'Color', 'r');
ylabel('DF/F')
axfig1.ax5r = [axfig1.ax5r, gca];
axfig1.ylim5r = ylim;
%linkaxes( hfig1.ax4r,'xy')
%ymax = max([hfig1.ax4r.YLim]');
%ymin = min([hfig1.ax4r.YLim]');
%ylim([ymin,ymax]);
ymin = min(axfig1.ylim5r(:));
ymax = max(axfig1.ylim5r(:));
ylim([ ymin,ymax ]);


end

%%

function hfig2 = plot_figure2(trials,idxT,hfig2,cw_ccw,M,uniqTrialFactor,iFactor,sData,nTrialFactor,tmax,p)

for j = 1:length(trials)
    idxT1 = idxT{j};
    lengthT = length(find(idxT1));
    T = [0:lengthT-1] * sData.dt ;
    %xl = [T(1),T(tmax)];
end

figure(hfig2);
set(hfig2,'Name', 'Figure2')
switch char(cw_ccw)
    case 'CW' , col2 = 1;
    case 'CCW', col2 = 2;
    otherwise
        error('')
end
nRow2 = (nTrialFactor)+2;
nCol2 = 2;

subplot(nRow2,nCol2,col2)

color = [];
switch iFactor
    case 1, color = parot.plot.color.speed(45);
    case 2, color = parot.plot.color.speed(90);
    case 3, color = parot.plot.color.speed(135);
    case 4, color = parot.plot.color.speed(180);
    otherwise,  color = 'k';
end
if isempty(color)
    hv=plot(T(1:tmax), nanmean(M.VMat(:,1:tmax),1), 'LineWidth',2);
else
    hv=plot(T(1:tmax), nanmean(M.VMat(:,1:tmax),1), 'LineWidth',2, 'Color',color);
end
title('Velocity(actual)')
xlabel('Time')
ylabel('Velocity')
%grid on
%grid minor
hold all
legendtxt = compose('%g',uniqTrialFactor(1:iFactor));
legend(legendtxt)
xlim([0,10])

%subplot(nRow2,nCol2,2+col2)
%plot(T(1:tmax), nanmean(M.ZMat(:,1:tmax)), 'LineWidth',2);
%hold all
%title('Velocity(vestibular)')
%xlabel('Time')
%ylabel('Velocity')
%hold all
%legend(num2str(uniqTrialFactor(1:iFactor)))

subplot(nRow2,nCol2, (iFactor*nCol2)+col2)
xlim([0,10])
yyaxis left
plot( xlim, [0,0], '--' ,'LineWidth',1, 'Color','k');
hold all
plot(T(1:tmax), nanmean(M.ZMat(:,1:tmax),1), 'LineWidth',1, 'Color',hv.Color);
hold all
ylabel('Velocity','Color','k')
yyaxis right
plot(T(1:tmax), nanmean(M.PMat(:,1:tmax),1), 'LineWidth',2, 'Color',hv.Color);
hold all
%ylabel('Pupil reset \n frequency','Color','k')
ylabel(sprintf('Pupil reset \n frequency'),'Color','k')
grid on
grid minor
%title('Pupil resets')
%legend(num2str(uniqTrialFactor(1:iFactor)))
%legend(num2str(uniqTrialFactor(1:iFactor)))
xlabel('Time')
%ylabel('Frequency')
xlim([0,10])

%%align zero for left and right
try
    yyaxis right; ylimr = get(gca,'Ylim');
    ylimr(1) = min([ylimr(1), -1]);
    ylimr(2) = max([ylimr(2),  1]);
    ratior = ylimr(1)/ylimr(2);
    yyaxis left;  yliml = get(gca,'Ylim');
    yliml(1) = min([yliml(1), -1]);
    yliml(2) = max([yliml(2),  1]);
    ratiol = yliml(1)/yliml(2);
    if ratior<ratiol
        set(gca,'Ylim',[yliml(2)*ratior , yliml(2)])
    else
        set(gca,'Ylim',[yliml(1) , yliml(1)/ratior])
    end
catch
    fprintf(1,'YLim zero\n')
end

subplot(nRow2,nCol2, nCol2+(nTrialFactor*nCol2)+col2)
%xlim([0,10])
%plot( xlim, [0,0], '--' ,'LineWidth',1, 'Color','k');
%hold all
yy = smooth( nanmean(M.PMat(:,1:tmax),1) , p.smoothFactor);
plot(T(1:tmax), yy, 'LineWidth',2, 'Color',hv.Color);
hold all
ylabel(sprintf('Pupil reset \n frequency (smoothed)'),'Color','k')
grid on
grid minor
%title('Pupil resets')
legendtxt = compose('%g',uniqTrialFactor(1:iFactor));
legend(legendtxt)
xlabel('Time')
xlim([0,10])

end



%%

function [ hfig3,AN ] = plot_figure3_collect(hfig3,M,p,iFactor,icw,tmax,AN)


%% Figure 4
figure(hfig3)
set(gcf,'Name', 'Figure4')

% 0 Velocity
% 1 Vestibular
% 2 Pupil resets
% 3 Neural Activity
% 4 Body movement

%
clear A;
A{1} = {  nanmean(M.VMat(:,1:tmax),1) , 'Velocity' , true };
A{2} = {  nanmean(M.ZMat(:,1:tmax),1) , 'Vestibular output' , true };
A{3} = {  nanmean(M.dpupilMat(:,1:tmax),1) , 'Pupil velocity' , true };
A{4} = {  smooth(nanmean(M.PMat(:,1:tmax),1) , p.smoothFactor) , 'Pupil reset frequency' ,true };
A{5} = {  smooth(nanmean(M.meanDeconvolvedMat(:,1:tmax),1) , p.smoothFactor) , 'Population activity', false };
A{6} = {  smooth(nanmean(M.bodyMovementMat(:,1:tmax),1)    , p.smoothFactor) , 'bodyMovement' , false };

AN{iFactor,icw} = A;

if (0)
    nrows = length(A);
    for irow = 1:nrows
        for icol =1:nrows
            subplot(nrows,nrows, (irow-1)*nrows + icol )
            %plot( A{irow}{1} , A{icol}{1} ,'.b','MarkerSize',10)
            plot( A{icol}{1} , A{irow}{1} ,'k.','MarkerSize',10)
            hold all
            if irow==nrows, xlabel(A{icol}{2} ), end
            if icol==1, ylabel(A{irow}{2} ), end
            xlim auto; if A{icol}{3}, xl = xlim; xlim( [-1,1]*max(abs(xl))), end
            ylim auto; if A{irow}{3}, yl = ylim; ylim( [-1,1]*max(abs(yl))), end
            grid on
        end
    end
end

end


%% 

function plot_figure3(hfig3,AN)

AMATALL = [];
for icw = 1:2
    for iN = 1:length(AN)
        %% Figure 4
        
        
        figure(hfig3)
        
        % 0 Velocity
        % 1 Vestibular
        % 2 Pupil resets
        % 3 Neural Activity
        % 4 Body movement
        A = AN{iN,icw};
        nrows = length(A);
        clear AMAT ALABEL
        for irow = 1:nrows
            AMAT(:,irow) = A{irow}{1};
            ALABEL{irow} = A{irow}{2};
        end
        
        AMATALL = vertcat(AMATALL, AMAT);
        %
        %         nrows = length(A);
        %         for irow = 1:nrows
        %             for icol =1:nrows
        %                 subplot(nrows,nrows, (irow-1)*nrows + icol )
        %                 %plot( A{irow}{1} , A{icol}{1} ,'.b','MarkerSize',10)
        %                 %plot( A{icol}{1} , A{irow}{1} ,'k.','MarkerSize',10)
        %                 plot( AMAT(:,icol) , AMAT(:,irow) ,'k.','MarkerSize',10)
        %                 hold all
        %                 if irow==nrows, xlabel(A{icol}{2} ), end
        %                 if icol==1, ylabel(A{irow}{2} ), end
        %                 xlim auto; if A{icol}{3}, xl = xlim; xlim( [-1,1]*max(abs(xl))), end
        %                 ylim auto; if A{irow}{3}, yl = ylim; ylim( [-1,1]*max(abs(yl))), end
        %                 grid on
        %             end
        %         end
        
    end
end

for irow = 1:nrows
    for icol =1:nrows
        
        figure(hfig3)
        subplot(nrows,nrows, (irow-1)*nrows + icol )
        %plot( A{irow}{1} , A{icol}{1} ,'.b','MarkerSize',10)
        %plot( A{icol}{1} , A{irow}{1} ,'k.','MarkerSize',10)
        %plot( AMAT(:,icol) , AMAT(:,irow) ,'k.','MarkerSize',10)
        
        x = AMATALL(:,icol);
        y = AMATALL(:,irow);
        xedges = linspace( nanmin(x), nanmax(x), 10 );
        clear ymean ystd yse
        for ix = 1:length(xedges)-1
            fidx = find( x > xedges(ix) & x <= xedges(ix+1)) ;
            ymean(ix) = nanmean( y(fidx) ) ;
            ystd(ix)  = nanstd( y(fidx) ) ;
            yse(ix)   = nanstd( y(fidx) ) / sqrt(length(fidx)) ;
        end
        xmean = (xedges(1:end-1) + xedges(2:end))/2;
        plot( AMATALL(:,icol) , AMATALL(:,irow) ,'.','MarkerSize',1,'Color', [0.8,0.8,0.8])
        hold all
        %plot( xedges, ymean, 'bo-', 'LineWidth',1)
        shadedErrorBar ( xmean , ymean, yse )
        
        hold all
        if irow==nrows, xlabel(A{icol}{2} ), end
        if icol==1, ylabel(A{irow}{2} ), end
        xlim auto; if A{icol}{3}, xl = xlim; xlim( [-1,1]*max(abs(xl))), end
        ylim auto; if A{irow}{3}, yl = ylim; ylim( [-1,1]*max(abs(yl))), end
        grid on
    end
end

    
end