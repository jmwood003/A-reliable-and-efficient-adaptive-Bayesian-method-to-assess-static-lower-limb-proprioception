%% Set up subject
close all; clear all; clc; 

%Subject ID
SID = 'PSItest_07a'; 
%Set test limb (moving limb)
TestLimb = 'Left';
%Number of trials
Ntrials = 50;

%Preset gamma and labmda
gamma = 0.02; lambda = 0.02;

%Set paths and directories 
addpath('C:\Users\Lab Account\Documents\GitHub\Split-Belt-AFC-Reliability\Codes\Experiment');
addpath('C:\Users\Lab Account\Documents\GitHub\Split-Belt-AFC-Reliability\Codes\Experiment\Functions');
Livedir = 'C:\Program Files\Vicon\DataStream SDK\Win64\MATLAB';
datadir = 'C:\Users\Lab Account\Documents\GitHub\Split-Belt-AFC-Reliability\Data\TestRetest_PSI';
backupdir = 'C:\Users\Lab Account\University of Delaware - o365\Team-CHS-PT-Morton Lab - Split-Belt Recal - Jonathan - Split-Belt Recal - Jonathan\Data\Backup';
cd(datadir);

%% Baseline difference calculation
clc;

tic
%Do this right before the AFC trial
cd(Livedir);
S = 1;
%Calculate baseline difference
[BslDiff,~,~] = ViconTMConnect_StaticCal(S,TestLimb);
offset = round(BslDiff);

%Ranges for the stimulus, alpha and beta parameters
X = linspace(-50,50,101)-offset;
alpha_range = linspace(-50,50,101)-offset;
beta_range = linspace(0.001,50,101);

%Create lookup table
[pr_left_x, pr_right_x] = psi_lookupT(X, alpha_range, beta_range);

toc

%% AFC task

%Time variables
PhaseStart = datetime('now');
timevar = tic;

%Run task
cd(Livedir);
[alpha_EV, beta_EV, AllStarts, AllStims, AllResponses, BinaryResponses] = ...
    ViconTMConnect_PSI(Ntrials, X, alpha_range, beta_range, ...
    pr_left_x, pr_right_x, TestLimb, lambda, gamma, offset);

elapsedTime = toc(timevar);

psi_est = gamma + (1-lambda-gamma) * normcdf(X,alpha_EV(end),beta_EV(end));
C = lines(5);
estC = C(2,:);

%Plot
PSIfig = figure; subplot(2,4,1:3); hold on
plot(1:Ntrials,alpha_EV,'o-','linewidth',2);
plot(1:Ntrials,AllStims,'ko-','linewidth',2);
plot(1:Ntrials,AllStarts,'ko-','linewidth',0.5);
plot(1:Ntrials,zeros(1,Ntrials),'k--','linewidth',2);
xlabel('Trial'); ylabel('Stimiulus');
legend(['\alpha = ' num2str(round(alpha_EV(end),2))],'Stimulus','Start Positions');
legend('boxoff');
ylim([-50 50]);
title([strrep(SID,'_',' ') ' - trial by trial']);
set(gca,'FontName','Ariel','FontSize',15);

subplot(2,4,5:7); hold on
plot(1:Ntrials,beta_EV,'ro-','linewidth',2);
plot(1:Ntrials,zeros(1,Ntrials),'k--','linewidth',2);
xlabel('Trial'); ylabel('Stimiulus');
legend(['\beta = ' num2str(round(beta_EV(end),2))]);
legend('boxoff');
ylim([0 50]);
set(gca,'FontName','Ariel','FontSize',15);

subplot(2,4,[4 8]); hold on
plot(psi_est,X,'Color',estC,'linewidth',2);
legend('Estimated Psi','location','northwest'); legend('boxoff');
xlabel('p_{left more foreward}');
title('Estimate');     ylim([-50 50]);
set(gca,'FontName','Ariel','FontSize',15);

%Save data
cd(datadir);
save([SID '_data'], 'alpha_EV', 'beta_EV', 'AllStarts', 'AllStims', 'AllResponses', 'BinaryResponses', 'elapsedTime', 'PhaseStart');
saveas(PSIfig,[SID '_fig.fig']);
cd(backupdir);
save([SID '_data'], 'alpha_EV', 'beta_EV', 'AllStarts', 'AllStims', 'AllResponses', 'BinaryResponses', 'elapsedTime', 'PhaseStart');

