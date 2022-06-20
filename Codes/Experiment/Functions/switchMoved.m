function switchMoved(src,event)

Fig = ancestor(src,"figure","toplevel");
if strcmp(src.Value,'Stop')==1
    uiwait(Fig);
elseif strcmp(src.Value,'Go')==1
    uiresume(Fig);
end  
    
end