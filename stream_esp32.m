function h = stream_esp32(s, nVentana, fs, fcFIR, fcIIR)
%STREAM_ESP32 Visualiza el streaming real del main.cpp pegado.
%
% Ese firmware envia continuamente:
%   [float32 cruda LE][float32 filtrada LE]
% Total: 8 bytes por muestra. No hay cabecera 0xBB ni CRC en el codigo
% pegado. Esta funcion asume que enviar_cadena_esp32 ya consumio el ACK.

arguments
    s
    nVentana (1, 1) double {mustBeInteger, mustBePositive} = 200
    fs (1, 1) double {mustBePositive} = 10
    fcFIR (1, 1) double {mustBeNonnegative} = 0.5
    fcIIR (1, 1) double {mustBeNonnegative} = 0.01
end

FFT_VENTANA = 128;
bytesPorMuestra = 8;
cmdStop = uint8(hex2dec('CC'));

bufferRx = uint8([]);
rawBuffer = nan(1, nVentana);
filtBuffer = nan(1, nVentana);
idx = 0;
numValidas = 0;

rawFFTBuffer = zeros(1, FFT_VENTANA);
filtFFTBuffer = zeros(1, FFT_VENTANA);
fftIdx = 0;
fftMuestrasNuevas = 0;
ventanaFFT = hann(FFT_VENTANA).';
freqFFT = (0:(FFT_VENTANA / 2 - 1)) * (fs / FFT_VENTANA);
fftCrudaDb = nan(1, FFT_VENTANA / 2);
fftFiltradaDb = nan(1, FFT_VENTANA / 2);

fig = figure('Name', 'Streaming ESP32 - cruda y filtrada', ...
    'NumberTitle', 'off', ...
    'CloseRequestFcn', @detenerStreaming);

ax1 = subplot(2, 1, 1, 'Parent', fig);
x = 1:nVentana;
lineRaw = plot(ax1, x, rawBuffer, 'Color', [0.20 0.20 0.20], 'LineWidth', 1.1);
hold(ax1, 'on');
lineFilt = plot(ax1, x, filtBuffer, 'Color', [0 0.35 0.80], 'LineWidth', 1.2);
hold(ax1, 'off');
grid(ax1, 'on');
title(ax1, 'Muestra cruda vs filtrada');
xlabel(ax1, 'Muestra');
ylabel(ax1, 'Amplitud');
legend(ax1, {'Cruda ADC', 'Filtrada'}, 'Location', 'best');

ax2 = subplot(2, 1, 2, 'Parent', fig);
lineFFTcruda = plot(ax2, freqFFT, fftCrudaDb, 'Color', [0.20 0.20 0.20], 'LineWidth', 1.1);
hold(ax2, 'on');
lineFFTfiltrada = plot(ax2, freqFFT, fftFiltradaDb, 'Color', [0 0.35 0.80], 'LineWidth', 1.2);
marcarCorte(ax2, fcFIR, sprintf('FIR LP %.3g Hz', fcFIR), [0 0.35 0.80]);
marcarCorte(ax2, fcIIR, sprintf('IIR HP %.3g Hz', fcIIR), [0.82 0.12 0.12]);
hold(ax2, 'off');
grid(ax2, 'on');
title(ax2, sprintf('FFT en vivo - ventana %d muestras', FFT_VENTANA));
xlabel(ax2, 'Frecuencia (Hz)');
ylabel(ax2, 'Magnitud (dB)');
xlim(ax2, [0 fs / 2]);
legend(ax2, {'Cruda', 'Filtrada'}, 'Location', 'best');

uicontrol(fig, 'Style', 'pushbutton', ...
    'String', 'Detener streaming', ...
    'Units', 'normalized', ...
    'Position', [0.40 0.01 0.20 0.05], ...
    'Callback', @detenerStreaming);

flush(s);
configureCallback(s, 'byte', bytesPorMuestra, @leerMuestra);

h = struct();
h.figure = fig;
h.serial = s;
h.stop = @() detenerStreaming([], []);

    function leerMuestra(src, ~)
        disponibles = src.NumBytesAvailable;
        if disponibles <= 0
            return;
        end

        nuevos = read(src, disponibles, 'uint8');
        bufferRx = [bufferRx nuevos(:).'];

        while numel(bufferRx) >= bytesPorMuestra
            paquete = bufferRx(1:bytesPorMuestra);
            bufferRx = bufferRx(bytesPorMuestra + 1:end);

            muestraCruda = double(typecast(uint8(paquete(1:4)), 'single'));
            muestraFiltrada = double(typecast(uint8(paquete(5:8)), 'single'));

            if ~isfinite(muestraCruda) || ~isfinite(muestraFiltrada)
                continue;
            end
            agregarMuestra(muestraCruda, muestraFiltrada);
        end
    end

    function agregarMuestra(muestraCruda, muestraFiltrada)
        idx = mod(idx, nVentana) + 1;
        numValidas = min(numValidas + 1, nVentana);

        rawBuffer(idx) = muestraCruda;
        filtBuffer(idx) = muestraFiltrada;
        agregarMuestraFFT(muestraCruda, muestraFiltrada);

        orden = indicesOrdenados();
        set(lineRaw, 'YData', rawBuffer(orden));
        set(lineFilt, 'YData', filtBuffer(orden));
        drawnow limitrate;
    end

    function agregarMuestraFFT(muestraCruda, muestraFiltrada)
        fftIdx = mod(fftIdx, FFT_VENTANA) + 1;
        rawFFTBuffer(fftIdx) = muestraCruda;
        filtFFTBuffer(fftIdx) = muestraFiltrada;
        fftMuestrasNuevas = fftMuestrasNuevas + 1;

        if fftMuestrasNuevas < FFT_VENTANA
            return;
        end
        fftMuestrasNuevas = 0;

        ordenFFT = [fftIdx + 1:FFT_VENTANA 1:fftIdx];
        crudaOrdenada = rawFFTBuffer(ordenFFT);
        filtradaOrdenada = filtFFTBuffer(ordenFFT);

        fftCrudaDb = calcularFFTdb(crudaOrdenada, ventanaFFT, FFT_VENTANA);
        fftFiltradaDb = calcularFFTdb(filtradaOrdenada, ventanaFFT, FFT_VENTANA);
        set(lineFFTcruda, 'YData', fftCrudaDb);
        set(lineFFTfiltrada, 'YData', fftFiltradaDb);
    end

    function orden = indicesOrdenados()
        if numValidas < nVentana
            orden = 1:nVentana;
        else
            orden = [idx + 1:nVentana 1:idx];
        end
    end

    function detenerStreaming(~, ~)
        try
            configureCallback(s, 'off');
        catch
        end
        try
            write(s, cmdStop, 'uint8');
        catch
        end
        if isvalid(fig)
            delete(fig);
        end
    end
end

function magDb = calcularFFTdb(x, ventana, n)
x = x(:).' .* ventana;
X = fft(x);
mag = abs(X(1:n / 2)) / n;
magDb = 20 * log10(mag + eps);
end

function marcarCorte(ax, fc, etiqueta, color)
if fc <= 0
    return;
end
xline(ax, fc, ':', etiqueta, 'Color', color, 'LineWidth', 1.0);
end
