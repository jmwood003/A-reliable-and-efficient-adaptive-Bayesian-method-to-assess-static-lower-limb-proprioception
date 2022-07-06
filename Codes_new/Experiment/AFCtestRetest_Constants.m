%Test retest

%% Set up subject
close all; clear all; clc; 

SID = 'AFCtest_21c'; 

addpath('Z:\smmorton Lab\Jonathan\Projects\SBrep\Codes\LiveControl');
addpath('Z:\smmorton Lab\Jonathan\Projects\SBrep\Codes\LiveControl\Functions');
Livedir = 'C:\Program Files\Vicon\DataStream SDK\Win64\MATLAB';
datadir = 'Z:\smmorton Lab\Jonathan\Projects\SBrep\Data\Piloting';
backupdir = 'Z:\smmorton Lab\Jonathan\Projects\SBrep\Data\Backup';
cd(datadir);

if ~exist(SID,'dir')
    mkdir(SID);
end
subjdir = [datadir, '\' SID];

TestLimb = 'Left';
Ntrials = 14;
Ts = [-40, -30, -20, -10, 0, 10, 20, 30, 40];

%% Baseline difference calculation
clc;

%Do this right before the AFC trial
cd(Livedir);
S = 1;
%Calculate baseline difference
[BslDiff,~,~] = ViconTMConnect_StaticCal(S,TestLimb);

%Set the targets
Bsl_Ts = round(Ts+BslDiff);

%% AFC task

%Time variables
PhaseStart = datetime('now');
timevar = tic;

%Run task
cd(Livedir);
[AllStarts, AllEnds, AllAnswers] = ViconTMConnect_AFC(Ntrials, Bsl_Ts, TestLimb);
elapsedTime = toc(timevar);

%Save data
cd(subjdir);
save(['AFCdata' SID(strfind(SID,'_'):end)], 'AllStarts', 'AllEnds', 'AllAnswers', 'BslDiff', 'TestLimb', 'elapsedTime', 'PhaseStart');
cd(backupdir);
save(['AFCdata' SID(strfind(SID,'_'):end)], 'AllStarts', 'AllEnds', 'AllAnswers', 'BslDiff', 'TestLimb', 'elapsedTime', 'PhaseStart');
