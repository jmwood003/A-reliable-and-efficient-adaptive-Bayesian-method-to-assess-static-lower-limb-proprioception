function [alpha_EV, beta_EV, AllStarts, AllStims, AllResponses, BinaryResponses, StartSpeeds, StimSpeeds] = ViconTMConnect_PSI(Ntrials, X, alpha_range, beta_range, pr_left_lookup, pr_right_lookup, TLstr, offset)

rng('shuffle');
strtpos_sigma = 50;

%Treadmill Speeds
minspeed = 10;
maxspeed = 50;

%Set the first round of start positions (changed every 10 trials)
%If TBidx == 1, the start position is from the top, if 0, it is from
%the bottom 
TBidx = rand(1,Ntrials)>0.5;
half = round(Ntrials/2);
while sum(TBidx) == half
    TBidx = rand(1,Ntrials)>0.5;
end

%Specify the priors (make them pretty wide, but reasonable)
%we are working in 2d space now
alpha_p = normpdf(alpha_range,-offset,20);
beta_p = exppdf(beta_range,20);
prior = beta_p'*alpha_p;

%We are injecting some extreme stimuli into the trials 
%Every 10 trials: 
extreme_space = 10; 
start_rand=5;%Starting at the 5th trial

%This loop randomizes when the extreme stimulus will be provided
%And determines which stimulus will be provided
for e = 1:floor(Ntrials/extreme_space)
    current_idx = start_rand:start_rand+extreme_space-1;
    random_stims = datasample(current_idx,2,'Replace',false);
    extreme_trials(e) = random_stims(1);
    iqr_trials(e) = random_stims(2);
    
    start_rand = current_idx(end)+1;
end
extreme_trials = [extreme_trials, nan]; %Pad with nans to prevent over indexing
iqr_trials = [iqr_trials, nan];
et_idx = 1; iqr_idx = 1; %Set the index for these trials

%Psudorandomize the extreme options (note that I have one more negative
%stimulus added vs positive - based on pilot testing individuals tend to be
%biased more positive
extreme_options = [-100,-100,-90,-90,90,90,100,100]-offset;
extreme_stims = extreme_options(randperm(length(extreme_options)));

%Treadmill controller from this site:
% https://github.com/willpower2727/HMRL-Matlab-Treadmill-Functions

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%Set up Vicon SDK----------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
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
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%Set up Treadmill SDK------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%Set treadmill speed (Lets say for now the right leg is the reference
%leg so we are only moving the left)
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
t=tcpip('localhost',1000);
set(t,'InputBufferSize',32,'OutputBufferSize',64);
fopen(t);

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%Start Trial---------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%Calculate first stimulus--------------------------------------------------
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

%find the simulus that minimizes entropy
[~,minH_idx] = min(EH);
stimulus = X(minH_idx);
AllStims(1) = stimulus;

%Get a start position and record in a different variable
startpos = round(normrnd(stimulus,strtpos_sigma));
while TBidx(1)==1 && startpos <= stimulus %This means that the start position should be above but it is below
    startpos = round(normrnd(stimulus,strtpos_sigma));
end
while TBidx(1)==0 && startpos >= stimulus %This means that the start position should be below but it is above
    startpos = round(normrnd(stimulus,strtpos_sigma));
end
AllStarts(1) = startpos;

stimulus = nan; %Need the stimulus to be nan at first so the first treadmill stop is the start position 

%Initialize user interface fig---------------------------------------------
% SubjDisp = uifigure('Name','Instrunctions','Position',[4000 300 500 500],'Color',[0.3010 0.7450 0.9330],'WindowState','fullscreen');
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

%User interface for force plates
ForceDisp = uifigure('Name','Forces','Position',[400 300 500 500]);
FGtitle = uilabel(ForceDisp, 'Position',[175 350 300 200], 'FontSize',30);
FGtitle.Text = 'Force Ratio';
FG = uigauge(ForceDisp, 'semicircular', 'Position',[100 250 300 300],'Limits',[50 150]);
FG.ScaleColors = {'red','yellow','green','yellow','red'};
FG.ScaleColorLimits = [50 80; 80 90; 90 110; 110 120; 120 150];
LFtext = uilabel(ForceDisp,'Position',[70 130 300 200], 'FontSize',15);
LFtext.Text = {'Increased Left Forces'};
RFtext = uilabel(ForceDisp,'Position',[300 130 300 200], 'FontSize',15);
RFtext.Text = {'Increased Right Forces'};

% ERRtitle = uilabel(ForceDisp, 'Position',[150 75 300 200], 'FontSize',30);
% ERRtitle.Text = 'Response Error';
% uicontrol(ForceDisp,'Style','pushbutton','Callback',@pushbutton_callback)
% EB = uibutton(ForceDisp,'Position',[150 50 200 100],'FontSize',50,'BackgroundColor','r','Callback',@pushbutton_callback);
% EB.Text = 'ERROR!';

%Initialize pre-set parameters 
Frame = -1;
SkippedFrames = [];
Counter = 1;
tStart = tic;
trial = 1;
alpha_EV = [];
beta_EV = [];
AllResponses = [];

%User interface
Fig = uifigure('Position',[2000 0 560 650]);
gl = uigridlayout(Fig,[4,4]);
gl.RowHeight = {25,50,400,100};
gl.ColumnWidth = {50,150,150,150};

%Message bar
message_text = uitextarea(gl,'HorizontalAlignment','center');
message_text.Layout.Row = 1;
message_text.Layout.Column = [1 4];

%Trial numbers
trial_label = uilabel(gl,'Text', 'Trial','FontSize',25);
trial_label.Layout.Row = 2;
trial_label.Layout.Column = 1;
trial_text = uitextarea(gl,'FontSize',20,'BackgroundColor',[0.93,0.93,0.93]);
trial_text.Layout.Row = 3;
trial_text.Layout.Column = 1;

%Start position texts
start_pos_label = uilabel(gl,'Text', 'Start Positions','FontSize',25);
start_pos_label.Layout.Row = 2;
start_pos_label.Layout.Column = 2;
start_pos_text = uitextarea(gl,'FontSize',20);
start_pos_text.Layout.Row = 3;
start_pos_text.Layout.Column = 2;

%Stimulus position texts
stim_pos_label = uilabel(gl,'Text', 'Stim Position','FontSize',25);
stim_pos_label.Layout.Row = 2;
stim_pos_label.Layout.Column = 3;
stim_pos_text = uitextarea(gl,'FontSize',20);
stim_pos_text.Layout.Row = 3;
stim_pos_text.Layout.Column = 3;

%Response texts
resp_label = uilabel(gl,'Text', '  Responses','FontSize',25);
resp_label.Layout.Row = 2;
resp_label.Layout.Column = 4;
resp_text = uitextarea(gl,'FontSize',20);
resp_text.Layout.Row = 3;
resp_text.Layout.Column = 4;

%Buttons 
L_btn = uibutton(gl,'BackgroundColor','g','Text','Left','FontSize',50,'ButtonPushedFcn',{@left_callback});
L_btn.Layout.Row = 4;
L_btn.Layout.Column = 2;

R_btn = uibutton(gl,'BackgroundColor','g','Text','Right','FontSize',50,'ButtonPushedFcn',{@right_callback});
R_btn.Layout.Row = 4;
R_btn.Layout.Column = 3;

Err_btn = uibutton(gl,'BackgroundColor','r','Text','Error!','FontSize',50,'ButtonPushedFcn',{@error_callback});
Err_btn.Layout.Row = 4;
Err_btn.Layout.Column = 4;

Switch = uiswitch(gl,'toggle','Items', {'Go','Stop'}, 'ValueChangedFcn',@switchMoved);
Switch.Layout.Row = 4;
Switch.Layout.Column = 1;

Fig.UserData = struct("Resp_Text", resp_text, "Trials", trial_text, "Switch", Switch, "Message", message_text);
message_text.Value = 'Moving to start position';

% Loop until the message box is dismissed
while trial <= Ntrials

  drawnow limitrate;
  Counter = Counter + 1;
  
%   Get a frame
%   fprintf( 'Waiting for new frame...' );
  while MyClient.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
    fprintf( '.' );
  end% while
%   fprintf( '\n' );   

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
%   fprintf( 'Frame Number: %d\n', Output_GetFrameNumber.FrameNumber );

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
  if ForceRatio > 0 && ForceRatio*100 < inf
    FG.Value = ForceRatio;    
  end
  
  %------------------------------------------------------------------------
  %------------------------------------------------------------------------
  %PSI Algorithm
  %------------------------------------------------------------------------
  %------------------------------------------------------------------------
  
  %Stops when the participant reaches the start position 
  if MkrDiff == startpos
      
%       disp(['Trial # ' num2str(trial) ':']);
%       disp(['Start pos: ' num2str(startpos)]);
      StartSpeeds(trial) = speed; %Record the speed
      
      AllTrials(trial) = trial; 

      trial_text.Value = sprintf('%d \n',AllTrials);
      scroll(trial_text,'bottom');      
      start_pos_text.Value = sprintf('%d \n',AllStarts);
%       scroll(start_pos_text,'bottom');

      %Stop treadmill
      TMtestSpeed = 0;  
      %Format treadmill input
      %If test leg is right the right moves and vice versa; the treadmill
      %input is formatted as right belt speed first then left belt speed
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

      %Reset start position
      startpos = nan;
      pause(2*rand(1)); %Pause for a random time period from 0-2 seconds 

      %Set the stimulus position
      stimulus = AllStims(trial);
      
      %Move treadmill to new stimulus position   
      speed = round(minspeed + (maxspeed-minspeed)*rand);
      if stimulus < MkrDiff
          TMtestSpeed = speed;
      else
          TMtestSpeed = -speed;
      end
          
      message_text.Value = ['Moving to stimulus position (speed=' num2str(speed) ')'];

  %Stops when the limb position equals the stimulus    
  elseif MkrDiff == stimulus
       
%       disp(['Stimulus: ' num2str(stimulus)]);
      StimSpeeds(trial) = speed; %Record the speed

      stim_pos_text.Value = sprintf('%d \n', AllStims);
%       scroll(stim_pos_text,'bottom');

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
      
      %Prompt subject to answer question with visual feedback
      normlbl.Visible = 'off';
      choicelbl.Visible = 'on';
      LB.Visible = 'on';
      RB.Visible = 'on';
      
      %Stop the trial and wait for input
      message_text.Value = 'At stimulus location, make selection';

      Switch.Value = 'Stop';
      uiwait(Fig);
      
%       response = input(['Response (r or l)?'],'s');
%       while strcmp(response,'r')==0 && strcmp(response,'l')==0
%           disp('incorrect response entered');
%           response = input(['Trial # ' num2str(trial) '; Response (r or l)?'],'s');
%       end
%       if trial == 1
%           response = input(['Re-enter response: '],'s');
%       end

      response = Fig.UserData.Resp_Text.Value{end};
      AllResponses{trial} = response;
      
      %Convert the resoponse to a binary response (probability of left)
      if strcmp(response,'left')==1
          BinaryResponses(trial) = 1;
      elseif strcmp(response,'right')==1
          BinaryResponses(trial) = 0;
      end
      
      %Go back to stand normally prompt
      normlbl.Visible = 'off';
      choicelbl.Visible = 'off';
      LB.Visible = 'off';
      RB.Visible = 'off';
      
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
      
      %Reset stimulus position
      stimulus = nan;
      
      %Move to the next trial
      trial = trial+1;
      if trial > Ntrials
          break
      elseif trial == 26 %Break at 25 
          message_text.Value = '25 trial break. Flip switch to continue';
          Switch.Value = 'Stop';
          uiwait(Fig);
      elseif trial==51 %Break at 50 
          message_text.Value = '50 trial break. Flip switch to continue';
          Switch.Value = 'Stop';          
          uiwait(Fig);
      end
      
      if trial==extreme_trials(et_idx)
          AllStims(trial) = extreme_stims(et_idx);
          et_idx = et_idx+1;
      elseif trial==iqr_trials(iqr_idx)
          addsub = [-40,-30,30,40];
          potential_stims = round(alpha_EV(trial-1))+addsub; 
          new_stim = potential_stims(randi(length(potential_stims)));
          [~, stimidx] = min(abs(X-new_stim));
          AllStims(trial) = X(stimidx);
          iqr_idx = iqr_idx+1;
      else
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

      %Get a new start position 
      startpos = round(normrnd(AllStims(trial),strtpos_sigma));
      while TBidx(trial)==1 && startpos <= AllStims(trial) %This means that the start position should be above but it is below
          startpos = round(normrnd(AllStims(trial),strtpos_sigma));
      end
      while TBidx(trial)==0 && startpos >= AllStims(trial) %This means that the start position should be below but it is above
          startpos = round(normrnd(AllStims(trial),strtpos_sigma));
      end
      AllStarts(trial) = startpos;
      
      message_text.Value = ['Moving to start position (speed=' num2str(speed) ')'];

  else
      
      %Move treadmill
%       speed = round(minspeed + (maxspeed-minspeed)*rand);
      if startpos < MkrDiff || stimulus < MkrDiff
          TMtestSpeed = speed;
      else
          TMtestSpeed = -speed;
      end

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
   
end% while true  

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%End Trial-----------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
close(SubjDisp)

fclose(t);
delete(t);

% %Disconnect from Vicon
% fprintf( 'Time Elapsed: %d\n', tEnd );

if TransmitMulticast
  MyClient.StopTransmittingMulticast();
end  

% Disconnect and dispose
MyClient.Disconnect();

%Disconnect from Vicon
tEnd = toc( tStart );
minutes = tEnd / 60;
fprintf( 'Time Elapsed (minutes): %4.2f', minutes );

% % Unload the SDK
% fprintf( 'Unloading SDK...' );
% Client.UnloadViconDataStreamSDK();
% fprintf( 'done\n' );

% fprintf( 'Skipped %d frames\n', size(SkippedFrames,2) );

end