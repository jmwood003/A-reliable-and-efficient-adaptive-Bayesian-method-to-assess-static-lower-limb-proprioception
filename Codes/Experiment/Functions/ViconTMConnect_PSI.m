function [alpha_EV, beta_EV, AllStarts, AllStims, AllResponses, BinaryResponses, StartSpeeds, StimSpeeds, pre_selects] = ViconTMConnect_PSI(Ntrials, X, alpha_range, beta_range, pr_left_lookup, pr_right_lookup, TLstr, offset)

%Description: runs an AFC task using the PSI algorithm by connecting 
% through vicon and through the treadmill controller

%Inputs: 
% Ntrials: scalar, number of trials in the AFC task
% X: vector of all possible simulus location
% alpha_range: vector of the range of possible alpha values
% beta_range: vector of the range of possible beta values
% pr_left_lookup: matrix, look-up table for the probability of responding 'left'
% pr_right_lookup: matrix, look-up table for the probability of responding 'right'
% TLstr: string, specifying which limb is the test limb ('left' or 'right')
% offset: scalar, the difference between the ankle markers at baseline

%Outputs:
% alpha_EV: vector of the alpha estimate after each trial
% beta_EV: vector of the beta estimate after each trial
% AllStarts: vector of all the start positions for each trial
% AllStims: vector of all the stimulus positions for each trial
% AllResponses: cell array of all the responses for each trial
% BinaryResponses: vector of all the responses in binary (1 or 0) form for each trial
% StartSpeeds: vector of treadmill speeds to each start position
% StimSpeeds: vector of treadmill speeds to each stimulus position

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Set some parameters for the test
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


%Set the seed 
rng('shuffle');

%The start positions will be randomized based on this sigma
strtpos_sigma = 50;

%Set the min and max treadmill Speeds
minspeed = 10;
maxspeed = 30;

%The start positions should move from the bottom up to top down an even
%number of times (or as close to equal as possible; 1 = top down, 0 bottom up)
TBidx = rand(1,Ntrials)>0.5;
half = round(Ntrials/2);
while sum(TBidx)~=half
    TBidx = rand(1,Ntrials)>0.5;
end

%Specify the priors
alpha_p = normpdf(alpha_range,-offset,20);
beta_p = exppdf(beta_range,20);
prior = beta_p'*alpha_p;

%Add in random stimuli every 5 trials to gain a wider range of stimuli
random_space = 5;   %Inject random stimuli around the threshold estimate every 5 trials
start_rand = 6; %Starting both at the 5th trial
for r = 1:floor(Ntrials/random_space)

    current_rand_idx = start_rand:start_rand+random_space-1; %index 10 trials at a time
    rand_trials(r) = datasample(current_rand_idx,1,'Replace',false); %choose an extreme index 
    start_rand = current_rand_idx(end)+1;

end

%Add in extreme stimuli every 10 trials to prevent loss of focus
extreme_space = 10; %Inject extreme stimuli every 10 trials 
start_rand = 6; %Starting both at the 5th trial
for e = 1:floor(Ntrials/extreme_space)
    current_ext_idx = start_rand:start_rand+extreme_space-1; %index 10 trials at a time
    extreme_trials(e)  = datasample(current_ext_idx,1,'Replace',false); %choose an extreme index 
    while ismember(extreme_trials(e),rand_trials)==1
        extreme_trials(e)  = datasample(current_ext_idx,1,'Replace',false); %choose an extreme index 
    end
    start_rand = current_ext_idx(end)+1;
end
extreme_trials = [extreme_trials, nan]; %Pad with nans to prevent over indexing
rand_trials = [rand_trials, nan];
et_idx = 1; rand_idx = 1; %Set the index for these trials

%Psudorandomize the extreme options
random_levels = [-30,-20,-10,10,20,30]; %random stimuli options 
extreme_options = [-100,-100,-90,-90,90,90,100,100]-offset;
extreme_stims = extreme_options(randperm(length(extreme_options)));

pre_selects = [extreme_trials, rand_trials];
pre_selects(isnan(pre_selects)==1) = [];

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Set up Vicon SDK----------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


% Program options
TransmitMulticast = false;
EnableHapticFeedbackTest = false;
HapticOnList = {'ViconAP_001';'ViconAP_002'};
SubjectFilterApplied = false;
bPrintSkippedFrame = false;

% Check whether these variables exist, as they can be set by the command line on launch
% If you run the script with Command Window in Matlab, these workspace vars could persist the value from previous runs even not set in the Command Window
% You could clear the value with "clearvars"
if ~exist( 'bReadCentroids' )
  bReadCentroids = false;
end

if ~exist( 'bReadRays' )
  bReadRays = false;
end

if ~exist( 'bTrajectoryIDs' )
  bTrajectoryIDs = false;
end

if ~exist( 'axisMapping' )
  axisMapping = 'ZUp';
end

% example for running from commandline in the ComandWindow in Matlab
% e.g. bLightweightSegment = true;HostName = 'localhost:801';ViconDataStreamSDK_MATLABTest
if ~exist('bLightweightSegment')
  bLightweightSegment = false;
end

% Pass the subjects to be filtered in
% e.g. Subject = {'Subject1'};HostName = 'localhost:801';ViconDataStreamSDK_MATLABTest
EnableSubjectFilter  = exist('subjects');

% Program options
if ~exist( 'HostName' )
  HostName = 'localhost:801';
end

if exist('undefVar')
  fprintf('Undefined Variable: %s\n', mat2str( undefVar ) );
end

% Load the SDK
fprintf( 'Loading SDK...' );
addpath( '..\dotNET' );
dssdkAssembly = which('ViconDataStreamSDK_DotNET.dll');
if dssdkAssembly == ""
  [ file, path ] = uigetfile( '*.dll' );
  if isequal( file, 0 )
    fprintf( 'User canceled' );
    return;
  else
    dssdkAssembly = fullfile( path, file );
  end   
end

NET.addAssembly(dssdkAssembly);
fprintf( 'done\n' );

% % A dialog to stop the loop
% MessageBox = msgbox( 'Stop DataStream Client', 'Vicon DataStream SDK' );

% Make a new client
MyClient = ViconDataStreamSDK.DotNET.Client();

% Connect to a server
fprintf( 'Connecting to %s ...', HostName );
while ~MyClient.IsConnected().Connected
  % Direct connection
  MyClient.Connect( HostName );
  
  % Multicast connection
  % MyClient.ConnectToMulticast( HostName, '224.0.0.0' );
  
  fprintf( '.' );
end
fprintf( '\n' );

% Enable some different data types
MyClient.EnableSegmentData();
MyClient.EnableMarkerData();
MyClient.EnableUnlabeledMarkerData();
MyClient.EnableDeviceData();
if bReadCentroids
  MyClient.EnableCentroidData();
end
if bReadRays
  MyClient.EnableMarkerRayData();
end

if bLightweightSegment
  MyClient.DisableLightweightSegmentData();
  Output_EnableLightweightSegment = MyClient.EnableLightweightSegmentData();
  if Output_EnableLightweightSegment.Result ~= ViconDataStreamSDK.DotNET.Result.Success
    fprintf( 'Server does not support lightweight segment data.\n' );
  end
end

MyClient.SetBufferSize(1)
% % Set the streaming mode
MyClient.SetStreamMode( ViconDataStreamSDK.DotNET.StreamMode.ClientPull  );
% % MyClient.SetStreamMode( StreamMode.ClientPullPreFetch );
% % MyClient.SetStreamMode( StreamMode.ServerPush );

% % Set the global up axis
if axisMapping == 'XUp'
  MyClient.SetAxisMapping( ViconDataStreamSDK.DotNET.Direction.Up, ...
                           ViconDataStreamSDK.DotNET.Direction.Forward,      ...
                           ViconDataStreamSDK.DotNET.Direction.Left ); % X-up
elseif axisMapping == 'YUp'
  MyClient.SetAxisMapping(  ViconDataStreamSDK.DotNET.Direction.Forward, ...
                          ViconDataStreamSDK.DotNET.Direction.Up,    ...
                          ViconDataStreamSDK.DotNET.Direction.Right );    % Y-up
else
  MyClient.SetAxisMapping(  ViconDataStreamSDK.DotNET.Direction.Forward, ...
                          ViconDataStreamSDK.DotNET.Direction.Left,    ...
                          ViconDataStreamSDK.DotNET.Direction.Up );    % Z-up
end

Output_GetAxisMapping = MyClient.GetAxisMapping();

% Discover the version number
Output_GetVersion = MyClient.GetVersion();

% if TransmitMulticast
%   MyClient.StartTransmittingMulticast( 'localhost', '224.0.0.0' );
% end  


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Set up Treadmill SDK------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


%Treadmill controller from this site:
% https://github.com/willpower2727/HMRL-Matlab-Treadmill-Functions

%Set treadmill speed and acceleration
accR = 1500;
accL = 1500;   
TMtestSpeed = 0;   
TMrefSpeed = 0; 

%Set a random speed to start
speed = round(minspeed + (maxspeed-minspeed)*rand);

%Format treadmill input
format=0;
speedRR=0;
speedLL=0;
accRR=0;
accLL=0;
incline=0;

%Open treadmill communication 
t=tcpclient('localhost',1000);
set(t,'InputBufferSize',32,'OutputBufferSize',64);
fopen(t);


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Initialize user interfaces------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


%Subjects display
SubjDisp = uifigure('Name','Instrunctions','Position',[4000 300 500 500],'WindowState','fullscreen');
SubjDisp.Color = 'w';
%Set a label for standing normally
normlbl = uilabel(SubjDisp,'Position',[300 300 1000 500], 'FontSize',100);
normlbl.Text = 'Stand Normally';
normlbl.Visible = 'off';
%Set a label for choice
choicelbl = uilabel(SubjDisp,'Position',[300 300 1000 500], 'FontSize',50);
choicelbl.Text = {'Do you feel your right or left foot'; '            is more forward?'};
choicelbl.Visible = 'off';
%Buttons
LB = uibutton(SubjDisp,'Position',[200 200 300 200],'FontSize',75,'BackgroundColor','g');
LB.Text = 'Left';
LB.Visible = 'off';
RB = uibutton(SubjDisp,'Position',[800 200 300 200],'FontSize',75,'BackgroundColor','g');
RB.Text = 'Right';
RB.Visible = 'off'; 

%Exerpimenter display
Fig = uifigure('Position',[2500 -90 700 850],'Name','Experimenter Interface');
gl = uigridlayout(Fig,[5,5]);
gl.RowHeight = {40,50,400,100,200};
gl.ColumnWidth = {60,150,150,150,70};
%Message bar
message_text = uitextarea(gl,'HorizontalAlignment','center','FontSize',25);
message_text.Layout.Row = 1;
message_text.Layout.Column = [1 4];
%Trial numbers
trial_label = uilabel(gl,'Text', 'Trial','FontSize',20);
trial_label.Layout.Row = 2;
trial_label.Layout.Column = 1;
trial_text = uitextarea(gl,'FontSize',20,'BackgroundColor',[0.93,0.93,0.93]);
trial_text.Layout.Row = 3;
trial_text.Layout.Column = 1;
%Start position texts
start_pos_label = uilabel(gl,'Text', '  Start Position','FontSize',20);
start_pos_label.Layout.Row = 2;
start_pos_label.Layout.Column = 2;
start_pos_text = uitextarea(gl,'FontSize',20);
start_pos_text.Layout.Row = 3;
start_pos_text.Layout.Column = 2;
%Stimulus position texts
stim_pos_label = uilabel(gl,'Text', '  Stim Position','FontSize',20);
stim_pos_label.Layout.Row = 2;
stim_pos_label.Layout.Column = 3;
stim_pos_text = uitextarea(gl,'FontSize',20);
stim_pos_text.Layout.Row = 3;
stim_pos_text.Layout.Column = 3;
%Response texts
resp_label = uilabel(gl,'Text', '  Responses','FontSize',20);
resp_label.Layout.Row = 2;
resp_label.Layout.Column = 4;
resp_text = uitextarea(gl,'FontSize',20);
resp_text.Layout.Row = 3;
resp_text.Layout.Column = 4;
%Buttons 
L_btn = uibutton(gl,'BackgroundColor','g','Text','Left','FontSize',50,'ButtonPushedFcn',@left_callback);
L_btn.Layout.Row = 4;
L_btn.Layout.Column = 2;
R_btn = uibutton(gl,'BackgroundColor','g','Text','Right','FontSize',50,'ButtonPushedFcn',@right_callback);
R_btn.Layout.Row = 4;
R_btn.Layout.Column = 3;
Err_btn = uibutton(gl,'BackgroundColor','r','Text','Error!','FontSize',50,'ButtonPushedFcn',{@error_callback, t, alpha_range, beta_range, prior, extreme_trials, rand_trials, X, pr_left_lookup, pr_right_lookup, strtpos_sigma, TBidx, TLstr});
Err_btn.Layout.Row = 4;
Err_btn.Layout.Column = 4;
%Switch
Switch = uiswitch(gl,'rocker','Items', {'Go','Stop'}, 'ValueChangedFcn',{@switchMoved, t, TLstr});
Switch.Layout.Row = 4;
Switch.Layout.Column = 1;
%Force ratio gauge 
uilabel(Fig, 'Position',[250 100 300 200], 'FontSize',20, 'Text', 'Force Ratio');
FG = uigauge(Fig, 'semicircular', 'Position',[150 10 300 300],'Limits',[50 150]);
FG.ScaleColors = {'red','yellow','green','yellow','red'};
FG.ScaleColorLimits = [50 80; 80 90; 90 110; 110 120; 120 150];
uilabel(Fig,'Position',[70 0 300 200], 'FontSize',15, 'Text','Left too high');
uilabel(Fig,'Position',[450 0 300 200], 'FontSize',15,'Text','Right too high');
%Position slider
stim_pos_label = uilabel(gl,'Text', {'Live'; 'Pos.'},'FontSize',20);
stim_pos_label.Layout.Row = 2;
stim_pos_label.Layout.Column = 5;
Pos_slide = uislider(gl,'Orientation','vertical','Limits',[-300 300],'MajorTicks',[-300:50:300]);
Pos_slide.Layout.Row = [3 5];
Pos_slide.Layout.Column = 5;

%Allow for indexing data within callback functions
Fig.UserData = struct("Resp_Text", resp_text, "Trials", trial_text, "Switch", Switch, ...
    "Message", message_text, "Stims", stim_pos_text, "Starts", start_pos_text,...
    "Position", Pos_slide, "Left_btn", L_btn, "Right_btn", R_btn, "Error_btn", Err_btn);

%Disable buttons for now
set(L_btn,'Enable','off');
set(R_btn,'Enable','off');

%Pause to make sure the figure has time to load
pause(5);


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Start Trial---------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


%Calculate first stimulus
for x = 1:length(X)
    
    %Calculate the probability of getting response r, after presenting
    %test x at the next trial
    pr_left_x = nansum(nansum(pr_left_lookup(:,:,x).*prior));
    pr_right_x = nansum(nansum(pr_right_lookup(:,:,x).*prior));

    %Calculate the posterior distribution for both responses
    Post_left = pr_left_lookup(:,:,x).*prior;
    Post_left = Post_left./pr_left_x;
    Post_right = pr_right_lookup(:,:,x).*prior;
    Post_right = Post_right./pr_right_x;        

    %Estimate the entropy of the posterior distribution for each response
    H_left = -nansum(nansum(Post_left.*log2(Post_left)));
    H_right = -nansum(nansum(Post_right.*log2(Post_right)));

    EH(x) = (H_left*pr_left_x) + (H_right*pr_right_x);

end
%find the simulus that minimizes entropy
[~,minH_idx] = min(EH);
AllStims(1) = X(minH_idx);

%Get a start position and record in a different variable
startpos = round(normrnd(AllStims(1),strtpos_sigma));
while TBidx(1)==1 && startpos <= AllStims(1) %This means that the start position should be above but it is below
    startpos = round(normrnd(AllStims(1),strtpos_sigma));
end
while TBidx(1)==0 && startpos >= AllStims(1) %This means that the start position should be below but it is above
    startpos = round(normrnd(AllStims(1),strtpos_sigma));
end
AllStarts(1) = startpos;

%Initialize pre-set parameters 
Frame = -1;
SkippedFrames = [];
Counter = 1;
tStart = tic;
trial = 1;
alpha_EV = [];
beta_EV = [];
AllResponses = [];
All_trial_nums = [];
StartSpeeds = [];
StimSpeeds = [];

%Update the display
All_trial_nums(1) = trial;
trial_text.Value = sprintf('%d \n',trial);
start_pos_text.Value = sprintf('%d \n',AllStarts);
stim_pos_text.Value = sprintf('%d \n',nan);

%Move treadmill to the start position position   
speed = round(minspeed + (maxspeed-minspeed)*rand);
StartSpeeds = speed; %Record the speed
message_text.Value = ['Moving to start position (speed=' num2str(speed) ')'];
if str2double(start_pos_text.Value{end}) <= offset
  TMtestSpeed = speed;
else
  TMtestSpeed = -speed;
end
%Format treadmill input
if strcmp(TLstr,'Left')==1
  aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
elseif strcmp(TLstr,'Right')==1
  aux=int16toBytes([TMtestSpeed TMrefSpeed speedRR speedLL accR accL accRR accLL incline]);      
end
actualData=reshape(aux',size(aux,1)*2,1);
secCheck=255-actualData; %Redundant data to avoid errors in comm
padding=zeros(1,27);
%Set speeds
Payload=[format actualData' secCheck' padding];
fwrite(t,Payload,'uint8');

% Loop until the message box is dismissed
while trial <= Ntrials

  drawnow limitrate;
  Counter = Counter + 1;
  
%   Get a frame
  while MyClient.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
    fprintf( '.' );
  end% while

  % Get the frame number
  Output_GetFrameNumber = MyClient.GetFrameNumber();
  if Frame ~= -1
    while Output_GetFrameNumber.FrameNumber > Frame + 1
      SkippedFrames = [SkippedFrames Frame+1];
      if bPrintSkippedFrame
        fprintf( 'Skipped frame: %d\n', Frame+1 );      
      end
      Frame = Frame + 1;
    end
  end
  Frame = Output_GetFrameNumber.FrameNumber;  

  % Get the frame rate
  Output_GetFrameRate = MyClient.GetFrameRate();

  for FrameRateIndex = 0:MyClient.GetFrameRateCount().Count -1
    FrameRateName  = MyClient.GetFrameRateName( FrameRateIndex ).Name;
    FrameRateValue = MyClient.GetFrameRateValue( FrameRateName ).Value;
  end

  % Get the timecode
  Output_GetTimecode = MyClient.GetTimecode();

  % Get the latency 
  for LatencySampleIndex = 0:typecast( MyClient.GetLatencySampleCount().Count, 'int32' ) -1
    SampleName  = MyClient.GetLatencySampleName( typecast( LatencySampleIndex, 'uint32') ).Name;
    SampleValue = MyClient.GetLatencySampleValue( SampleName ).Value;

  end% for  
                     
  Output_GetHardwareFrameNumber = MyClient.GetHardwareFrameNumber();

  if EnableSubjectFilter && ~SubjectFilterApplied 
    for SubjectIndex = 1: length( Subject )
      Output_SubjectFilter = MyClient.AddToSubjectFilter(char( Subject(SubjectIndex)));
      SubjectFilterApplied = SubjectFilterApplied || Output_SubjectFilter.Result.Value == Result.Success;
    end
  end
  
  %Index the heel markers 
  SubjectCount = MyClient.GetSubjectCount().SubjectCount;  
  SubjectIndex = typecast( SubjectCount, 'int32' ) -1; 
  SubjectName = MyClient.GetSubjectName( typecast( SubjectIndex, 'uint32') ).SubjectName;  
  Output_GetMarkerGlobalTranslation_Left = MyClient.GetMarkerGlobalTranslation( SubjectName, 'LMAL' );
  LMALY = Output_GetMarkerGlobalTranslation_Left.Translation( 2 );

  Output_GetMarkerGlobalTranslation_Left = MyClient.GetMarkerGlobalTranslation( SubjectName, 'RMAL' );
  RMALY = Output_GetMarkerGlobalTranslation_Left.Translation( 2 );
    
  %Calculate marker difference (test minus reference)
  if strcmp(TLstr,'Left')==1
      MkrDiff = round(LMALY - RMALY); %In mm
  elseif strcmp(TLstr,'Right')==1
      MkrDiff = round(RMALY - LMALY); %In mm      
  end  

  %Index Left Force plate
  DeviceCountL = MyClient.GetDeviceCount().DeviceCount;
  DeviceIndex = typecast( DeviceCountL, 'int32' ) - 1;
  Output_GetDeviceNameL = MyClient.GetDeviceName( typecast( DeviceIndex, 'uint32' ) );
  %The above should index the Left force plate (use the below expression to
  %check)
%   Output_GetDeviceName.DeviceName

  % Count the number of device outputs
  DeviceOutputCountL = MyClient.GetDeviceOutputCount( Output_GetDeviceNameL.DeviceName ).DeviceOutputCount;
  DeviceOutputIndexL = typecast( DeviceOutputCountL, 'int32' ) - 7;
  Output_GetDeviceOutputComponentName = MyClient.GetDeviceOutputComponentName( Output_GetDeviceNameL.DeviceName, typecast( DeviceOutputIndexL, 'uint32') );
  %The above should index the the Fz component of the force plate (use the
  %below expression to check):
%   Output_GetDeviceOutputComponentName.DeviceOutputName
%   Output_GetDeviceOutputComponentName.DeviceOutputComponentName

  % Get the device output value
  Output_GetDeviceOutputValue = MyClient.GetDeviceOutputValue( Output_GetDeviceNameL.DeviceName, Output_GetDeviceOutputComponentName.DeviceOutputName, Output_GetDeviceOutputComponentName.DeviceOutputComponentName);
  FZ_L = Output_GetDeviceOutputValue.Value();
  
  %Index Right Force plate
  DeviceCountR = MyClient.GetDeviceCount().DeviceCount;
  DeviceIndexR = typecast( DeviceCountR, 'int32' ) - 2;
  Output_GetDeviceNameR = MyClient.GetDeviceName( typecast( DeviceIndexR, 'uint32' ) );
  %The above should index the Left force plate (use the below expression to
  %check)
%   Output_GetDeviceNameR.DeviceName
  
  % Count the number of device outputs
  DeviceOutputCountR = MyClient.GetDeviceOutputCount( Output_GetDeviceNameR.DeviceName ).DeviceOutputCount;
  DeviceOutputIndexR = typecast( DeviceOutputCountR, 'int32' ) - 7;
  Output_GetDeviceOutputComponentNameR = MyClient.GetDeviceOutputComponentName( Output_GetDeviceNameR.DeviceName, typecast( DeviceOutputIndexR, 'uint32') );
  %The above should index the the Fz component of the force plate (use the
  %below expression to check):
%   Output_GetDeviceOutputComponentNameR.DeviceOutputName
%   Output_GetDeviceOutputComponentNameR.DeviceOutputComponentName

  % Get the device output value
  Output_GetDeviceOutputValueR = MyClient.GetDeviceOutputValue( Output_GetDeviceNameR.DeviceName, Output_GetDeviceOutputComponentNameR.DeviceOutputName, Output_GetDeviceOutputComponentNameR.DeviceOutputComponentName);
  FZ_R = Output_GetDeviceOutputValueR.Value();
  
  %Ensure forces are being place through feet
  ForceRatio = (FZ_R / FZ_L)*100;
  if ForceRatio > 0 && ForceRatio < inf
    FG.Value = ForceRatio;    
  end
  
  %Update the marker difference display slider
  Pos_slide.Value = MkrDiff;


  %------------------------------------------------------------------------
  %------------------------------------------------------------------------
  %PSI Algorithm
  %------------------------------------------------------------------------
  %------------------------------------------------------------------------
  

  %Stops when the participant reaches the start position 
  if MkrDiff == str2double(start_pos_text.Value{end})

      %get the start position and end position from the GUI
      if trial ~=1 
          AllStims_str = Fig.UserData.Stims.Value;
          AllStarts_str = Fig.UserData.Starts.Value;
          AllTrials_str = Fig.UserData.Trials.Value;
          AllStims = []; AllStarts = []; All_trial_nums = []; 
          for i = 1:length(AllTrials_str)
              AllStims(i) = str2double(AllStims_str{i});
              AllStarts(i) = str2double(AllStarts_str{i});
              All_trial_nums(i) = str2double(AllTrials_str{i});
          end
          AllStarts(isnan(AllStarts)==1) = [];
          AllStims(isnan(AllStims)==1) = [];
      end

      %Stop treadmill
      TMtestSpeed = 0;  
      %Format treadmill input
      if strcmp(TLstr,'Left')==1
          aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
      elseif strcmp(TLstr,'Right')==1
          aux=int16toBytes([TMtestSpeed TMrefSpeed speedRR speedLL accR accL accRR accLL incline]);      
      end
      actualData=reshape(aux',size(aux,1)*2,1);
      secCheck=255-actualData; %Redundant data to avoid errors in comm
      padding=zeros(1,27);
      %Set speeds
      Payload=[format actualData' secCheck' padding];
      fwrite(t,Payload,'uint8');

      %Update the marker difference display slider
      Pos_slide.Value = MkrDiff;

      %update the start and stim position displays 
      start_pos_text.Value = sprintf('%d \n', [AllStarts, nan]);
      stim_pos_text.Value = sprintf('%d \n',AllStims);
      scroll(start_pos_text,'bottom');
      scroll(stim_pos_text,'bottom');

      %Pause for a random time period from 0-2 seconds 
      pause(2*rand(1));

      %Move treadmill to new stimulus position   
      speed = round(minspeed + (maxspeed-minspeed)*rand);
      StimSpeeds(trial) = speed; %Record the speed
      message_text.Value = ['Moving to stimulus position (speed=' num2str(speed) ')']; %display message
      if str2double(stim_pos_text.Value{end}) <= MkrDiff
          TMtestSpeed = speed;
      else
          TMtestSpeed = -speed;
      end
      %Format treadmill input
      if strcmp(TLstr,'Left')==1
          aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
      elseif strcmp(TLstr,'Right')==1
          aux=int16toBytes([TMtestSpeed TMrefSpeed speedRR speedLL accR accL accRR accLL incline]);      
      end
      actualData=reshape(aux',size(aux,1)*2,1);
      secCheck=255-actualData; %Redundant data to avoid errors in comm
      padding=zeros(1,27);
      %Set speeds
      Payload=[format actualData' secCheck' padding];
      fwrite(t,Payload,'uint8');

  %Stops when the limb position equals the stimulus    
  elseif MkrDiff == str2double(stim_pos_text.Value{end})
       
      %Need to get the start position and end position from the GUI
      AllStims_str = Fig.UserData.Stims.Value;
      AllStarts_str = Fig.UserData.Starts.Value;
      AllTrials_str = Fig.UserData.Trials.Value;
      AllStims = []; AllStarts = []; All_trial_nums = []; 
      for i = 1:length(AllTrials_str)
          AllStims(i) = str2double(AllStims_str{i});
          AllStarts(i) = str2double(AllStarts_str{i});
          All_trial_nums(i) = str2double(AllTrials_str{i});
      end
      AllStarts(isnan(AllStarts)==1) = [];
      AllStims(isnan(AllStims)==1) = [];

      %Stop treadmill
      TMtestSpeed = 0;  
      %Format treadmill input
      if strcmp(TLstr,'Left')==1
          aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
      elseif strcmp(TLstr,'Right')==1
          aux=int16toBytes([TMtestSpeed TMrefSpeed speedRR speedLL accR accL accRR accLL incline]);      
      end      
      actualData=reshape(aux',size(aux,1)*2,1);
      secCheck=255-actualData; %Redundant data to avoid errors in comm
      padding=zeros(1,27);
      %Set speeds
      Payload=[format actualData' secCheck' padding];
      fwrite(t,Payload,'uint8');

      %Update the marker difference display slider
      Pos_slide.Value = MkrDiff;
      
      %Engage the visual feedback/prompts
      choicelbl.Visible = 'on'; %Display the question for the subject
      LB.Visible = 'on';
      RB.Visible = 'on';
      message_text.Value = 'At stimulus location, make selection'; %Display message
      message_text.BackgroundColor = 'g';          
      set(L_btn,'Enable','on'); %Enable buttons
      set(R_btn,'Enable','on');
      set(Err_btn,'Enable','off'); %Disable error button
      Switch.Value = 'Stop';
      uiwait(Fig); %Wait for a response

      %Turn off the display for the subject
      choicelbl.Visible = 'off';
      LB.Visible = 'off';
      RB.Visible = 'off';
                
      %Index the responses from the figure
      AllResponses = Fig.UserData.Resp_Text.Value;
      AllResponses = AllResponses(1:end-1); %remove the blank

      %Convert the resoponse to a binary response (probability of left)
      BinaryResponses = contains(AllResponses,'left');
          
      %Create new vectors for repeated stimuli 
      Unique_stims = unique(AllStims,'stable');
      Nstims = []; Kleft = [];
      for s = 1:length(Unique_stims)
          stim_idx = find(Unique_stims(s)==AllStims);
          Nstims(s) = length(stim_idx);
          Kleft(s) = sum(BinaryResponses(stim_idx));
      end
    
      %Calculate the likelihood of this response given the current parameters
      for a = 1:length(alpha_range)
          for b = 1:length(beta_range)
              psi = normcdf(Unique_stims,alpha_range(a),beta_range(b));
              likelihood(b,a) = prod((psi.^Kleft).*((1-psi).^(Nstims - Kleft)));
          end
      end

      %Calculate the posterior and normalize
      posterior = likelihood.*prior;
      posterior = posterior./nansum(nansum(posterior));

      %Marginalize and check the plot
      alpha_post = nansum(posterior,1);
      beta_post = nansum(posterior,2)';

      %Calculate the mean of each posterior
      alpha_EV(trial) = nansum(alpha_range.*alpha_post);
      beta_EV(trial) = nansum(beta_range.*beta_post);  

      %The posterior becomes the prior
      prior = posterior;
      
      %Move to the next trial
      trial = str2double(Fig.UserData.Trials.Value{end})+1; %Index from the display
      All_trial_nums(trial) = trial; %Add the trial
      trial_text.Value = sprintf('%d \n', All_trial_nums); %update the display
      scroll(trial_text,'bottom');

      %Pause the test if at trial 25
      if trial > Ntrials
          break
      elseif trial == 26 %Break at 25 
          message_text.Value = '25 trial break. Flip switch to continue';
          message_text.BackgroundColor = 'c';
          Switch.Value = 'Stop';
          uiwait(Fig);
      elseif trial==51 %Break at 50 
          message_text.Value = '50 trial break. Flip switch to continue';
          message_text.BackgroundColor = 'c';          
          Switch.Value = 'Stop';          
          uiwait(Fig);
      end
      
      %Select the next stimulus (using entropy or the pre-set random stims)
      if trial==extreme_trials(et_idx) %Extreme stimulus 

          %Select an extreme stimulus
          AllStims(trial) = extreme_stims(et_idx);
          et_idx = et_idx+1;

      elseif trial==rand_trials(rand_idx) %less extreme stimulus

          %Add the random values to the current estimate for alpha
          potential_stims = round(alpha_EV(trial-1))+random_levels; 
          new_stim = potential_stims(randi(length(potential_stims)));
          [~, stimidx] = min(abs(X-new_stim)); %Find the value closest to the stim location
          AllStims(trial) = X(stimidx);
          rand_idx = rand_idx+1; %Update the index

      else %Entropy calculation 

          %Calculate the best stimulus for the next trial using information entropy     
          %Loop through all potential stimulus values
          for x = 1:length(X) 

              %Calculate the probability of getting response r, after presenting
              %test x at the next trial
              pr_left_x = nansum(nansum(pr_left_lookup(:,:,x).*prior));
              pr_right_x = nansum(nansum(pr_right_lookup(:,:,x).*prior));

              %Calculate the posterior distribution for both responses
              Post_left = pr_left_lookup(:,:,x).*prior;
              Post_left = Post_left./pr_left_x;
              Post_right = pr_right_lookup(:,:,x).*prior;
              Post_right = Post_right./pr_right_x;        

              %Estimate the entropy of the posterior distribution for each response
              H_left = -nansum(nansum(Post_left.*log2(Post_left)));
              H_right = -nansum(nansum(Post_right.*log2(Post_right)));

              EH(x) = (H_left*pr_left_x) + (H_right*pr_right_x);
          end
          %Find the simulus that minimizes entropy
          [~,minH_idx] = min(EH);
          AllStims(trial) = X(minH_idx);

      end

      %Get a new start position based on the next stim position
      startpos = round(normrnd(AllStims(trial),strtpos_sigma));
      while TBidx(trial)==1 && startpos <= AllStims(trial) %This means that the start position should be above but it is below
          startpos = round(normrnd(AllStims(trial),strtpos_sigma));
      end
      while TBidx(trial)==0 && startpos >= AllStims(trial) %This means that the start position should be below but it is above
          startpos = round(normrnd(AllStims(trial),strtpos_sigma));
      end
      AllStarts(trial) = startpos;

      %Update the display
      stim_pos_text.Value = sprintf('%d \n',[AllStims nan]);
      start_pos_text.Value = sprintf('%d \n',AllStarts);
      scroll(start_pos_text,'bottom');
      scroll(stim_pos_text,'bottom');

      %Move treadmill to new stimulus position   
      speed = round(minspeed + (maxspeed-minspeed)*rand);
      StartSpeeds(trial) = speed; %Record the speed
      message_text.Value = ['Moving to start position (speed=' num2str(speed) ')'];
      if str2double(start_pos_text.Value{end}) <= MkrDiff
          TMtestSpeed = speed;
      else
          TMtestSpeed = -speed;
      end
      %Format treadmill input
      if strcmp(TLstr,'Left')==1
          aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
      elseif strcmp(TLstr,'Right')==1
          aux=int16toBytes([TMtestSpeed TMrefSpeed speedRR speedLL accR accL accRR accLL incline]);      
      end
      actualData=reshape(aux',size(aux,1)*2,1);
      secCheck=255-actualData; %Redundant data to avoid errors in comm
      padding=zeros(1,27);
      %Set speeds
      Payload=[format actualData' secCheck' padding];
      fwrite(t,Payload,'uint8');

  elseif MkrDiff >= 250 || MkrDiff <= -250 %If the foot is moving to far, stop and go back
  
      %Move treadmill to new stimulus position   
      if str2double(start_pos_text.Value{end}) < MkrDiff || str2double(stim_pos_text.Value{end}) < MkrDiff
          TMtestSpeed = speed;
      else
          TMtestSpeed = -speed;
      end
      %Format treadmill input
      if strcmp(TLstr,'Left')==1
        aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
      elseif strcmp(TLstr,'Right')==1
         aux=int16toBytes([TMtestSpeed TMrefSpeed speedRR speedLL accR accL accRR accLL incline]);      
      end
      actualData=reshape(aux',size(aux,1)*2,1);
      secCheck=255-actualData; %Redundant data to avoid errors in comm
      padding=zeros(1,27);
      %Set speeds
      Payload=[format actualData' secCheck' padding];
      fwrite(t,Payload,'uint8');

  end 

end% while true  

AllStarts(isnan(AllStarts)==1) = [];
AllStims(isnan(AllStims)==1) = [];
AllResponses = AllResponses';
BinaryResponses = BinaryResponses';
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%End Trial-----------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


close(SubjDisp);
delete(SubjDisp);

close(Fig);
delete(Fig);

clear t;

%Disconnect from Vicon
if TransmitMulticast
  MyClient.StopTransmittingMulticast();
end  

% Disconnect and dispose
MyClient.Disconnect();

%Disconnect from Vicon
tEnd = toc( tStart );
minutes = tEnd / 60;
fprintf( 'Time Elapsed (minutes): %4.2f', minutes );

end