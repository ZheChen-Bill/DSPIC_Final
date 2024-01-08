clear; close all;

fsamp = 8000; % 8kHz
fcuts = [1500 2000]; % edge of passing band = 1.5kHz and Transition band = 0.5 kHz
mags = [1 0]; % Low pass filter
devs = [0.01 0.01]; % ripple (delta = 0.01; Attenuation = -20*log10(delta);)
delta = 0.01;
Attenuation = 20*log10(delta);
[n,Wn,beta,ftype] = kaiserord(fcuts,mags,devs,fsamp);
hh = fir1(n,Wn,ftype,kaiser(n+1,beta),'noscale');
fprintf('filter order = %d\n',n+1);
fprintf('Normalize frequency band edge = %d\n',Wn);
fprintf('beta = %d\n',beta);
h = freqz(hh,1,1024,fsamp);
figure(1) 
freqz(hh,1,1024,fsamp);
hold on

%save the file of coef
f = fopen('coef.txt','w');
fprintf(f,'%f\r\n',hh);
fclose(f);

% Plot frequency mask
w = 0:1:4000;
mask = zeros(size(w));
mask(w <= 1500) = 0; % Passband
mask(w >= 2000) = Attenuation; % Stopband
mask(w > 1500 & w < 2000) = interp1([1500,2000], [0, -40], w(w > 1500 & w < 2000)); % Transition
figure(1)
plot(w, mask, 'r--', 'LineWidth', 1);
hold off;
grid on;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
legend('Frequency Response', 'Mask');

% read the curve of the wordlength and SNR, assume MAC_WL = 64.(I choose wordlength = 14 for our further test)
fileIn = fopen('../code/data/SNR(change_wordlength).txt','r');
formatSpec = '%f';
SNR1 = fscanf(fileIn, formatSpec);

fileOut = fopen('../code/data/wordlength.txt','r');
formatSpec = '%f';
WL = fscanf(fileOut, formatSpec);

figure(2),
plot(WL,SNR1);
title("input word length vs SNR")
xlabel("input word length")
ylabel("SNR")

% read the curve of the MAC_wordlength and SNR, let word length = 14 (I choose MAC_wordlength = 20 for our further test)

fileIn = fopen('../code/data/SNR(change_MAC_wordlength).txt','r');
formatSpec = '%f';
SNR2 = fscanf(fileIn, formatSpec);

fileOut = fopen('../code/data/MAC_wordlength.txt','r');
formatSpec = '%f';
MAC_WL = fscanf(fileOut, formatSpec);

figure(3),
plot( MAC_WL, SNR2);
title("MAC wordlength vs SNR")
xlabel("MAC word length")
ylabel("SNR")

% To observe our test (input,output(floating),output(fixed))
fileIn = fopen('../code/data/inputsignal.txt','r');
formatSpec = '%f';
input = fscanf(fileIn, formatSpec);
figure(4),
freqz(input)
title("input spectrum")

fileIn = fopen('../code/data/outputsignal(floating).txt','r');
formatSpec = '%f';
output_floating = fscanf(fileIn, formatSpec);
figure(5)
freqz(output_floating)
title("output spectrum(floating point)")

fileOut = fopen('../code/data/outputsignal(fixed).txt','r');
formatSpec = '%f';
output_fixed = fscanf(fileOut, formatSpec);
figure(6)
freqz(output_fixed)
title("output spectrum(fixed point)")
