% initial clear
close all
clear all
clc

% title
fprintf('Comparação de Resultados de uma FFT\n\n');

% number of points to generate
N = 8192;

% sampling frequency; fs = 8KHz
fs = 8E3;

% 
fn = 329.6;

% generate a time vector discretized
t = 0: 1/fs: N/fs-1/fs;

% generate a frequency vector discretized
freq = 0:fs/N:fs*(1-1/N);

% function to discretize
y = (sin(2*pi*fn*t))/(2^(log(N)/log(2)));

% apply Fast Fourier Transform (FFT) to y points
z = fft(y);

% display signal
figure()
plot(t,y)
title('Sinal de Entrada - math script');
xlabel('Tempo (s)');
ylabel('Amplitude');
grid on;
axis;
print('x_math','-dpdfcrop', '-svgconvert', '-bestfit')

% load test results
load './xinput.m'

% generate real vector
for k = 1:N
	re(k) = xinput(2*k-1)/2^31;
end

% display signal
figure()
plot(t,re)
title('Sinal de Entrada - Programa em C');
xlabel('Tempo (s)');
ylabel('Amplitude');
grid on;
axis;
print('x_c','-dpdfcrop', '-svgconvert', '-bestfit')

% display results of FFT in order to frequency
figure()
plot(freq,abs(z))
title('Resultado da FFT - math script');
xlabel('Frequência (Hz)');
ylabel('Amplitude');
grid on;
axis([0 fs 0 .35]);
print('fft_math','-dpdfcrop', '-svgconvert', '-bestfit')

% load test results
load './Xoutput.m'

% generate complex vector
for k = 1:N
	comp(k) = (Xoutput(2*k-1)+1i*Xoutput(2*k))/2^31;
end

% display results of FFT test in order to frequency
figure()
plot(freq,abs(comp))
title('Resultado da FFT - Programa em C');
xlabel('Frequência (Hz)');
ylabel('Amplitude');
grid on;
axis([0 fs 0 .35]);
print('fft_c','-dpdfcrop', '-svgconvert', '-bestfit')

% Print results to terminal
fn
fprintf('Índices dos máximos:\ni = %g\n',find(abs(comp) == max(abs(comp)),1,'first'));

fprintf('\nIntervalo de frequências:\nf0 = %g, f1 = %g, f-1 = %g\n',freq(find(abs(comp) == max(abs(comp)),1,'first')),freq(1+find(abs(comp) == max(abs(comp)),1,'first')),freq(-1+find(abs(comp) == max(abs(comp)),1,'first')));

fprintf('\nValores a guardar:\nRef0 = %g, Imf0 = %g\nRef1 = %g, Imf1 = %g\nRef-1 = %g, Imf-1 = %g\n',Xoutput(2*find(abs(comp) == max(abs(comp)),1,'first')),Xoutput(1+2*find(abs(comp) == max(abs(comp)),1,'first')),Xoutput(2*(1+find(abs(comp) == max(abs(comp)),1,'first'))),Xoutput(1+2*(1+find(abs(comp) == max(abs(comp)),1,'first'))),Xoutput(2*(-1+find(abs(comp) == max(abs(comp)),1,'first'))),Xoutput(-1+2*(1+find(abs(comp) == max(abs(comp)),1,'first'))));
