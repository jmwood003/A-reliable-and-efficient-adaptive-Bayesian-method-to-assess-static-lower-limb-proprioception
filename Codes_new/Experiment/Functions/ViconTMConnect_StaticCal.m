function [BslDiff, Lstart, Rstart] = ViconTMConnect_StaticCal(S,TLstr)

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
%Start Trial---------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
Frame = -1;
SkippedFrames = [];
t0 = clock;
Counter = 1;
% Loop until the message box is dismissed
while etime(clock, t0) < S

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
  LMALY(Counter) = Output_GetMarkerGlobalTranslation_Left.Translation( 2 );

  Output_GetMarkerGlobalTranslation_Left = MyClient.GetMarkerGlobalTranslation( SubjectName, 'RMAL' );
  RMALY(Counter) = Output_GetMarkerGlobalTranslation_Left.Translation( 2 );
    
  %Calculate marker difference (test minus reference)
  if strcmp(TLstr,'Left')==1
      MkrDiff(Counter) = LMALY(Counter) - RMALY(Counter); %In mm
  elseif strcmp(TLstr,'Right')==1
      MkrDiff(Counter) = RMALY(Counter) - LMALY(Counter); %In mm      
  else
      error('Input must be Left or Right');
  end
 
end% while true  

BslDiff = mean(MkrDiff);
Rstart = mean(RMALY);
Lstart = mean(LMALY);

% %Disconnect from Vicon
% fprintf( 'Time Elapsed: %d\n', tEnd );

if TransmitMulticast
  MyClient.StopTransmittingMulticast();
end  

% Disconnect and dispose
MyClient.Disconnect();

% % Unload the SDK
% fprintf( 'Unloading SDK...' );
% Client.UnloadViconDataStreamSDK();
% fprintf( 'done\n' );

% fprintf( 'Skipped %d frames\n', size(SkippedFrames,2) );

end