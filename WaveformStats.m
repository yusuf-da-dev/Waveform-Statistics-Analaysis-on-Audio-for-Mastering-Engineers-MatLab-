%% WaveformStatisticsAnalysis.m
clear; clc; close all;

makePlots = true;
saveTxtReport = true;


edgeCheckSeconds = 0.50;
lowBandCutoffHz = 120;
oversampleFactor = 8;   
clickSigma = 6;
rmsWindowMs = 50;       % short window min/max roo mean squared baby : square root of (1/T * integral (range 0 to T) of (f(t))^2 with respect to t)
clipThreshold = 0.9999; 

[fileName, filePath] = uigetfile( ...
    {'*.wav;*.flac;*.aif;*.aiff','Audio Files (*.wav,*.flac,*.aif,*.aiff)'}, ...
    'Pick a file to inspect');

if isequal(fileName,0)
    error('No file selected.');
end

fullName = fullfile(filePath, fileName);
[x, fs] = audioread(fullName);
x = double(x);

if isempty(x)
    error('File loaded as empty somehow.');
end

if size(x,2) == 1
    warning('Mono file found, duplicating channel so stereo checks still run.');
    x = [x x];
elseif size(x,2) > 2
    warning('More than 2 channels found, taking first 2 only.');
    x = x(:,1:2);
end

xRaw = x;

dcOffset = mean(xRaw,1);

x = xRaw - dcOffset;

L = x(:,1);
R = x(:,2);
mono = mean(x,2);

L_raw = xRaw(:,1);
R_raw = xRaw(:,2);
monoRaw = mean(xRaw,2);

nSamp = size(x,1);
durSec = nSamp / fs;
durMin = durSec / 60;
timeVec = (0:nSamp-1)'/fs;

report = {};
report{end+1} = 'PERSONAL MASTERING ASSISTANT V2';
report{end+1} = ['File: ' fileName];
report{end+1} = sprintf('Sample rate: %d Hz', fs);
report{end+1} = sprintf('Duration: %.2f sec (%.2f min)', durSec, durMin);
report{end+1} = ' ';

fprintf('\nLoaded: %s\n', fileName);
fprintf('Sample rate: %d Hz\n', fs);
fprintf('Duration: %.2f sec (%.2f min)\n\n', durSec, durMin);

edgeN = min(round(edgeCheckSeconds * fs), nSamp);
headChunk = x(1:edgeN,:);
tailChunk = x(end-edgeN+1:end,:);
headRMS = sqrt(mean(mean(headChunk.^2,2)));
tailRMS = sqrt(mean(mean(tailChunk.^2,2)));
headRMS_dB = 20*log10(headRMS + eps);
tailRMS_dB = 20*log10(tailRMS + eps);

fprintf('Head RMS (first %.2fs): %.2f dBFS\n', edgeCheckSeconds, headRMS_dB);
fprintf('Tail RMS (last %.2fs):  %.2f dBFS\n\n', edgeCheckSeconds, tailRMS_dB);
report{end+1} = sprintf('Head RMS: %.2f dBFS', headRMS_dB);
report{end+1} = sprintf('Tail RMS: %.2f dBFS', tailRMS_dB);

samplePeakL = max(abs(L_raw));
samplePeakR = max(abs(R_raw));
samplePeak = max([samplePeakL samplePeakR]);

samplePeakL_dBFS = 20*log10(samplePeakL + eps);
samplePeakR_dBFS = 20*log10(samplePeakR + eps);
samplePeak_dBFS  = 20*log10(samplePeak + eps);


x_os = resample(xRaw, oversampleFactor, 1);
truePeakL = max(abs(x_os(:,1)));
truePeakR = max(abs(x_os(:,2)));
truePeak = max([truePeakL truePeakR]);

truePeakL_dBTP = 20*log10(truePeakL + eps);
truePeakR_dBTP = 20*log10(truePeakR + eps);
truePeak_dBTP  = 20*log10(truePeak + eps);

fprintf('Sample peak L/R: %.2f / %.2f dBFS\n', samplePeakL_dBFS, samplePeakR_dBFS);
fprintf('Sample peak max: %.2f dBFS\n', samplePeak_dBFS);
fprintf('True peak L/R:   %.2f / %.2f dBTP\n', truePeakL_dBTP, truePeakR_dBTP);
fprintf('True peak max:   %.2f dBTP\n\n', truePeak_dBTP);

report{end+1} = sprintf('Sample peak L: %.2f dBFS', samplePeakL_dBFS);
report{end+1} = sprintf('Sample peak R: %.2f dBFS', samplePeakR_dBFS);
report{end+1} = sprintf('Sample peak max: %.2f dBFS', samplePeak_dBFS);
report{end+1} = sprintf('True peak L: %.2f dBTP', truePeakL_dBTP);
report{end+1} = sprintf('True peak R: %.2f dBTP', truePeakR_dBTP);
report{end+1} = sprintf('True peak max: %.2f dBTP', truePeak_dBTP);


loud = loudnessMeterBS1770(xRaw, fs);

estLUFS = loud.integratedLUFS;
momentaryLUFS = loud.momentaryLUFS;
momentaryTime = loud.momentaryTime;
shortTermLUFS = loud.shortTermLUFS;
shortTermTime = loud.shortTermTime;

momentaryMax = max(momentaryLUFS, [], 'omitnan');
momentaryMin = min(momentaryLUFS, [], 'omitnan');
momentaryMed = median(momentaryLUFS, 'omitnan');

shortTermMax = max(shortTermLUFS, [], 'omitnan');
shortTermMin = min(shortTermLUFS, [], 'omitnan');
shortTermMed = median(shortTermLUFS, 'omitnan');

fprintf('Integrated loudness: %.2f LUFS\n', estLUFS);
fprintf('Momentary loudness max/min/med: %.2f / %.2f / %.2f LUFS\n', momentaryMax, momentaryMin, momentaryMed);
fprintf('Short-term loudness max/min/med: %.2f / %.2f / %.2f LUFS\n\n', shortTermMax, shortTermMin, shortTermMed);

report{end+1} = sprintf('Integrated loudness: %.2f LUFS', estLUFS);
report{end+1} = sprintf('Momentary loudness max: %.2f LUFS', momentaryMax);
report{end+1} = sprintf('Momentary loudness min: %.2f LUFS', momentaryMin);
report{end+1} = sprintf('Momentary loudness median: %.2f LUFS', momentaryMed);
report{end+1} = sprintf('Short-term loudness max: %.2f LUFS', shortTermMax);
report{end+1} = sprintf('Short-term loudness min: %.2f LUFS', shortTermMin);
report{end+1} = sprintf('Short-term loudness median: %.2f LUFS', shortTermMed);

rmsWin = max(1, round((rmsWindowMs/1000) * fs));

L_rmsTrack = sqrt(movmean(L_raw.^2, rmsWin, 'Endpoints','shrink'));
R_rmsTrack = sqrt(movmean(R_raw.^2, rmsWin, 'Endpoints','shrink'));

L_maxRMS = max(L_rmsTrack);
L_minRMS = min(L_rmsTrack);
R_maxRMS = max(R_rmsTrack);
R_minRMS = min(R_rmsTrack);

L_maxRMS_dBFS = 20*log10(L_maxRMS + eps);
L_minRMS_dBFS = 20*log10(L_minRMS + eps);
R_maxRMS_dBFS = 20*log10(R_maxRMS + eps);
R_minRMS_dBFS = 20*log10(R_minRMS + eps);

fprintf('Max RMS L/R (%d ms): %.2f / %.2f dBFS\n', rmsWindowMs, L_maxRMS_dBFS, R_maxRMS_dBFS);
fprintf('Min RMS L/R (%d ms): %.2f / %.2f dBFS\n\n', rmsWindowMs, L_minRMS_dBFS, R_minRMS_dBFS);

report{end+1} = sprintf('Max RMS L (%d ms): %.2f dBFS', rmsWindowMs, L_maxRMS_dBFS);
report{end+1} = sprintf('Max RMS R (%d ms): %.2f dBFS', rmsWindowMs, R_maxRMS_dBFS);
report{end+1} = sprintf('Min RMS L (%d ms): %.2f dBFS', rmsWindowMs, L_minRMS_dBFS);
report{end+1} = sprintf('Min RMS R (%d ms): %.2f dBFS', rmsWindowMs, R_minRMS_dBFS);

clippedSamplesL = sum(abs(L_raw) >= clipThreshold);
clippedSamplesR = sum(abs(R_raw) >= clipThreshold);

dcOffsetL = dcOffset(1);
dcOffsetR = dcOffset(2);
dcOffsetL_dBFS = 20*log10(abs(dcOffsetL) + eps);
dcOffsetR_dBFS = 20*log10(abs(dcOffsetR) + eps);

fprintf('Possibly clipped samples L/R: %d / %d\n', clippedSamplesL, clippedSamplesR);
fprintf('DC offset L/R: %.8f / %.8f FS\n', dcOffsetL, dcOffsetR);
fprintf('DC offset L/R: %.2f / %.2f dBFS\n\n', dcOffsetL_dBFS, dcOffsetR_dBFS);

report{end+1} = sprintf('Possibly clipped samples L: %d', clippedSamplesL);
report{end+1} = sprintf('Possibly clipped samples R: %d', clippedSamplesR);
report{end+1} = sprintf('DC offset L: %.8f FS (%.2f dBFS)', dcOffsetL, dcOffsetL_dBFS);
report{end+1} = sprintf('DC offset R: %.8f FS (%.2f dBFS)', dcOffsetR, dcOffsetR_dBFS);

rmsWhole = sqrt(mean(mono.^2));
peakMono = max(abs(mono));
crest_dB = 20*log10((peakMono + eps) / (rmsWhole + eps));

blockLen = max(1, round(0.4*fs));
numBlocks = floor(length(mono)/blockLen);
shortCrest = nan(numBlocks,1); 

for ii = 1:numBlocks
    s1 = (ii-1)*blockLen + 1;
    s2 = ii*blockLen;
    seg = mono(s1:s2);
    pk = max(abs(seg));
    rr = sqrt(mean(seg.^2));
    shortCrest(ii) = 20*log10((pk + eps)/(rr + eps));
end

shortCrestMed = median(shortCrest,'omitnan');
shortCrestP10 = prctile(shortCrest,10);
shortCrestP90 = prctile(shortCrest,90);
fprintf('Crest factor: %.2f dB\n', crest_dB);
fprintf('Median short crest: %.2f dB\n', shortCrestMed);
fprintf('Short crest 10th/90th pct: %.2f / %.2f dB\n\n', shortCrestP10, shortCrestP90);
report{end+1} = sprintf('Crest factor: %.2f dB', crest_dB);
report{end+1} = sprintf('Median short crest: %.2f dB', shortCrestMed);


LRcorr = corr(L,R,'rows','complete');
Lrms = sqrt(mean(L.^2));
Rrms = sqrt(mean(R.^2));
lrBalance_dB = 20*log10((Lrms + eps)/(Rrms + eps));

[bLow, aLow] = butter(4, lowBandCutoffHz/(fs/2), 'low');


L_low = filtfilt(bLow, aLow, L);
R_low = filtfilt(bLow, aLow, R);
lowCorr = corr(L_low, R_low,'rows','complete');
M_low = 0.5*(L_low + R_low);
S_low = 0.5*(L_low - R_low); 
Mlow_rms = sqrt(mean(M_low.^2));
Slow_rms = sqrt(mean(S_low.^2));
lowSideVsMid_dB = 20*log10((Slow_rms + eps)/(Mlow_rms + eps));
fprintf('Full-band stereo correlation: %.3f\n', LRcorr);
fprintf('L/R RMS balance: %.2f dB\n', lrBalance_dB);
fprintf('Low-end correlation (<%d Hz): %.3f\n', lowBandCutoffHz, lowCorr);
fprintf('Low-end SIDE vs MID: %.2f dB\n\n', lowSideVsMid_dB);
report{end+1} = sprintf('Full-band stereo correlation: %.3f', LRcorr);
report{end+1} = sprintf('L/R RMS balance: %.2f dB', lrBalance_dB);
report{end+1} = sprintf('Low-end correlation (<%d Hz): %.3f', lowBandCutoffHz, lowCorr);
report{end+1} = sprintf('Low-end SIDE vs MID: %.2f dB', lowSideVsMid_dB);


nfft = 8192;
[pxx, f] = pwelch(mono, hann(nfft), round(0.5*nfft), nfft, fs, 'power');
bandMean = @(f1,f2) mean(pxx(f>=f1 & f<=f2));
bandDB   = @(f1,f2) 10*log10(bandMean(f1,f2) + eps);
sub_dB      = bandDB(20,60);
bass_dB     = bandDB(60,120);
lowmid_dB   = bandDB(120,350);
mud_dB      = bandDB(200,400);
body_dB     = bandDB(400,1000);
presence_dB = bandDB(4000,7000);
sib_dB      = bandDB(5000,10000);
air_dB      = bandDB(10000,16000);
mudVsBody = mud_dB - body_dB;
sibVsPres = sib_dB - presence_dB;
airVsPres = air_dB - presence_dB;
subVsBass = sub_dB - bass_dB;

fprintf('Sub 20-60 Hz: %.2f dB\n', sub_dB);
fprintf('Bass 60-120 Hz: %.2f dB\n', bass_dB);
fprintf('Low-mid 120-350 Hz: %.2f dB\n', lowmid_dB);
fprintf('Mud 200-400 Hz: %.2f dB\n', mud_dB);
fprintf('Body 400-1k Hz: %.2f dB\n', body_dB);
fprintf('Presence 4-7 kHz: %.2f dB\n', presence_dB);
fprintf('Sibilance 5-10 kHz: %.2f dB\n', sib_dB);
fprintf('Air 10-16 kHz: %.2f dB\n\n', air_dB);

report{end+1} = sprintf('Mud vs body: %.2f dB', mudVsBody);
report{end+1} = sprintf('Sibilance vs presence: %.2f dB', sibVsPres);
report{end+1} = sprintf('Air vs presence: %.2f dB', airVsPres);
report{end+1} = sprintf('Sub vs bass: %.2f dB', subVsBass);


Nw = 2048;
Nh = 512;
[S, F, T] = spectrogram(mono, hann(Nw), Nw-Nh, Nw, fs);
Smag = abs(S).^2;

sibMask = F >= 5000 & F <= 10000;
presMask = F >= 4000 & F <= 7000;

sibTrack = 10*log10(mean(Smag(sibMask,:),1) + eps);
presTrack = 10*log10(mean(Smag(presMask,:),1) + eps);

sibRel = sibTrack - presTrack;
sibBurstiness = prctile(sibRel,95);

fprintf('Sibilance burstiness (95th pct relative): %.2f dB\n\n', sibBurstiness);
report{end+1} = sprintf('Sibilance burstiness (95th pct rel): %.2f dB', sibBurstiness);

dmono = abs(diff(mono)); 
thr = mean(dmono) + clickSigma*std(dmono);
clickCount = sum(dmono > thr);
clicksPerMin = clickCount / max(durMin, eps);

fprintf('Transient outlier rate: %.2f per min\n\n', clicksPerMin);
report{end+1} = sprintf('Transient outlier rate: %.2f per min', clicksPerMin);

disp('Suggestions');
report{end+1} = ' ';
report{end+1} = 'Suggestions:';

if headRMS_dB < -55
    msg = '- Start looks very quiet. Check if there is dead air to trim.';
else
    msg = '- Start does not look obviously silent. Still check top manually by ear.';
end
disp(msg); report{end+1} = msg;

if tailRMS_dB < -55
    msg = '- End looks very quiet. Check if the fade/tail is intentional rather than leftover silence.';
else
    msg = '- Tail still has level. Make sure the ending/fade feels musical rather than messy.';
end
disp(msg); report{end+1} = msg;

if abs(lrBalance_dB) > 0.6
    msg = sprintf('- Stereo balance is a bit off (%.2f dB L/R). Worth checking before final limiting.', lrBalance_dB);
else
    msg = '- L/R balance looks basically okay.';
end
disp(msg); report{end+1} = msg;

if LRcorr < 0.1
    msg = sprintf('- Full-band stereo correlation is quite low (%.3f). Definitely mono-check this.', LRcorr);
elseif LRcorr < 0.4
    msg = sprintf('- Stereo is quite wide (corr %.3f). Probably okay, but still mono-check it.', LRcorr);
else
    msg = sprintf('- Stereo correlation looks healthy overall (%.3f).', LRcorr);
end
disp(msg); report{end+1} = msg;

if lowCorr < 0.7 || lowSideVsMid_dB > -18
    msg = sprintf('- Vinyl warning: low-end stereo/phase risk (corr %.3f, side-mid %.2f dB).', lowCorr, lowSideVsMid_dB);
    disp(msg); report{end+1} = msg;
    msg2 = '  Consider M/S EQ and gently narrowing or filtering the SIDE below about 80-100 Hz.';
    disp(msg2); report{end+1} = msg2;
else
    msg = '- Low end looks reasonably mono-compatible for vinyl.';
    disp(msg); report{end+1} = msg;
end

if mudVsBody > -1.5
    msg = sprintf('- Low-mid might be a bit thick (mud vs body = %.2f dB).', mudVsBody);
    disp(msg); report{end+1} = msg;
    msg2 = '  If it sounds cloudy, try a broad tiny cut around 250-350 Hz. Keep it subtle.';
    disp(msg2); report{end+1} = msg2;
else
    msg = '- Mud region does not look massively overcooked.';
    disp(msg); report{end+1} = msg;
end

if sibVsPres > -2 || sibBurstiness > 2
    msg = sprintf('- Sibilance might need attention (avg rel %.2f dB, burstiness %.2f dB).', sibVsPres, sibBurstiness);
    disp(msg); report{end+1} = msg;
    msg2 = '  For vinyl especially, de-esser / dynamic EQ / manual spectral cleanup could help.';
    disp(msg2); report{end+1} = msg2;
else
    msg = '- Sibilance is not screaming numerically, but still listen to the esses manually.';
    disp(msg); report{end+1} = msg;
end

if airVsPres < -8
    msg = sprintf('- Top end may be a bit tucked in (air vs presence = %.2f dB).', airVsPres);
    disp(msg); report{end+1} = msg;
    msg2 = '  Maybe a very gentle shelf above 10-12 kHz if the references actually support it.';
    disp(msg2); report{end+1} = msg2;
else
    msg = '- Air band looks reasonably present.';
    disp(msg); report{end+1} = msg;
end

if subVsBass > 1.5
    msg = sprintf('- Sub looks stronger than upper bass by %.2f dB.', subVsBass);
    disp(msg); report{end+1} = msg;
    msg2 = '  Check for rumble or over-heavy subs, especially if vinyl is one of the deliverables.';
    disp(msg2); report{end+1} = msg2;
else
    msg = '- Sub-to-bass relationship does not look extreme.';
    disp(msg); report{end+1} = msg;
end

if crest_dB < 7
    msg = sprintf('- Crest factor is low (%.2f dB): already dense, so do not smash it further.', crest_dB);
    disp(msg); report{end+1} = msg;
    msg2 = '  If you need more level, clip-before-limit is probably safer than just hammering the limiter.';
    disp(msg2); report{end+1} = msg2;
elseif crest_dB > 12
    msg = sprintf('- Crest factor is pretty high (%.2f dB): there may be room for gentle glue compression.', crest_dB);
    disp(msg); report{end+1} = msg;
else
    msg = sprintf('- Crest factor is in a workable middle area (%.2f dB).', crest_dB);
    disp(msg); report{end+1} = msg;
end

if clicksPerMin > 20
    msg = sprintf('- There may be clicks/ticks/edit spikes (%.2f per min heuristic).', clicksPerMin);
    disp(msg); report{end+1} = msg;
    msg2 = '  Worth checking in RX declick / spectral repair, or at least zooming in on obvious bits.';
    disp(msg2); report{end+1} = msg2;
else
    msg = '- No huge click problem flagged by the rough detector.';
    disp(msg); report{end+1} = msg;
end

if clippedSamplesL > 0 || clippedSamplesR > 0 || truePeak_dBTP > 0
    msg = sprintf('- Ceiling warning: clipped samples L/R = %d / %d, TP max = %.2f dBTP.', clippedSamplesL, clippedSamplesR, truePeak_dBTP);
    disp(msg); report{end+1} = msg;
else
    msg = '- No obvious clipping/ISP disaster flagged.';
    disp(msg); report{end+1} = msg;
end

if abs(dcOffsetL) > 1e-3 || abs(dcOffsetR) > 1e-3
    msg = sprintf('- DC offset is a bit higher than i would like (L %.6f, R %.6f).', dcOffsetL, dcOffsetR);
    disp(msg); report{end+1} = msg;
else
    msg = '- DC offset looks negligible.';
    disp(msg); report{end+1} = msg;
end

disp(' ');
disp('Delivery format notes');
report{end+1} = ' ';
report{end+1} = 'Delivery format notes:';

msg = 'STREAMING / DIGITAL';
disp(msg); report{end+1} = msg;

if truePeak_dBTP > -1
    msg = sprintf('- True peak %.2f dBTP -> too hot for a safer streaming deliverable.', truePeak_dBTP);
else
    msg = sprintf('- True peak %.2f dBTP -> okay for streaming ceiling.', truePeak_dBTP);
end
disp(msg); report{end+1} = msg;

if estLUFS > -10
    msg = sprintf('- Loudness %.2f LUFS -> probably too pushed for this brief.', estLUFS);
elseif estLUFS >= -13 && estLUFS <= -10
    msg = sprintf('- Loudness %.2f LUFS -> sensible modern streaming zone.', estLUFS);
else
    msg = sprintf('- Loudness %.2f LUFS -> quieter side, maybe okay if musically right.', estLUFS);
end
disp(msg); report{end+1} = msg;

msg = '- Deliver at original sample rate / bit depth. FLAC makes sense here because of metadata embedding.';
disp(msg); report{end+1} = msg;

disp(' ');
msg = 'CD';
disp(msg); report{end+1} = ' '; report{end+1} = msg;

if truePeak_dBTP > -0.3
    msg = sprintf('- For CD this is a bit hot at %.2f dBTP if you want safer headroom.', truePeak_dBTP);
else
    msg = sprintf('- True peak %.2f dBTP is in a sensible place for CD.', truePeak_dBTP);
end
disp(msg); report{end+1} = msg;

msg = '- Export 44.1 kHz / 16-bit dithered WAV.';
disp(msg); report{end+1} = msg;

msg = '- Around -9 LUFS is a decent working target, but quality matters more than forcing loudness.';
disp(msg); report{end+1} = msg;

disp(' ');
msg = 'VINYL';
disp(msg); report{end+1} = ' '; report{end+1} = msg;

if lowCorr < 0.7 || lowSideVsMid_dB > -18
    msg = '- Fix the low-end stereo issue first before calling this vinyl-ready.';
else
    msg = '- Low-end mono compatibility looks decent for vinyl.';
end
disp(msg); report{end+1} = msg;

if sibVsPres > -2 || sibBurstiness > 2
    msg = '- De-essing / dynamic HF control is worth serious attention for vinyl.';
else
    msg = '- Sibilance is not being flagged hard, but still listen carefully before any vinyl deliverable.';
end
disp(msg); report{end+1} = msg;

msg = '- Keep limiting light. Original sample rate / bit depth. Do not flatten the life out of it.';
disp(msg); report{end+1} = msg;

disp(' ');
msg = 'BROADCAST / TV / FILM';
disp(msg); report{end+1} = ' '; report{end+1} = msg;

if truePeak_dBTP > -1
    msg = sprintf('- True peak %.2f dBTP -> too high for EBU-style broadcast delivery.', truePeak_dBTP);
else
    msg = sprintf('- True peak %.2f dBTP -> okay for broadcast ceiling.', truePeak_dBTP);
end
disp(msg); report{end+1} = msg;

msg = sprintf('- Loudness is %.2f LUFS. Actual broadcast master would need to land around -23 LUFS.', estLUFS);
disp(msg); report{end+1} = msg;

disp(' ');
disp('Admin / project reminder');
disp('- Remember metadata + ISRC still need sorting as part of the deliverables.'); 
disp('- Streaming folder = FLAC with metadata.');
disp('- CD = 44.1k / 16-bit dithered WAV.');
disp('- Broadcast = WAV and proper broadcast metadata workflow.');
disp('- Vinyl = keep original sample rate/bit depth and split sides properly.');

report{end+1} = ' ';
report{end+1} = 'Admin reminder: metadata / ISRC / format-specific exports still need doing.';

if makePlots
    figure('Name','Personal Mastering Assistant V2','Color','w');

    subplot(4,1,1);
    plot(timeVec, mono, 'k');
    xlabel('Time (s)');
    ylabel('Amp');
    title('Mono waveform');

    subplot(4,1,2);
    spectrogram(mono, 1024, 768, 1024, fs, 'yaxis');
    title('Spectrogram');

    subplot(4,1,3);
    semilogx(f, 10*log10(pxx + eps), 'k');
    grid on;
    xlabel('Frequency (Hz)');
    ylabel('PSD (dB)');
    title('Average spectrum');
    xlim([20 min(fs/2, 20000)]);

    subplot(4,1,4);
    plot(momentaryTime, momentaryLUFS, 'b'); hold on;
    plot(shortTermTime, shortTermLUFS, 'r');
    yline(estLUFS, '--k');
    grid on;
    xlabel('Time (s)');
    ylabel('LUFS');
    title('Loudness trace');
    legend('Momentary (400 ms)','Short-term (3 s)','Integrated','Location','best');
end

if saveTxtReport
    [~, baseName, ~] = fileparts(fileName);
    outTxt = fullfile(filePath, [baseName '_mastering_report.txt']);

    fid = fopen(outTxt, 'w');
    if fid == -1
        warning('Could not write text report.');
    else
        for i = 1:numel(report)
            fprintf(fid, '%s\n', report{i});
        end
        fclose(fid);
        fprintf('\nSaved text report to:\n%s\n', outTxt);
    end
end

disp(' ');
disp('Done');
fprintf('Integrated loudness: %.2f LUFS\n', estLUFS);
fprintf('Momentary loudness max/min/med: %.2f / %.2f / %.2f LUFS\n', momentaryMax, momentaryMin, momentaryMed);
fprintf('Short-term loudness max/min/med: %.2f / %.2f / %.2f LUFS\n', shortTermMax, shortTermMin, shortTermMed);
fprintf('Sample peak L/R/max: %.2f / %.2f / %.2f dBFS\n', samplePeakL_dBFS, samplePeakR_dBFS, samplePeak_dBFS);
fprintf('True peak L/R/max: %.2f / %.2f / %.2f dBTP\n', truePeakL_dBTP, truePeakR_dBTP, truePeak_dBTP);
fprintf('Max RMS L/R: %.2f / %.2f dBFS\n', L_maxRMS_dBFS, R_maxRMS_dBFS);
fprintf('Min RMS L/R: %.2f / %.2f dBFS\n', L_minRMS_dBFS, R_minRMS_dBFS);
fprintf('Possibly clipped samples L/R: %d / %d\n', clippedSamplesL, clippedSamplesR);
fprintf('DC offset L/R: %.8f / %.8f FS\n', dcOffsetL, dcOffsetR);
fprintf('Crest factor: %.2f dB\n', crest_dB);
fprintf('Stereo corr: %.3f\n', LRcorr);
fprintf('Low corr < %d Hz: %.3f\n', lowBandCutoffHz, lowCorr);
fprintf('Sibilance burstiness: %.2f dB\n', sibBurstiness);
fprintf('Transient outlier rate: %.2f per min\n', clicksPerMin);

function out = loudnessMeterBS1770(x, fs)


    if size(x,2) > 5
        x = x(:,1:5); 
    end

    targetFs = 48000;
    if fs ~= targetFs
        x = resample(x, targetFs, fs); 
        fs = targetFs;
    end

    y = kWeightFilter48k(x);

   
    energy = sum(y.^2, 2);

    out.momentaryWinSec = 0.400;
    out.shortTermWinSec = 3.000;
    out.hopSec = 0.100;

    [out.momentaryLUFS, out.momentaryTime, momentaryEnergy] = slidingLoudnessFromEnergy(energy, fs, out.momentaryWinSec, out.hopSec);
    [out.shortTermLUFS, out.shortTermTime, shortTermEnergy] = slidingLoudnessFromEnergy(energy, fs, out.shortTermWinSec, out.hopSec);

    
    blockLoudness = -0.691 + 10*log10(momentaryEnergy + eps);

    absMask = blockLoudness >= -70;
    if ~any(absMask)
        out.integratedLUFS = -Inf;
        return;
    end

    relGate = -0.691 + 10*log10(mean(momentaryEnergy(absMask)) + eps) - 10;
    finalMask = absMask & (blockLoudness >= relGate);

    if ~any(finalMask)
        out.integratedLUFS = -Inf;
        return;
    end

    out.integratedLUFS = -0.691 + 10*log10(mean(momentaryEnergy(finalMask)) + eps);
end

function [LU, tCenter, blockEnergy] = slidingLoudnessFromEnergy(energy, fs, winSec, hopSec)


    winLen = max(1, round(winSec * fs));
    hopLen = max(1, round(hopSec * fs));

    n = length(energy);
    if n < winLen
        energy = [energy; zeros(winLen - n, 1)];
        n = length(energy);
    end

    numBlocks = 1 + floor((n - winLen) / hopLen);
    blockEnergy = zeros(numBlocks,1);
    tCenter = zeros(numBlocks,1);

    for ii = 1:numBlocks
        idx1 = 1 + (ii-1)*hopLen;
        idx2 = idx1 + winLen - 1;
        seg = energy(idx1:idx2);

        blockEnergy(ii) = mean(seg);
        tCenter(ii) = ((idx1 + idx2)/2 - 1) / fs;
    end

    LU = -0.691 + 10*log10(blockEnergy + eps);
end

function y = kWeightFilter48k(x)

    b1 = [1.53512485958697  -2.69169618940638   1.19839281085285];
    a1 = [1.00000000000000  -1.69065929318241   0.73248077421585];

    b2 = [1.00000000000000  -2.00000000000000   1.00000000000000];
    a2 = [1.00000000000000  -1.99004745483398   0.99007225036621];

    y = filter(b1, a1, x);
    y = filter(b2, a2, y);
end
