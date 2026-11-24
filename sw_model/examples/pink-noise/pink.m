close all 
clear all

pkg load signal

Fs=48000;
TD = .1; % test duration in seconds
time=1/Fs:1/Fs:TD;
Nbits = 32;
N = 6;
freq = 0.5:0.5:24000;


% generate filter z plane
j=1;
for i=1:N-1
  Z(i) = (Fs/2- j*40)/(Fs/2);
  j *= 4;
end

j=1;
for  i=1:N
  P(i) = (Fs/2- j*20)/(Fs/2);
  j *= 4;
end

% create transfer function
[NUM, DEN] = zp2tf(Z,P,1);

%normalize gain to unity
NUM = NUM* sum(DEN)/sum(NUM);


% input white noise
x=2*(rand(1,length(time))-0.5);
x(1:N+1)=zeros(1,N+1);

%x=sin(2*pi*1000*time);

% poles and zeros
zplane(NUM,DEN);

%frequency response
figure
[H,w]=freqz(NUM, DEN, Fs);
semilogx(freq, 20*log10(abs(H)))
figure
semilogx(freq, angle(H) )

% time response
sys = tf(NUM,DEN,1/Fs);
figure
lsim(sys,x, time)


% create my own response
y = zeros(1, length(time));

for i=N+1:length(time) 
    acc = 0;
    bcc = 0;
    for j=1:length(NUM)
      acc += NUM(j) * x(i-j+1);
    end
    for j=2:length(DEN)
      bcc += DEN(j) * y(i-j+1);
    end
    y(i) = acc - bcc;
end

figure
plot(time, y) 


% print filter coeffs

fn = fopen ("NUM.txt", "w");

for i=1:length(NUM)-1
  fprintf(fn,"%.20f, \n", NUM(i));
end 
fprintf(fn,"%.20f\n", NUM(length(NUM)));

fclose(fn);


fd = fopen ("DEN.txt", "w");

for i=2:length(DEN)-1
  fprintf(fd,"%.20f, \n", DEN(i));
end
    fprintf(fd,"%.20f\n", DEN(length(DEN)));

fclose(fd);
