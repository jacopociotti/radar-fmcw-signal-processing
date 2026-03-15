# 📡 Elaborazione di Segnali Radar FMCW e Analisi di Target in Ambiente Indoor

Questo repository contiene il codice e l'analisi per l'elaborazione completa della catena di segnali di un radar FMCW (Frequency Modulated Continuous Wave), partendo dai dati grezzi (Raw Data) fino alla visualizzazione delle traiettorie dei target. L'obiettivo principale è il tracciamento di target umani in ambienti indoor, affrontando la complessa problematica del forte clutter statico.

## 📡 Panoramica del Progetto

Il progetto si concentra sulla decodifica e l'interpretazione del Data Cube Radar (una struttura multidimensionale basata su Fast-Time, Slow-Time e Antenne) per estrarre precise informazioni fisiche su soggetti in movimento. Nello specifico, il caso di studio analizza un'acquisizione dinamica in cui due persone si muovono incrociando le proprie traiettorie (creando una forma a "X") all'interno di una stanza.

Sfruttando algoritmi basati sulla Fast Fourier Transform (FFT), il sistema genera diverse tipologie di mappe radar:
* **Range-Doppler**: per visualizzare contemporaneamente distanza e velocità radiale.
* **Range-Azimuth**: per la localizzazione spaziale sul piano orizzontale (distanza e angolo).
* **Range-Tempo**: per monitorare il flusso e l'evoluzione della distanza dei target nel corso dell'intera acquisizione.
* **Doppler-Tempo (Spettrogramma)**: per l'analisi micro-Doppler e le variazioni cinematiche istantanee.

## 🛠️ Tecniche di Rimozione del Clutter (Clutter Removal)

In ambienti indoor, gli ostacoli statici (come le colonne e le pareti) possiedono una Radar Cross Section molto alta, che genera riflessioni in grado di saturare la dinamica dell'immagine e nascondere i target umani. Per estrarre le informazioni utili, sono state implementate e confrontate tre strategie di filtraggio:

1. **Sottrazione del Background (Background Subtraction)**: Sottrae alla mappa corrente l'energia di un'acquisizione di riferimento a stanza vuota. È la tecnica che offre la qualità d'immagine superiore e la massima precisione spaziale, eliminando quasi totalmente gli ostacoli.
2. **Filtro MTI (Moving Target Indicator)**: Opera nel dominio della frequenza Doppler, discriminando i bersagli sopprimendo l'energia statica (azzerando le componenti a velocità zero). Ottima soluzione per un funzionamento autonomo in scenari mutevoli.
3. **Frame Differencing (MHI)**: Calcola la differenza algebrica tra le mappe di frame successivi, costruendo una mappa globale della "storia" del movimento. 

## 🔬 Set-up Sperimentale e Hardware

* **Sensore**: Radar FMCW con architettura MIMO (Multiple Input Multiple Output), posizionato a circa 1.5 metri di altezza.
* **Dimensioni Data Cube**: 128 (Campioni Fast-Time) x 64 (Chirp Slow-Time) x 86 (Antenne Virtuali).
* **Parametri Waveform (Chirp)**:
  * Frequenza di Campionamento ADC: 10000 ksample/s.
  * Larghezza di Banda (B): 2.96 GHz.
  * Range Massimo Rilevabile: ~9.5 m.
* **Scenario**: Ambiente indoor (Faculty Club DII Univpm) caratterizzato da pareti, finestre, sedie e una colonna fortemente riflettente a 9 metri di distanza. 

## 💻 Tecnologie Utilizzate

* **MATLAB**: L'intero sviluppo degli algoritmi di Signal Processing, l'implementazione dei filtri di Clutter Removal e la generazione e salvataggio delle figure radar 2D e temporali sono stati realizzati tramite script MATLAB.
