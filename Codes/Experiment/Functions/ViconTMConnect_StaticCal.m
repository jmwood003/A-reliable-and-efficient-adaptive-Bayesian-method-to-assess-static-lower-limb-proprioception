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

HostName = 'localhost:801';

% Load the SDK
fprintf( 'Loading SDK...' );
addpath( '..\dotNET' );
dssdkAssembly = which('ViconDataStreamSDK_DotNET.dll');
NET.addAssembly(dssdkAssembly);
fprintf( 'done\n' );

% Make a new client
MyClient = ViconDataStreamSDK.DotNET.Client();

% Connect to a server
fprintf( 'Connecting to %s ...', HostName );
while ~MyClient.IsConnected().Connected
  % Direct connection
  MyClient.Connect( HostName );
  fprintf( '.' );
end
fprintf( '\n' );

% Enable some different data types
MyClient.EnableSegmentData();
MyClient.EnableMarkerData();
MyClient.EnableUnlabeledMarkerData();
MyClient.EnableDeviceData();

% Set the streaming mode and buffer size
MyClient.SetBufferSize(1)
MyClient.SetStreamMode( ViconDataStreamSDK.DotNET.StreamMode.ClientPull  );

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
  
  while MyClient.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
    fprintf( '.' );
  end% while
  
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


if TransmitMulticast
  MyClient.StopTransmittingMulticast();
end  

% Disconnect and dispose
MyClient.Disconnect();

end