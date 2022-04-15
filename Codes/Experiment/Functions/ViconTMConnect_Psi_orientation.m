function ViconTMConnect_Psi_orientation(TLstr)

StartPos = [-60, 60];
EndPos = [-100, 100];

startpos = StartPos(1);
stimulus = nan; %Need the stimulus to be nan at first so the first treadmill stop is the start position 

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
if strcmp(TLstr,'Left')==1
    accR = 1500;
    accL = 100;   
elseif strcmp(TLstr,'Right')==1
    accL = 1500;
    accR = 100;      
else
  error('Input must be Left or Right');
end
TMtestSpeed = 0;   
TMrefSpeed = 0; 

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
FGtitle = uilabel(ForceDisp, 'Position',[175 300 300 200], 'FontSize',30);
FGtitle.Text = 'Force Ratio';
FG = uigauge(ForceDisp, 'semicircular', 'Position',[100 200 300 300],'Limits',[50 150]);
FG.ScaleColors = {'red','yellow','green','yellow','red'};
FG.ScaleColorLimits = [50 80; 80 90; 90 110; 110 120; 120 150];
LFtext = uilabel(ForceDisp,'Position',[70 80 300 200], 'FontSize',15);
LFtext.Text = {'Increased Left Forces'};
RFtext = uilabel(ForceDisp,'Position',[300 80 300 200], 'FontSize',15);
RFtext.Text = {'Increased Right Forces'};

%Initialize pre-set parameters 
Frame = -1;
SkippedFrames = [];
Counter = 1;
tStart = tic;
trial = 1; 

% Loop until the message box is dismissed
while trial <= 2

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
      
      disp(['Trial # ' num2str(trial) ':']);
      disp(['Start pos: ' num2str(startpos)]);
     
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
      pause(rand(1));

      %Set the stimulus position
      stimulus = EndPos(trial);
      
      %Move treadmill to new stimulus position    
      if stimulus < MkrDiff
          TMtestSpeed = 10;
      else
          TMtestSpeed = -10;
      end
      
  %Stops when the limb position equals the stimulus    
  elseif MkrDiff == stimulus
       
      disp(['Stimulus: ' num2str(stimulus)]);

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
      
      response = input(['Response (r or l)?'],'s');

      %Go back to stand normally prompt
      normlbl.Visible = 'off';
      choicelbl.Visible = 'off';
      LB.Visible = 'off';
      RB.Visible = 'off';

      %Reset stimulus position
      stimulus = nan;
      
      %Move to the next trial
      trial = trial+1;
      if trial > length(EndPos)
          break
      end
      
      %Get a new start position 
      startpos = StartPos(trial);

      disp(' ');
  else
      
      %Move treadmill
      if startpos < MkrDiff || stimulus < MkrDiff
          TMtestSpeed = 10;
      else
          TMtestSpeed = -10;
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