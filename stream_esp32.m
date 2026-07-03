function h = stream_esp32(s, nVentana, fs, fcFIR, fcIIR)
%STREAM_ESP32 Visualiza el streaming BINARIO del ESP32 en tiempo real.
%
% El firmware envia 8 bytes por muestra a fs=10 Hz:
%   Bytes 0-3 : float32 (single) cruda [V]
%   Bytes 4-7 : float32 (single) filtrada [V]
%
% Protocolo: 115200 baud, 8N1. Sin cabecera de texto.
% MATLAB lee con configureCallback 'byte' cada 8 bytes recibidos.
%
% Uso desde consola:
%   s = serialport("COM4", 115200);
%   h = stream_esp32(s);
%
% Uso desde la GUI (main_app):
%   h = stream_esp32(app.serial, 200, app.fs.Value, fcFIR, fcIIR);

arguments
    s
    nVentana (1, 1) double {mustBeInteger, mustBePositive} = 200
    fs       (1, 1) double {mustBePositive}                = 10
    fcFIR    (1, 1) double {mustBeNonnegative}             = 0.5
    fcIIR    (1, 1) double {mustBeNonnegative}             = 0.01
end

BYTES_POR_MUESTRA = 8;   % 2 x float32 (cruda y filtrada)
FFT_VENTANA       = 128;

rawBuffer  = nan(1, nVentana);
filtBuffer = nan(1, nVentana);
idx        = 0;
numValidas = 0;

rawFFTBuffer      = zeros(1, FFT_VENTANA);
filtFFTBuffer     = zeros(1, FFT_VENTANA);
fftIdx            = 0;
fftMuestrasNuevas = 0;
ventanaFFT        = hann(FFT_VENTANA).';
freqFFT           = (0:(FFT_VENTANA/2-1)) * (fs/FFT_VENTANA);
fftCrudaDb        = nan(1, FFT_VENTANA/2);
fftFiltradaDb     = nan(1, FFT_VENTANA/2);

erroresDecode = 0;
MAX_ERRORES   = 20;

% ---- Figura ----
fig = figure('Name', 'Streaming ESP32 - cruda y filtrada (float32 binario)', ...
    'NumberTitle', 'off', ...
    'CloseRequestFcn', @detenerStreaming);

ax1 = subplot(2, 2, 1, 'Parent', fig);
t = (0:nVentana-1) / fs;
lineRaw  = plot(ax1, t, rawBuffer,  'Color', [0.20 0.20 0.20], 'LineWidth', 1.1);
grid(ax1, 'on');
title(ax1, 'Señal Cruda - Tiempo');
xlabel(ax1, 'Tiempo (s)');
ylabel(ax1, 'Amplitud (V)');

ax2 = subplot(2, 2, 2, 'Parent', fig);
lineFilt = plot(ax2, t, filtBuffer, 'Color', [0 0.35 0.80], 'LineWidth', 1.2);
grid(ax2, 'on');
title(ax2, 'Señal Filtrada - Tiempo');
xlabel(ax2, 'Tiempo (s)');
ylabel(ax2, 'Amplitud (V)');

ax3 = subplot(2, 2, 3, 'Parent', fig);
lineFFTcruda = plot(ax3, freqFFT, fftCrudaDb, 'Color', [0.20 0.20 0.20], 'LineWidth', 1.1);
grid(ax3, 'on');
title(ax3, 'Espectro (FFT) Cruda');
xlabel(ax3, 'Frecuencia (Hz)');
ylabel(ax3, 'Magnitud (dB)');
xlim(ax3, [0 fs/2]);

ax4 = subplot(2, 2, 4, 'Parent', fig);
lineFFTfiltrada = plot(ax4, freqFFT, fftFiltradaDb, 'Color', [0 0.35 0.80], 'LineWidth', 1.2);
hold(ax4, 'on');
marcarCorte(ax4, fcFIR, sprintf('FIR LP %.3g Hz', fcFIR), [0 0.35 0.80]);
marcarCorte(ax4, fcIIR, sprintf('IIR HP %.3g Hz', fcIIR), [0.82 0.12 0.12]);
hold(ax4, 'off');
grid(ax4, 'on');
title(ax4, 'Espectro (FFT) Filtrada');
xlabel(ax4, 'Frecuencia (Hz)');
ylabel(ax4, 'Magnitud (dB)');
xlim(ax4, [0 fs/2]);

uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Detener streaming', ...
    'Units', 'normalized', ...
    'Position', [0.40 0.01 0.20 0.05], ...
    'Callback', @detenerStreaming);

% ---- Configurar puerto serial para modo BINARIO ----
configureTerminator(s, 'LF');
flush(s);

% El callback se dispara exactamente cada 8 bytes (1 muestra = 2 single)
configureCallback(s, 'byte', BYTES_POR_MUESTRA, @leerPaquete);

h = struct();
h.figure = fig;
h.serial = s;
h.stop   = @() detenerStreaming([], []);

% ---- Funciones anidadas ----

    function leerPaquete(src, ~)
        % Lee 8 bytes correspondientes a 2 singles
        try
            bytes = read(src, BYTES_POR_MUESTRA, 'uint8');
        catch
            return;
        end
        if numel(bytes) < BYTES_POR_MUESTRA
            return;
        end

        % Decodificar floats (little-endian)
        vals = typecast(uint8(bytes(:).'), 'single');
        muestraCruda    = double(vals(1));
        muestraFiltrada = double(vals(2));

        % Validar
        if ~isfinite(muestraCruda) || ~isfinite(muestraFiltrada)
            erroresDecode = erroresDecode + 1;
            if erroresDecode >= MAX_ERRORES && isvalid(fig)
                fig.Name = sprintf('ADVERTENCIA: %d paquetes invalidos - verifique sinc.', ...
                    erroresDecode);
            end
            % Descartar 1 byte para intentar resincronizar
            try, read(src, 1, 'uint8'); catch, end
            return;
        end

        erroresDecode = 0;
        agregarMuestra(muestraCruda, muestraFiltrada);
    end

    function agregarMuestra(muestraCruda, muestraFiltrada)
        idx        = mod(idx, nVentana) + 1;
        numValidas = min(numValidas + 1, nVentana);

        rawBuffer(idx)  = muestraCruda;
        filtBuffer(idx) = muestraFiltrada;
        agregarMuestraFFT(muestraCruda, muestraFiltrada);

        orden = indicesOrdenados();
        set(lineRaw,  'YData', rawBuffer(orden));
        set(lineFilt, 'YData', filtBuffer(orden));
        drawnow limitrate;
    end

    function agregarMuestraFFT(muestraCruda, muestraFiltrada)
        fftIdx            = mod(fftIdx, FFT_VENTANA) + 1;
        rawFFTBuffer(fftIdx)  = muestraCruda;
        filtFFTBuffer(fftIdx) = muestraFiltrada;
        fftMuestrasNuevas = fftMuestrasNuevas + 1;

        if fftMuestrasNuevas < FFT_VENTANA
            return;
        end
        fftMuestrasNuevas = 0;

        ordenFFT         = [fftIdx+1:FFT_VENTANA  1:fftIdx];
        crudaOrdenada    = rawFFTBuffer(ordenFFT);
        filtradaOrdenada = filtFFTBuffer(ordenFFT);

        fftCrudaDb    = calcularFFTdb(crudaOrdenada,    ventanaFFT, FFT_VENTANA);
        fftFiltradaDb = calcularFFTdb(filtradaOrdenada, ventanaFFT, FFT_VENTANA);
        set(lineFFTcruda,    'YData', fftCrudaDb);
        set(lineFFTfiltrada, 'YData', fftFiltradaDb);
    end

    function orden = indicesOrdenados()
        if numValidas < nVentana
            orden = 1:nVentana;
        else
            orden = [idx+1:nVentana  1:idx];
        end
    end

    function detenerStreaming(~, ~)
        try
            configureCallback(s, 'off');
        catch
        end
        if isvalid(fig)
            delete(fig);
        end
    end
end

% ---- Funciones locales ----

function magDb = calcularFFTdb(x, ventana, n)
x     = x(:).' .* ventana;
X     = fft(x);
mag   = abs(X(1:n/2)) / n;
magDb = 20 * log10(mag + eps);
end

function marcarCorte(ax, fc, etiqueta, color)
if fc <= 0
    return;
end
xline(ax, fc, ':', etiqueta, 'Color', color, 'LineWidth', 1.0);
end
