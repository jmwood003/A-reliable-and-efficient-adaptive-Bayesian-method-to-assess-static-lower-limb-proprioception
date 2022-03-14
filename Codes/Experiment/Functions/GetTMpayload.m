function Payload = GetTMpayload(TMspeedR, TMspeedL, accR, accL)

incline = 0;

%Format treadmill input
format=0;
speedRR=0;
speedLL=0;
accRR=0;
accLL=0;

aux=int16toBytes(round([TMspeedR TMspeedL speedRR speedLL accR accL accRR accLL incline]));
actualData=reshape(aux',size(aux,1)*2,1);
secCheck=255-actualData; %Redundant data to avoid errors in comm
padding=zeros(1,27);

%Set speeds
Payload=[format actualData' secCheck' padding];

end