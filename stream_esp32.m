function h = stream_esp32(s, nVentana, fs, fcFIR, fcIIR)
%STREAM_ESP32 Visualiza el streaming CSV del ESP32 en tiempo real.
%
% El firmware envia:
%   - Una cabecera de texto (primera linea): "crudo,filtrado"
%   - Luego una linea por muestra a fs=10 Hz:
%       <crudo>,<filtrado>\r\n
%     Ejemplo: 0.81234,0.00123
%
% Protocolo: 115200 baud, 8N1, terminador CR/LF.
% No se envia ningun dato al ESP32; esta funcion es solo receptora.
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

FFT_VENTANA = 128;

rawBuffer  = nan(1, nVentana);
filtBuffer = nan(1, nVentana);
idx        = 0;
numValidas = 0;
cabeceraSaltada = false;   % flag: se descarta la primera linea de texto

rawFFTBuffer     = zeros(1, FFT_VENTANA);
filtFFTBuffer    = zeros(1, FFT_VENTANA);
fftIdx           = 0;
fftMuestrasNuevas = 0;
ventanaFFT       = hann(FFT_VENTANA).';
freqFFT          = (0:(FFT_VENTANA / 2 - 1)) * (fs / FFT_VENTANA);
fftCrudaDb       = nan(1, FFT_VENTANA / 2);
fftFiltradaDb    = nan(1, FFT_VENTANA / 2);

% ---- Figura ----
fig = figure('Name', 'Streaming ESP32 - cruda y filtrada (CSV)', ...
    'NumberTitle', 'off', ...
    'CloseRequestFcn', @detenerStreaming);

ax1 = subplot(2, 1, 1, 'Parent', fig);
x = 1:nVentana;
lineRaw  = plot(ax1, x, rawBuffer,  'Color', [0.20 0.20 0.20], 'LineWidth', 1.1);
hold(ax1, 'on');
lineFilt = plot(ax1, x, filtBuffer, 'Color', [0 0.35 0.80],    'LineWidth', 1.2);
hold(ax1, 'off');
grid(ax1, 'on');
title(ax1, 'Senales en tiempo real — cruda vs. filtrada');
xlabel(ax1, 'Muestra');
ylabel(ax1, 'Amplitud (V)');
legend(ax1, {'Cruda ADC', 'Filtrada'}, 'Location', 'best');

ax2 = subplot(2, 1, 2, 'Parent', fig);
lineFFTcruda    = plot(ax2, freqFFT, fftCrudaDb,    'Color', [0.20 0.20 0.20], 'LineWidth', 1.1);
hold(ax2, 'on');
lineFFTfiltrada = plot(ax2, freqFFT, fftFiltradaDb, 'Color', [0 0.35 0.80],    'LineWidth', 1.2);
marcarCorte(ax2, fcFIR, sprintf('FIR LP %.3g Hz', fcFIR), [0 0.35 0.80]);
marcarCorte(ax2, fcIIR, sprintf('IIR HP %.3g Hz', fcIIR), [0.82 0.12 0.12]);
hold(ax2, 'off');
grid(ax2, 'on');
title(ax2, sprintf('FFT en vivo — ventana %d muestras (Hann)', FFT_VENTANA));
xlabel(ax2, 'Frecuencia (Hz)');
ylabel(ax2, 'Magnitud (dB)');
xlim(ax2, [0 fs / 2]);
legend(ax2, {'Cruda', 'Filtrada'}, 'Location', 'best');

uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Detener streaming', ...
    'Units', 'normalized', ...
    'Position', [0.40 0.01 0.20 0.05], ...
    'Callback', @detenerStreaming);

% ---- Configurar puerto serial para texto CR/LF ----
configureTerminator(s, 'CR/LF');
flush(s);

% Callback: se dispara en cada linea completa (\r\n recibido)
configureCallback(s, 'terminator', @leerLinea);

h = struct();
h.figure = fig;
h.serial = s;
h.stop   = @() detenerStreaming([], []);

% ---- Funciones anidadas ----

    function leerLinea(src, ~)
        try
            linea = readline(src);
        catch
            return;
        end

        linea = strtrim(char(linea));

        % Descartar cabecera "crudo,filtrado" y lineas vacias o no numericas
        if isempty(linea)
            return;
        end
        if ~cabeceraSaltada || contains(linea, 'crudo', 'IgnoreCase', true)
            cabeceraSaltada = true;
            return;
        end

        % Parseo CSV: "<crudo>,<filtrado>"
        vals = sscanf(linea, '%f,%f');
        if numel(vals) < 2
            return;   % linea malformada — ignorar
        end

        muestraCruda    = vals(1);
        muestraFiltrada = vals(2);

        if ~isfinite(muestraCruda) || ~isfinite(muestraFiltrada)
            return;
        end

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

        ordenFFT         = [fftIdx + 1:FFT_VENTANA  1:fftIdx];
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
            orden = [idx + 1:nVentana  1:idx];
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
x      = x(:).' .* ventana;
X      = fft(x);
mag    = abs(X(1:n / 2)) / n;
magDb  = 20 * log10(mag + eps);
end

function marcarCorte(ax, fc, etiqueta, color)
if fc <= 0
    return;
end
xline(ax, fc, ':', etiqueta, 'Color', color, 'LineWidth', 1.0);
end
