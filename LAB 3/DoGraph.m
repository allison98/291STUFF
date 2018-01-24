function DoGraph()

try
 fclose(instrfind);
end;

s1 = serial('COM4', ... % Change as needed!
 'BaudRate', 115200, ...
 'Parity', 'none', ...
 'DataBits', 8, ...
 'StopBits', 1, ...
 'FlowControl', 'none');
fopen(s1);

try
 fprintf('Press CTRL+C to finish\n');
 
 figure(1);  
    ax = gca;
    ylim([0 40]);
    xlim([0 10]);
    xlabel('Time', 'fontsize', 12)
    ylabel('Voltage', 'fontsize', 12)
    title('Voltage', 'fontsize', 14)

    t = 1;
    t0 = datevec(now);

    while t>0
       % Get timestamp
       t1 = datevec(now);
       x = etime(t1,t0);

       val=fscanf(s1);
       y = sscanf(val, '%f');

       hold on;
       p = plot(x,y, '-o');    
       set(p,'linewidth',2);
       xlim([x-5 x+5]);
       drawnow limitrate;
    end
   
% i = 0;
% x=0;
 
 %while (1)
     
   %  val=fscanf(s1);
  %   result = sscanf(val, '%f');
    % fprintf('T=%5.2fC\n', result);
     
  %   theplot = plot(x,result,'-o');
  %   StripChart('Initialize');
     
   %  StripChart('Update',theplot,result);
     
   %  x=x+1;
   %  i = i+1;
 %end
end
fclose(s1);
clear all;
fprintf('Closed');
end
