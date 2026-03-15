clear;clear; close all; clc;

%% Configurazione File
filename_target = "3_12_2025_FacultyTest5.mat";      % File con persone
filename_background = "3_12_2025_FacultyTest3.mat";  % File ambiente vuoto

%% Configurazione Video
% video_name = 'Radar_Movie.avi';
% v = VideoWriter(video_name);
% v.FrameRate = 10; % 10 frame al secondo (rallentato per vedere meglio)
% open(v);
% 
% disp('Generazione video in corso... attendere...');
% 
% % Creiamo una figura invisibile per il rendering
% hFig = figure('Visible', 'off');

%% Inizializzazione assi e dati comuni
disp('Caricamento parametri iniziali...');
% Carichiamo un file solo per leggere le dimensioni e l'asse Range
temp = load(filename_target);
adc_dim = size(temp.adc_dataTot); % [FastTime, SlowTime, Antenna, Frames]
v_target = temp.v_target;

Fast_Time = adc_dim(1);
Slow_Time = adc_dim(2);
Antenna = adc_dim(3);

% Definizione Assi
R = temp.R; % Asse Range originale
idx_start = Fast_Time/2; 
idx_end = Fast_Time;
R_positive = R(idx_start : idx_end); % Asse Range tagliato (solo positivi)

% Asse Azimuth
azimuth = linspace(-60, 60, Antenna);

% Accumulatori per mappe RANGE-DOPPLER e RANGE-AZIMUTH
SumFrame_RD_Target = zeros(length(R_positive),Slow_Time); % Range-Doppler
SumFrame_RA_Target = zeros(length(R_positive), Antenna);  % Range-Azimuth Target
SumFrame_RA_BG = zeros(length(R_positive), Antenna);      % Range-Azimuth Background
SumFrame_RA_mti_Target = zeros(length(R_positive), Antenna);  % Range-Azimuth MTI

%% FILE CON TARGET: Caricamento Dati
disp('--- Elaborazione Target ---');

% Caricamento Dati Target
data_T = load(filename_target);
adc_data_target = data_T.adc_dataTot;
n_frames_target = size(adc_data_target, 4);

disp('--- Elaborazione Background ---');

% caricamento Dati Background
data_BG = load(filename_background);
adc_data_bg = data_BG.adc_dataTot;
n_frames_bg = size(adc_data_bg, 4);

%% FILE BACKGROUND: Caricamento Dati e Mappa Range-Azimuth

% ciclo for su tutti i frame
for k = 1 : n_frames_bg
    raw_cube_bg = adc_data_bg(:, :, :, k);
    
    % Range FFT
    step1_bg = fft(raw_cube_bg, Fast_Time, 1);
    
    % Angle FFT
    step2_bg = fft(step1_bg, Antenna, 3);
    
    % Shift
    cube_shifted_bg = fftshift(fftshift(step2_bg, 1), 3);
    
    % Somma lungo la dimensione 2
    map_RA_bg = squeeze(sum(abs(cube_shifted_bg), 2));
    
    % aggiorno l'accumulatore con solo valori degli assi positivi
    SumFrame_RA_BG = SumFrame_RA_BG + map_RA_bg(idx_start:idx_end, :);
end

% Normalizzazione (Media), dividere per n_frames_bg rende le due mappe confrontabili
Map_RA_BG_Final = SumFrame_RA_BG / n_frames_bg;

% plot Background
figure;
Map_RA_BG_Final_dB = 20*log10(Map_RA_BG_Final);
Map_RA_BG_Final_dB = Map_RA_BG_Final_dB - max(Map_RA_BG_Final_dB(:)); 
imagesc(azimuth, R_positive, Map_RA_BG_Final_dB);
axis xy; colorbar;
xlabel('Angolo (°)'); ylabel('Range (m)');
title(['Mappa Range-Azimuth Background (' num2str(n_frames_bg) ' frames)']);
caxis([-35 0]);

%% FILE TARGET: Mappa RANGE-DOPPLER
% preparazione della figura Live
figure;
TAx = axes;
TImg = imagesc(v_target, R_positive,zeros(length(idx_start:idx_end), Slow_Time));
axis xy; colorbar;
caxis([-35 0]); 
xlabel('Velocità (m/s)'); ylabel('Range (m)');

% Definisco i frame chiave che voglio catturare
key_frames = [10, 30, 60, 90]; 

% Ciclo for su tutti i frame
for k = 1 : n_frames_target
    raw_cube = adc_data_target(:, :, :, k);
   
    % comprimiamo cubo lungo la dimensione delle antenne, per avere una visione
    % complessiva del target da tutte le antenne. (cubo 4D -> 3D)
    raw_data_all_ant = sum(raw_cube,3); % somme lungo l'asse delle antenne (dimensione 3)

    % FFT2D sulle dimensioni Fast_Time (campioni temporali -> Range) -> Slow_Time (variazione chirp -> Velocità)
    map_RD = abs(fftshift(fft2(raw_data_all_ant)));

    % rimuovo Zero Doppler (Clutter di tutti gli oggetti fermi)
    center = floor(Slow_Time/2) + 1; % colonna 32, 33 e 34
    map_RD(:, center-1 : center+1) = 0; 

    map_RD_positive = map_RD(idx_start:idx_end,:);
    map_RD_dB = 20*log10(map_RD_positive + 1e-9);
    map_RD_dB = map_RD_dB - max(map_RD_dB(:));

    % Aggiorna grafico
    set(TImg, 'CData', map_RD_dB);
    title(TAx, ['Live Range-Doppler: Istante t = ' num2str(k*0.150, '%.2f') ' s Frame ' num2str(k) '/' num2str(n_frames_target)]);
    
    % --- SALVATAGGIO AUTOMATICO ---
%     if ismember(k, key_frames)
%         filename = ['mapRDX_Frame_' num2str(k) '.png'];
%         % exportgraphics è meglio di saveas perché ritaglia i bordi bianchi
%         exportgraphics(gcf, filename, 'Resolution', 300);
%         disp(['Salvato: ' filename]);
%     end
   
    pause(0.05);
    
    % aggiorno l'accumulatore con solo valori degli assi positivi
    SumFrame_RD_Target = SumFrame_RD_Target + map_RD(idx_start:idx_end, :);
end
% normalizzazione (calcola la potenza media per frame)
Map_RD_Final = SumFrame_RD_Target / n_frames_target; % serve per il confronto con il background

% plot Target
figure;
Map_RD_dB = 20*log10(Map_RD_Final + 1e-9); % 1e-9 serve se l'argomento del logaritmo è 0
Map_RD_dB = Map_RD_dB - max(Map_RD_dB(:)); % Normalizza a 0 dB
imagesc(v_target, R_positive, Map_RD_dB);
axis xy; colorbar;
xlabel('Velocità (m/s)'); ylabel('Range (m)');
title(['Mappa Range-Doppler (' num2str(n_frames_target) ' frames)']);
caxis([-35 0]);

%% TARGET: Mappa Range-Azimuth
figure;
Ax = axes;
Img = imagesc(azimuth, R_positive,zeros(length(idx_start:idx_end), Antenna));
axis xy; colorbar;
caxis([-35 0]); 
xlabel('Angolo (°)'); ylabel('Range (m)');

% Definisco i frame chiave che voglio catturare
key_frames = [10, 30, 60, 90]; 

% ciclo for su tutti i frame
for k = 1 : n_frames_target
    raw_cube = adc_data_target(:, :, :, k);

    % Range FFT (Fast_Time (Dim 1))
    step1 = fft(raw_cube, Fast_Time, 1);
    
    % Angle FFT (Antenne (Dim 3))
    step2 = fft(step1, Antenna, 3);
    
    % Shift (Range e Angolo)
    cube_shifted = fftshift(fftshift(step2, 1), 3);
    
    % Somma Energia (Modulo) di ogni chirp lungo dim 2. Se sommo prima dell'FFT,
    % i target in movimento vengono cancellati (hanno fase diversa). Dopo FFT prendo l'abs (valore positivo) e 
    % la somma darà contributo positivo.
    % squeeze: passo da cube 3D -> 2D rimuovendo la dimensione 2 ottenendo una matrice [Range x Angolo]
    map_RA = squeeze(sum(abs(cube_shifted), 2));
 
    map_RA_positive = map_RA(idx_start:idx_end, :);
    map_RA_dB = 20*log10(map_RA_positive + 1e-9);
    map_RA_dB = map_RA_dB - max(map_RA_dB(:));

    % Aggiorna grafico
    set(Img, 'CData', map_RA_dB);
    title(Ax, ['Live Range-Azimuth: Istante t = ' num2str(k*0.150, '%.2f') ' s Frame ' num2str(k) '/' num2str(n_frames_target)]);
    
%     % --- SALVATAGGIO AUTOMATICO ---
%     if ismember(k, key_frames)
%         filename = ['mapRAX_Frame_' num2str(k) '.png'];
%         % exportgraphics è meglio di saveas perché ritaglia i bordi bianchi
%         exportgraphics(gcf, filename, 'Resolution', 300);
%         disp(['Salvato: ' filename]);
%     end
    pause(0.05);
    
    % aggiorno l'accumulatore con solo valori degli assi positivi
    SumFrame_RA_Target = SumFrame_RA_Target + map_RA(idx_start:idx_end, :);
end

% normalizzazione (calcola la potenza media per frame)
Map_RA_Target_Final = SumFrame_RA_Target / n_frames_target;

% plot Range-Azimuth Target
figure;
Map_RA_Target_Final_dB = 20*log10(Map_RA_Target_Final);
Map_RA_Target_Final_dB = Map_RA_Target_Final_dB - max(Map_RA_Target_Final_dB(:)); % Normalizza a 0 dB
imagesc(azimuth, R_positive, Map_RA_Target_Final_dB);
axis xy; colorbar;
xlabel('Angolo (°)'); ylabel('Range (m)');
title(['Mappa Range-Azimuth File con Target (' num2str(n_frames_target) ' frames)']);
caxis([-35 0]); 

%% SOTTRAZIONE TARGET/BACKGROUND FIGURA LIVE E RISULTATO FINALE
disp('--- Calcolo Differenza ---');

figure;
Ax = axes;
Img = imagesc(azimuth, R_positive,zeros(length(idx_start:idx_end), Antenna));
axis xy; colorbar;
caxis([-35 0]); 
xlabel('Angolo (°)'); ylabel('Range (m)');

% Definisco i frame chiave che voglio catturare
key_frames = [10, 30, 60, 90]; 

% ciclo for su tutti i frame
for k = 1 : n_frames_target
    raw_cube = adc_data_target(:, :, :, k);
    raw_cube_bg = adc_data_bg(:, :, :, k);
    % Range FFT (Fast_Time (Dim 1))
    step1 = fft(raw_cube, Fast_Time, 1);
    step1bg = fft(raw_cube_bg, Fast_Time, 1);
    % Angle FFT (Antenne (Dim 3))
    step2 = fft(step1, Antenna, 3);
    step2bg = fft(step1bg, Antenna, 3);
    % Shift (Range e Angolo)
    cube_shifted = fftshift(fftshift(step2, 1), 3);
    cube_shiftedbg = fftshift(fftshift(step2bg, 1), 3);
    
    % Somma Energia (Modulo) di ogni chirp lungo dim 2. Se sommo prima dell'FFT,
    % i target in movimento vengono cancellati (hanno fase diversa). Dopo FFT prendo l'abs (valore positivo) e 
    % la somma darà contributo positivo.
    % squeeze: passo da cube 3D -> 2D rimuovendo la digumensione 2 ottenendo una matrice [Range x Angolo]
    map_RA = squeeze(sum(abs(cube_shifted), 2));
    map_RAbg = squeeze(sum(abs(cube_shiftedbg), 2));

    map_RA_positive = map_RA(idx_start:idx_end, :);
    map_RA_positivebg = map_RAbg(idx_start:idx_end, :);

    % Sottraggo Mappa_Target - Mappa_Background
    MAP_final = map_RA_positive - map_RA_positivebg;
    MAP_final (MAP_final < 0) = 0;

    MAP_final_dB = 20*log10(MAP_final + 1e-9);
    MAP_final_dB = MAP_final_dB - max(MAP_final_dB(:));

    % Aggiorna grafico
    set(Img, 'CData', MAP_final_dB);
    title(Ax, ['Live Range-Azimuth - Background Subtraction: Istante t = ' num2str(k*0.150, '%.2f') ' s Frame ' num2str(k) '/' num2str(n_frames_target)]);
    
    % --- SALVATAGGIO AUTOMATICO ---
%     if ismember(k, key_frames)
%         filename = ['mapRAX_sub_Frame_' num2str(k) '.png'];
%         % exportgraphics è meglio di saveas perché ritaglia i bordi bianchi
%         exportgraphics(gcf, filename, 'Resolution', 300);
%         disp(['Salvato: ' filename]);
%     end
    pause(0.05);
    
end
% Mappa Statica
% trovo il massimo tra le due mappe
maxt = max(Map_RA_Target_Final(:));
maxbg = max(Map_RA_BG_Final(:));

max_val_global = max(max(Map_RA_Target_Final(:)), max(Map_RA_BG_Final(:)));

% normalizzo entrambi con lo stesso numero, in questo modo i valori hanno la stessa scala.
% se avessi nomalizzato con il massimo locale, nel caso background il muro (val max) = 1. 
% Nel caso target se è il target con potenza max = 1, ho che la potenza del muro < 1, 
% quindi quando faccio la sottrazione muro_target - muro_bg < 1 -> 0 , ma
% ho anche ridotto l'intensità di tutti gli altri oggetti nella mappa target (uso scale diverse).
% bisogna normalizzare ad uno stesso fattore di scala -> massimo tra entrambe le mappe
Map_RA_Target_Final = Map_RA_Target_Final / max_val_global;
Map_RA_BG_Final     = Map_RA_BG_Final     / max_val_global;

% sottrazione: (Media Target) - (Media Background) in Lineare
Map_RA_Cleaned = Map_RA_Target_Final - Map_RA_BG_Final;
% rimuovo i valori negativi (rumore)
Map_RA_Cleaned(Map_RA_Cleaned < 0) = 0;

% conversione in dB
Map_RA_Clean_dB = 20*log10(Map_RA_Cleaned + 1e-9); 
Map_RA_Clean_dB = Map_RA_Clean_dB - max(Map_RA_Clean_dB(:));
% plot Finale
figure;
imagesc(azimuth, R_positive, Map_RA_Clean_dB);
axis xy; colorbar;
xlabel('Angolo (°)'); ylabel('Range (m)');
title('Mappa Range-Azimuth Background Sottratto');
caxis([-35 0]);

%% MTI (Moving Target Indicator): Mappa Range-Azimuth
figure;
Ax = axes;
Img_mti = imagesc(azimuth, R_positive,zeros(length(idx_start:idx_end), Antenna));
axis xy; colorbar;
caxis([-35 0]); 
xlabel('Angolo (°)'); ylabel('Range (m)');

% Definisco i frame chiave che voglio catturare
key_frames = [10, 30, 60, 90]; 

% ciclo for su tutti i frame
for k = 1 : n_frames_target

    raw_cube_mti = adc_data_target(:, :, :, k);

    % Range FFT (Fast_Time (Dim 1))
    step1_mti = fftshift(fft(raw_cube_mti, Fast_Time, 1));
    
    % Velocity FFT (Slow_Time (Dim 2)) separa movimento dinamico da quello statico
    step2_mti = fftshift(fft(step1_mti, Slow_Time, 2));
    % Zero Doppler
    center = floor(Slow_Time/2) + 1; % colonna 33
    step2_mti(:, center-1:center+1, :) = 0;  % elimina 3 colonne attorno allo zero
    % Angle FFT (Antenne (Dim 3))
    step3_mti = fftshift(fft(step2_mti, Antenna, 3));
    
    map_RA_mti = squeeze(sum(abs(step3_mti), 2));
 
    map_RA_positive_mti = map_RA_mti(idx_start:idx_end, :);
    map_RA_mti_dB = 20*log10(map_RA_positive_mti + 1e-9);
    map_RA_mti_dB = map_RA_mti_dB - max(map_RA_mti_dB(:));

    % Aggiorna grafico
    set(Img_mti, 'CData', map_RA_mti_dB);
    title(Ax, ['Live Range-Azimuth - Filtro MTI: Istante t = ' num2str(k*0.150, '%.2f') ' s Frame ' num2str(k) '/' num2str(n_frames_target)]);
    
    % --- SALVATAGGIO AUTOMATICO ---
%     if ismember(k, key_frames)
%         filename = ['mapRAX_mti_Frame_' num2str(k) '.png'];
%         % exportgraphics è meglio di saveas perché ritaglia i bordi bianchi
%         exportgraphics(gcf, filename, 'Resolution', 300);
%         disp(['Salvato: ' filename]);
%     end
    pause(0.05);

    % aggiorno l'accumulatore con solo valori degli assi positivi
    SumFrame_RA_mti_Target = SumFrame_RA_mti_Target + map_RA_mti(idx_start:idx_end, :);
end

% normalizzazione (calcola la potenza media per frame)
Map_RA_mti_Target_Final = SumFrame_RA_mti_Target / n_frames_target;

% plot Range-Azimuth Target
figure;
Map_RA_mti_Target_Final_dB = 20*log10(Map_RA_mti_Target_Final);
Map_RA_mti_Target_Final_dB = Map_RA_mti_Target_Final_dB - max(Map_RA_mti_Target_Final_dB(:)); % Normalizza a 0 dB
imagesc(azimuth, R_positive, Map_RA_mti_Target_Final_dB);
axis xy; colorbar;
xlabel('Angolo (°)'); ylabel('Range (m)');
title(['Mappa Range-Azimuth MTI (' num2str(n_frames_target) ' frames)']);
caxis([-35 0]); 

%% FRAME DIFFERENCE: Mappa Range-Azimuth

figure;
Ax = axes;
Img = imagesc(azimuth, R_positive,zeros(length(idx_start:idx_end), Antenna));
axis xy; colorbar;
caxis([-35 0]); 
xlabel('Angolo (°)'); ylabel('Range (m)');

% Definisco i frame chiave che voglio catturare
key_frames = [10, 30, 60, 90]; 

% Pre-calcolo il primo frame per avere un "precedente"
k = 1;
raw_cube = adc_data_target(:, :, :, k);
step1_fd = fft(raw_cube, Fast_Time, 1);
step2_fd = fft(step1_fd, Antenna, 3);
cube_shifted_fd = fftshift(fftshift(step2_fd, 1), 3);
% mappa magnitudo precedente
Map_Prev = squeeze(sum(abs(cube_shifted_fd), 2)); 
Map_Prev = Map_Prev(idx_start:idx_end, :);

% accumulatore con la somma di tutti i cambiamenti
Accumulated_Diff = zeros(size(Map_Prev));

disp('Avvio Frame Differencing...');
% ciclo for dal secondo frame in poi
for k = 2:n_frames_target
    
    % calcolo Frame Corrente
    raw_cube = adc_data_target(:, :, :, k);
    step1_fd = fft(raw_cube, Fast_Time, 1);
    step2_fd = fft(step1_fd, Antenna, 3);
    cube_shifted_fd = fftshift(fftshift(step2_fd, 1), 3);
    Map_Curr = squeeze(sum(abs(cube_shifted_fd), 2));
    Map_Curr = Map_Curr(idx_start:idx_end, :);
    
    % differenza frame corrente con frame precedente
    Diff_instant = Map_Curr - Map_Prev;
    Diff_instant(Diff_instant < 0) = 0;

    %map_RA_positive_mti = map_RA_mti(idx_start:idx_end, :);
    Diff_instant_dB = 20*log10(Diff_instant + 1e-9);
    Diff_instant_dB = Diff_instant_dB - max(Diff_instant_dB(:)); 


    % Aggiorna grafico
    set(Img, 'CData', Diff_instant_dB);
    title(Ax, ['Live Range-Azimuth - Frame Differencing: Istante t = ' num2str(k*0.150, '%.2f') ' s Frame ' num2str(k) '/' num2str(n_frames_target)]);
    
    % --- SALVATAGGIO AUTOMATICO ---
%     if ismember(k, key_frames)
%         filename = ['mapRAX_fd_Frame_' num2str(k) '.png'];
%         % exportgraphics è meglio di saveas perché ritaglia i bordi bianchi
%         exportgraphics(gcf, filename, 'Resolution', 300);
%         disp(['Salvato: ' filename]);
%     end
    pause(0.05);
    

    % aggiorno il valore della differenza all'accumulatore totale
    Accumulated_Diff = Accumulated_Diff + Diff_instant;

    % aggiorno mappa precedente
    Map_Prev = Map_Curr;
end
% normalizzo (media)
Diff = Accumulated_Diff / (n_frames_target-1);
% in dB e normalizzazione
Diff_dB = 20 * log10(Diff + 1e-9);
Diff_dB = Diff_dB - max(Diff_dB(:));
% plot
figure;
imagesc(azimuth, R_positive, Diff_dB);
axis xy; colorbar;
xlabel('Angolo (°)'); ylabel('Range (m)');
title(['Mappa Range-Azimuth Frame Difference (' num2str(n_frames_target) ' frames)']);
caxis([-35 0])

%% Mappa Range-Tempo
RangeTimeMap = zeros(length(R_positive), n_frames_target);

for k = 1:n_frames_target

    raw_data = adc_data_target(:,:,:,k);
    % Range FFT
    fft_range = fftshift(fft(raw_data, Fast_Time, 1));
    
    % somma energia su Antenne e Chirps (Doppler) per avere solo Range
    % ottengo un vettore colonna di potenza per ogni frame
    range_profile = sum(sum(abs(fft_range), 2), 3);
    
    % salvo nella colonna k-esima
    RangeTimeMap(:, k) = range_profile(idx_start:idx_end);
end

% in dB
RangeTimeMap_dB = 20*log10(RangeTimeMap);
RangeTimeMap_dB = RangeTimeMap_dB - max(RangeTimeMap_dB(:));
% plot
figure;
time_axis = (1:n_frames_target) * 150e-3; % converto in secondi (1 frame dura 150 ms)
imagesc(time_axis, R_positive, RangeTimeMap_dB);
axis xy; colorbar;
xlabel('Tempo (s)');
ylabel('Range (m)');
title('Mappa Range-Tempo');

%% SPETTROGRAMMA (Mappa Velocità-Tempo)
disp('--- Generazione Spettrogramma ---');

% Definiamo asse velocità
velocity_axis = linspace(-max(abs(v_target)), max(abs(v_target)), Slow_Time);
time_axis_spec = (1:n_frames_target) * 150e-3;

% Matrice finale [Velocità x Tempo]
Spectrogram_Map = zeros(Slow_Time, n_frames_target);

for k = 1 : n_frames_target
    raw_cube = adc_data_target(:, :, :, k);
    
    % Range FFT (su tutto il cubo)
    step1 = fftshift(fft(raw_cube, Fast_Time, 1),1);
    
    % Doppler FFT (su tutto il cubo)
    step2 = fftshift(fft(step1, Slow_Time, 2), 2);
    
    % Calcolo Magnitudo (Energia)
    energy_cube = abs(step2);
    
    % Selezione Range e Somma Totale
    % Sommiamo l'energia di tutte le antenne (dim 3) e di tutti i range utili (dim 1)
    % Ci interessa "quanta energia c'è a velocità X", non importa dove o da che antenna
    doppler_profile = squeeze(sum(sum(energy_cube(idx_start:idx_end, :, :), 1), 3));
    
    % Salviamo nella colonna k
    Spectrogram_Map(:, k) = doppler_profile;
end

% Rimozione DC (Colonna)
idx_center = floor(Slow_Time/2) + 1;
Spectrogram_Map(idx_center-1:idx_center+1, :) = 0;

% Conversione in dB
Spectrogram_dB = 20*log10(Spectrogram_Map + 1e-9);
Spectrogram_dB = Spectrogram_dB - max(Spectrogram_dB(:)); 

% Plot
figure;
imagesc(time_axis_spec, velocity_axis, Spectrogram_dB);
axis xy; colorbar;
caxis([-35 0]); 
xlabel('Tempo (s)');
ylabel('Velocità (m/s)');
title('Spettrogramma Velocità-Tempo (Micro-Doppler)');