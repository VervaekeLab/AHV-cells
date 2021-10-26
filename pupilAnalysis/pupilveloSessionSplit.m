function Results = pupilveloSession(session,in_light,walls_only,selectTrialFactor,tag, plotfig1,plotfig2,plotfig3,plotfig4)


% Check
sessionID = session.sessionID;
fprintf(1,'%s...',sessionID)
if ~isfield(session,'pupilCenter')
    fprintf(1,'no pupil data\n')
    Results = [];
    return
else
    fprintf(1,'yes pupil data\n')
end

% Get session meta data
fovLocationName = session.fovLocationName ;
protocol = session.experimentInfo.sessionProtocol;
trialSummary = session.trialSummary;
rotatingCW = session.trialSummary.rotatingCW;
rotatingCCW = session.trialSummary.rotatingCCW;
rotationLength = session.trialSummary.rotationLength;
stageSpeed = session.trialSummary.stageSpeed;


% Get pupil data
pupilx  = squeeze(session.pupilCenter(:,:,1));
pupily  = squeeze(session.pupilCenter(:,:,2));
[coeff,score] = pca([pupilx', pupily']);
pupil1 = score(:,1).';
pupil2 = score(:,2).';
velocity = session.velocity;
stagePositions = session.stagePositions;
rotationLength = session.trialSummary.rotationLength;

% Scale to [-1,1]
%pupil1 = normalize(pupil1, 'range');
%pupil1 = 2*pupil1 -1;
dpupil1 = [0, diff(pupil1)];

%pupil2 = normalize(pupil2, 'range');
%pupil2 = 2*pupil2 -1;
pupil2 = pupil2 - nanmedian(pupil2);
dpupil2 = [0, diff(pupil2)];

if (0)
    %         % Identify resets
    %pupilResetIdx = ( abs(dpupil1) > 0.15);
    %         qAbsDPupil = quantile( abs(dpupil1), quantileReset );
    %         pupilResetIdx = ( abs(dpupil1) > qAbsDPupil );
    %
    %
    %         % Get pupil movements removing resets (not used)
    %         if(0)
    %             dpupil1NoReset = dpupil1;
    %             dpupil1NoReset(pupilResetIdx) = 0;
    %             pupil1NoReset = pupil1(1) + cumsum(dpupil1NoReset,'omitnan');
    %         end
end

% Trial Start
uniqTrialNo = session.trialSummary.trialNo;
trialStart = nan(1,length(uniqTrialNo));
for i = 1:length(uniqTrialNo)
    idxT1 = find( session.trialNo == uniqTrialNo(i), 1, 'first' ) ;
    trialStart(i) = idxT1;
    idxT1 = find( session.trialNo == uniqTrialNo(i), 1, 'last' ) ;
    trialEnd(i) = idxT1;
end
clear i




%% Get velocity from pupil
%switch selectTrialFactor
%    case 'rotationLength'
%        trialFactor = rotationLength;
%    case 'stageSpeed'
%        trialFactor = stageSpeed;
%end
trialFactor = session.trialSummary.(selectTrialFactor);
uniqTrialFactor = unique(trialFactor);
windowSize = 11;
quantileReset = 0.99;
[ freqPupilReset, pupilResetIdx ] = measureFreqPupilResetSplit(session,'windowSize',windowSize,...
    'quantileReset', quantileReset, 'removeConsecutive', false);


%% Collect

clear Results
for cw_ccw = {'CW','CCW'}
    
    nTrialFactor = length(uniqTrialFactor);
    for iFactor = 1:nTrialFactor
        
        trialFilter = uniqTrialFactor(iFactor) ;
        
        %% Prepare
        switch char(cw_ccw)
            case 'CW'
                trials1 = find( rotatingCW(:)' & (trialFactor(:)'== trialFilter) );
            case 'CCW'
                trials1 = find( rotatingCCW(:)' & (trialFactor(:)'== trialFilter) );
        end
        
        PCell = {}; PCell2 = {}; VCell = {}; ZCell = {}; OmegaCell = {};
        deconvolvedCell = {}; dffCell = {};
        idxT = {}; trials={};
        for ii = 1:length(trials1)
            
            idxT1 = false(1,session.nSamples);
            idxT1( trialStart(trials1(ii)) : trialEnd(trials1(ii)) ) = true;
            
            trials{ii} = trials1;
            idxT{ii} = idxT1;
            PCell{ii} = freqPupilReset(1,idxT1);
            PCell2{ii} = freqPupilReset(2,idxT1);
            VCell{ii} = velocity(idxT1);
            
            % Laurens
            is_active = 0; % in_light = 1;
            T = [0:(length(find(idxT1))-1)] * session.dt ;
            VL = Example_Simulations_Kalman_Model_PRT(T,velocity(idxT1),is_active, in_light, walls_only);
            colVestibularReal = 1;
            ZCell{ii} = VL.Z(:,colVestibularReal)';
            OmegaCell{ii}  = VL.Xf(:,1)';
            
            
            % Neural data
            dffCell{ii} = session.dff(:,idxT1);
            deconvolvedCell{ii} = session.deconvolved(:,idxT1);
            
            
            %idxT(rotate.stationary) = false;  % rotating part only
        end
        clear ii
        
        % Trim cell into matrix (trialTypes x time)
        tmax = min(cellfun(@length,PCell)); %160;
        lengthA = length(PCell);
        PMat = zeros(lengthA,tmax);
        PMat2 = zeros(lengthA,tmax);
        VMat = zeros(lengthA,tmax);
        ZMat = zeros(lengthA,tmax);
        OmegaMat = zeros(lengthA,tmax);
        for k=1:lengthA
            PMat(k,1:tmax) = PCell{k}(:,1:tmax);
            PMat2(k,1:tmax) = PCell2{k}(:,1:tmax);
            VMat(k,1:tmax) = VCell{k}(:,1:tmax);
            ZMat(k,1:tmax) = ZCell{k}(:,1:tmax);
            OmegaMat(k,1:tmax) = OmegaCell{k}(:,1:tmax);
        end
        
        % Neural activity
        meanDeconvolvedMat = zeros(lengthA, tmax);
        meanDffMat = zeros(lengthA, tmax);
        for k=1:lengthA
            meanDeconvolvedMat(k,1:tmax) = nanmean(deconvolvedCell{k}(:,1:tmax),1);
            meanDffMat(k,1:tmax) = nanmean(dffCell{k}(:,1:tmax),1);
        end
        
        
        %Collect
        switch char(cw_ccw)
            case 'CW' , col2 = 1;
            case 'CCW', col2 = 2;
            otherwise
                error('')
        end
        uniqStageSpeed = unique(stageSpeed);
        S1 = v2struct(sessionID,uniqStageSpeed,selectTrialFactor,trialFilter, ...
            quantileReset,windowSize,cw_ccw,...
            trials,idxT,tmax,PMat,PMat2,VMat,ZMat,OmegaMat, ...
            meanDeconvolvedMat, meanDffMat);
        Results(iFactor,col2) = S1;
        
        %continue
        
        
    end %iFactor
end %cw_ccw

%return
pause(0)

%% Plot only


%plotfig1 = true; %false;
%plotfig2 = false;
%plotfig3 = false;
%plotfig4 = false;

if plotfig2, hfig2 = figure('Units','normalized','OuterPosition',[0.05,0.1,0.45,0.8]); end
%if plotfig3, hfig3 = figure('Units','normalized','OuterPosition',[0.05,0.1,0.45,0.8]); end
if plotfig4, hfig4 = figure('Units','normalized','OuterPosition',[0.05,0.1,0.45,0.5]); end

%if plotfig4, hfig4 = figure(1000); set(hfig4,'Units','normalized','OuterPosition',[0.05,0.1,0.45,0.5]); end

for cw_ccw = {'CW','CCW'}
    
    %Collect
    switch char(cw_ccw)
        case 'CW' , col2 = 1;
        case 'CCW', col2 = 2;
        otherwise
            error('')
    end
    
    if plotfig1, hfig1 = figure('Units','normalized','OuterPosition',[0.0,0.1,0.8,0.8]); end
    
    ax1 = [];
    ax2 = [];
    ax3 = [];
    ax4 = []; ylim4 = [];
    ax4r = []; ylim4r = [];
    ax5 = []; ylim5 = [];
    ax5r = []; ylim5r = [];
    
    for iFactor = 1:nTrialFactor
        
        trials = Results(iFactor,col2).trials;
        idxT = Results(iFactor,col2).idxT;
        PMat = Results(iFactor,col2).PMat;
        PMat2 = Results(iFactor,col2).PMat2;
        VMat = Results(iFactor,col2).VMat;
        ZMat = Results(iFactor,col2).ZMat;
        OmegaMat = Results(iFactor,col2).OmegaMat;
        tmax = Results(iFactor,col2).tmax;
        meanDeconvolvedMat = Results(iFactor,col2).meanDeconvolvedMat;
        meanDffMat = Results(iFactor,col2).meanDffMat;
        
        %% FIGURE 1 PLOT INDIVIDUAL TRIALS
        
        for j = 1:length(trials)
            
            %i = trials{j};
            try
                idxT1 = idxT{j};
            catch
                keyboard
                pause
            end
            
            lengthT = length(find(idxT1));
            T = [0:lengthT-1] * session.dt ;
            xl = [T(1),T(tmax)];
            
            
            if(plotfig1)
                
                figure(hfig1)
                nrows = 7;
                
                %% SUBPLOT 1
                % Actual velocity
                row = 1;
                col = iFactor;
                sbnum = (row-1) * nTrialFactor + col;
                
                subplot(nrows,nTrialFactor,sbnum)
                hv = plot( T, velocity(idxT1) , '.-');
                hold all
                xlim(xl)
                title('velocity')
                xlabel('seconds')
                ylabel('deg/s')
                ax1 = [ax1, gca];
                grid on
                grid minor
                
                %plot( T, ZCell , '--', 'Color', hv.Color);
                
                
                %% SUBPLOT 2
                % Pupil tracking
                row = 2;
                col = iFactor;
                sbnum = (row-1) * nTrialFactor + col;
                
                subplot(nrows,nTrialFactor,sbnum)
                h=plot( T, pupil1(idxT1),'.-');
                hold all
                xlim(xl)
                y = pupil1(idxT1);
                idxReset = pupilResetIdx(idxT1);
                plot( T(idxReset), y(idxReset) , 'o', 'Color', h.Color)
                title('pupil tracking')
                xlabel('seconds')
                ylabel('')
                ax2 = [ax2, gca];
                grid on
                grid minor
                
                
                %% SUBPLOT 2b (6)
                % Pupil tracking
                row = 6;
                col = iFactor;
                sbnum = (row-1) * nTrialFactor + col;
                
                subplot(nrows,nTrialFactor,sbnum)
                h=plot( T, dpupil2(idxT1),'.-');
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
                h=plot( T, session.bodyMovement(idxT1),'.-');
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
                h = plot( T, dpupil1(idxT1) ,'.-');
                hold all
                y = dpupil1(idxT1);
                idxReset = pupilResetIdx(idxT1);
                plot( T(idxReset), y(idxReset) , 'o', 'Color', h.Color)
                ax3 = [ax3, gca];
                yyaxis right
                plot( T, freqPupilReset(idxT1) ,'.-');
                ax3 = [ax3, gca];
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
                %    ax1 = gca;
                %    figure('Position',[1000,410,560,420])
                %    plot(x1)
                %    colorbar
                %    ax2 = gca;
                %    linkaxes([ax1,ax2],'x')
                %    pause
                %end
                
                
                
            end
            
            
        end % trials
        
        
        %% FIGURES MEAN TRIAL
        
        %% SUBPLOT 4
        if (plotfig1)
            % Add average plots
            row = 4;
            col = iFactor;
            sbnum = (row-1) * nTrialFactor + col;
            
            subplot(nrows,nTrialFactor,sbnum)
            hold all
            yyaxis left
            hA = plot(T(1:tmax), nanmean(PMat(:,1:tmax),1), 'LineWidth',3, 'Color','r');
            %suptitle( sprintf('%s (%s) Rotating %d degrees', ...
            %    sessionID, fovLocationName, uniqTrialFactor(irot)) )
            xlim(xl)
            title('reset frequency')
            xlabel('seconds')
            ylabel('Hz')
            grid on
            grid minor
            ax4 = [ax4, gca] ;
            ylim4 = [ylim4; ylim];
            
            drawnow
            linkaxes( ax1,'xy')
            linkaxes( ax2,'xy')
            linkaxes( ax3,'xy')
            %linkaxes( ax4,'xy')
            %linkaxes([ax1,ax3,ax5],'x')
            %linkaxes([ax3,ax5],'y')
            %ymax = max([ax4.YLim]');
            %ymin = min([ax4.YLim]');
            ymin = min(ylim4(:));
            ymax = max(ylim4(:));
            ylim([ ymin,ymax ]);
            
            yyaxis right
            plot( T(1:tmax), nanmean(ZMat(:,1:tmax),1) , '--', 'Color', hA.Color);
            ax4r = [ax4r, gca];
            ylim4r = ylim;
            %linkaxes( ax4r,'xy')
            %ymax = max([ax4r.YLim]');
            %ymin = min([ax4r.YLim]');
            %ylim([ymin,ymax]);
            ymin = min(ylim4r(:));
            ymax = max(ylim4r(:));
            ylim([ ymin,ymax ]);
            
        end
        
        %% SUBPLOT 5
        if (plotfig1)
            % Add average plots
            row = 5;
            col = iFactor;
            sbnum = (row-1) * nTrialFactor + col;
            
            subplot(nrows,nTrialFactor,sbnum)
            hold all
            yyaxis left
            %hA = plot(T(1:tmax), smooth( nanmean(meanDeconvolvedMat(:,1:tmax),1) ), 'LineWidth',1, 'Color','b');
            hA = shadedErrorBar(T(1:tmax), smooth( nanmean(meanDeconvolvedMat(:,1:tmax),1) ), smooth( nanstd(meanDeconvolvedMat(:,1:tmax),[],1) ), 'lineProps', {'LineWidth',1, 'Color','b'});
            %suptitle( sprintf('%s (%s) Rotating %d degrees', ...
            %    sessionID, fovLocationName, uniqTrialFactor(irot)) )
            xlim(xl)
            title('Neural Activity')
            xlabel('seconds')
            ylabel('Deconvolved')
            grid on
            grid minor
            ax5 = [ax5, gca] ;
            ylim5 = [ylim5; ylim];
            
            drawnow
            linkaxes( ax1,'xy')
            linkaxes( ax2,'xy')
            linkaxes( ax3,'xy')
            %linkaxes( ax4,'xy')
            %linkaxes([ax1,ax3,ax5],'x')
            %linkaxes([ax3,ax5],'y')
            %ymax = max([ax4.YLim]');
            %ymin = min([ax4.YLim]');
            ymin = min(ylim5(:));
            ymax = max(ylim5(:));
            ylim([ ymin,ymax ]);
            
            if (0) % df/f has conflicts with shadedErrorBar
                yyaxis right
                %plot( T(1:tmax), smooth( nanmean(meanDffMat(:,1:tmax),1) ) , '-', 'Color', 'r');
                %shadedErrorBar( T(1:tmax), smooth( nanmean(meanDffMat(:,1:tmax),1) ) , smooth( nanstd(meanDffMat(:,1:tmax),[],1) ) , 'lineProps', {'Color', 'r'});
                ylabel('DF/F')
                ax5r = [ax5r, gca];
                ylim5r = ylim;
                %linkaxes( ax4r,'xy')
                %ymax = max([ax4r.YLim]');
                %ymin = min([ax4r.YLim]');
                %ylim([ymin,ymax]);
                ymin = min(ylim5r(:));
                ymax = max(ylim5r(:));
                ylim([ ymin,ymax ]);
            end
        end
        
        
        
        
        %% FIGURE 2 - SUMMARY
        if (plotfig2)
            figure(hfig2);
            switch char(cw_ccw)
                case 'CW' , col2 = 1;
                case 'CCW', col2 = 2;
                otherwise
                    error('')
            end
            nRow2 = (nTrialFactor)+2;
            nCol2 = 2;
            
            subplot(nRow2,nCol2,col2)
            hv=plot(T(1:tmax), nanmean(VMat(:,1:tmax),1), 'LineWidth',2);
            title('Velocity(actual)')
            xlabel('Time')
            ylabel('Velocity')
            %grid on
            %grid minor
            hold all
            legend(num2str(uniqTrialFactor(1:iFactor)))
            xlim([0,10])
            
            %subplot(nRow2,nCol2,2+col2)
            %plot(T(1:tmax), nanmean(ZMat(:,1:tmax)), 'LineWidth',2);
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
            plot(T(1:tmax), nanmean(ZMat(:,1:tmax),1), 'LineWidth',1, 'Color',hv.Color);
            hold all
            ylabel('Velocity','Color','k')
            yyaxis right
            plot(T(1:tmax), nanmean(PMat(:,1:tmax),1), 'LineWidth',2, 'Color',hv.Color);
            hold all
            ylabel('Pupil reset frequency','Color','k')
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
            plot(T(1:tmax), smooth(nanmean(PMat(:,1:tmax),1)), 'LineWidth',2, 'Color',hv.Color);
            hold all
            ylabel(sprintf('Pupil reset frequency\n(smoothed)'),'Color','k')
            grid on
            grid minor
            %title('Pupil resets')
            legend(num2str(uniqTrialFactor(1:iFactor)))
            xlabel('Time')
            xlim([0,10])
        end
        
        
        
        if(plotfig4)
            %% Figure 4
            figure(hfig4)
            %subplot(2,1,1)
            %Vmean = smooth(nanmean(VMat(:,1:tmax)));
            %Zmean = smooth(nanmean(ZMat(:,1:tmax)));
            %plot(Vmean,Zmean,'.b','MarkerSize',10)
            %hold all
            %xlabel({'Velocity'})
            %ylabel({'Vestibular output'})
            subplot(1,2,1)
            Vmean = smooth(nanmean(VMat(:,1:tmax),1));
            Pmean = smooth(nanmean(PMat(:,1:tmax),1));
            plot(Vmean,Pmean,'.b','MarkerSize',10)
            hold all
            xlabel({'Velocity'})
            ylabel({'Pupil frequency'})
            xl = xlim; xlim( [-1,1]*max(abs(xl)))
            yl = ylim; ylim( [-1,1]*max(abs(yl)))
            grid on
            subplot(1,2,2)
            Zmean = smooth(nanmean(ZMat(:,1:tmax),1));
            Pmean = smooth(nanmean(PMat(:,1:tmax),1));
            plot(Zmean,Pmean,'.b','MarkerSize',10)
            hold all
            xlabel({'Vestibular output'})
            ylabel({'Pupil frequency'})
            xl = xlim; xlim( [-1,1]*max(abs(xl)))
            yl = ylim; ylim( [-1,1]*max(abs(yl)))
            grid on
        end
        
        drawnow
        
    end % nTrialFactor
    
    
    
    
    
    % Save dir
    rootdir = 'E:/Dropbox (UIO Physiology Dropbox)/Lab Data/Aree Witoelar/RSC Rotation Project/LinearNonLinearPoisson';
    dirname = sprintf('%s/tmp/%s-pupilResetQ%2d-%s/', rootdir, datestr(now,'yyyymmdd'), quantileReset*100, tag);
    if ~exist(dirname,'dir'),  mkdir(dirname), end
    
    % Save Figure 1
    if(plotfig1)
        figure(hfig1)
        %suptitle( sprintf('%s (%s) Rotating %d deg/s', ...
        %    sessionID, fovLocationName, uniqTrialFactor(iFactor)) )
        suptitle( sprintf('%s (%s) %s, Rotating %s', ...
            sessionID, fovLocationName, tag, char(cw_ccw)) )
        
        subdirname = sprintf('%s/velo', dirname);
        if ~exist(subdirname,'dir'),  mkdir(subdirname), end
        savename = sprintf('%s/%s_%s_windowSize%d_%s', subdirname,sessionID,tag,windowSize,char(cw_ccw));
        saveas(hfig1,savename,'png')
        saveas(hfig1,savename,'fig')
        fprintf(1,'saved to %s\n',savename)
    end
    
end % CW CCW

if plotfig2
    % Save Figure 2
    figure(hfig2)
    suptitle( sprintf('%s (%s), %s', ...
        sessionID, fovLocationName, tag) )
    savename = sprintf('%s/%s_%s_windowSize%d', dirname,sessionID,tag,windowSize);
    saveas(hfig2,savename,'png')
    saveas(hfig2,savename,'fig')
    fprintf(1,'saved to %s\n',savename)
end

drawnow


if plotfig4
    % Figure vestibular vs pupil
    figure(hfig4)
    suptitle( sprintf('%s (%s), %s', ...
        sessionID, fovLocationName, tag) )
    drawnow
    savename = sprintf('%s/scatterV_%s_%s_windowSize%d', dirname,sessionID,tag,windowSize);
    saveas(hfig4,savename,'png')
    saveas(hfig4,savename,'fig')
    fprintf(1,'saved to %s\n',savename)
end




end