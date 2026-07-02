function filtro = disenar_filtro(tipo, fs, plan)
%DISENAR_FILTRO Disena una etapa o cadena de filtros desde el plan del agente.
%
% filtro = disenar_filtro(tipo, fs) mantiene compatibilidad con la version
% anterior. filtro = disenar_filtro(tipo, fs, plan) disena todas las etapas.

if nargin < 3 || isempty(plan)
    plan = planBasico(tipo, fs);
end

filtro = struct();
filtro.tipo = char(tipo);
filtro.fs = fs;
filtro.etapas = [];

for k = 1:numel(plan.etapas)
    e = plan.etapas(k);
    clase = upper(string(e.clase));
    if clase == "FIR"
        etapaDisenada = disenarFIR(e, fs);
    elseif clase == "IIR"
        etapaDisenada = disenarIIR(e, fs);
    else
        etapaDisenada = disenarAuxiliar(e, fs);
    end
    if k == 1
        filtro.etapas = etapaDisenada;
    else
        filtro.etapas(k) = etapaDisenada;
    end
end

if numel(filtro.etapas) == 1
    if strcmp(filtro.etapas(1).clase, 'FIR')
        filtro.b = filtro.etapas(1).b;
        filtro.a = 1;
    else
        filtro.sos = filtro.etapas(1).sos;
        filtro.scaleValues = 1;
    end
end
end

function plan = planBasico(tipo, fs)
tipo = upper(string(tipo));
if contains(tipo, "IIR")
    e = struct('clase', 'IIR', 'respuesta', 'lowpass', 'descripcion', ...
        'IIR pasa bajos generico', 'orden', 6, 'frecuencia', min(0.2 * fs, 0.4 * fs), ...
        'q', [], 'estructura', 'SOS');
else
    e = struct('clase', 'FIR', 'respuesta', 'lowpass', 'descripcion', ...
        'FIR pasa bajos generico', 'orden', 64, 'frecuencia', min(0.2 * fs, 0.4 * fs), ...
        'q', [], 'estructura', 'FIR directo');
end
plan = struct('etapas', e);
end

function out = disenarFIR(e, fs)
orden = max(1, round(e.orden));
respuesta = lower(string(e.respuesta));
freq = limitarFrecuencia(e.frecuencia, fs, respuesta);
metodo = 'Ventana Hamming';

switch respuesta
    case "derivative"
        b = [1 -1];
        orden = 1;
        out = struct('clase', 'FIR', 'respuesta', char(respuesta), ...
            'descripcion', e.descripcion, 'estructura', e.estructura, ...
            'orden', orden, 'frecuencia', freq, 'b', b, ...
            'a', 1, 'sos', [], 'coeficientes', b, ...
            'metodo', 'Derivador FIR discreto H(z)=1-z^-1', 'prototipo', '');
        return;
    case "notch"
        f0 = freq(1);
        bw = max(0.05 * f0, fs * 0.01);
        f1 = max(f0 - bw / 2, fs / 2 * 0.001);
        f2 = min(f0 + bw / 2, fs / 2 * 0.95);
        d = designfilt('bandstopfir', 'FilterOrder', orden, ...
            'CutoffFrequency1', f1, 'CutoffFrequency2', f2, ...
            'SampleRate', fs, 'DesignMethod', 'window', 'Window', 'hamming');
    case "highpass"
        d = designfilt('highpassfir', 'FilterOrder', orden, ...
            'CutoffFrequency', freq(1), 'SampleRate', fs, ...
            'DesignMethod', 'window', 'Window', 'hamming');
    case "bandpass"
        d = designfilt('bandpassfir', 'FilterOrder', orden, ...
            'CutoffFrequency1', freq(1), 'CutoffFrequency2', freq(2), ...
            'SampleRate', fs, 'DesignMethod', 'window', 'Window', 'hamming');
    otherwise
        d = designfilt('lowpassfir', 'FilterOrder', orden, ...
            'CutoffFrequency', freq(1), 'SampleRate', fs, ...
            'DesignMethod', 'window', 'Window', 'hamming');
end

out = struct('clase', 'FIR', 'respuesta', char(respuesta), ...
    'descripcion', e.descripcion, 'estructura', e.estructura, ...
    'orden', orden, 'frecuencia', freq, 'b', d.Coefficients(:).', ...
    'a', 1, 'sos', [], 'coeficientes', d.Coefficients(:).', ...
    'metodo', metodo, 'prototipo', '');
end

function out = disenarIIR(e, fs)
orden = max(1, round(e.orden));
respuesta = lower(string(e.respuesta));
freq = limitarFrecuencia(e.frecuencia, fs, respuesta);

switch respuesta
    case "highpass"
        d = designfilt('highpassiir', 'FilterOrder', orden, ...
            'HalfPowerFrequency', freq(1), 'SampleRate', fs, 'DesignMethod', 'butter');
        sosMatrix = d.Coefficients;
    case "bandpass"
        if mod(orden, 2) ~= 0
            orden = orden + 1;
        end
        d = designfilt('bandpassiir', 'FilterOrder', orden, ...
            'HalfPowerFrequency1', freq(1), 'HalfPowerFrequency2', freq(2), ...
            'SampleRate', fs, 'DesignMethod', 'butter');
        sosMatrix = d.Coefficients;
    case "notch"
        f0 = freq(1);
        q = e.q;
        if isempty(q)
            q = 10;
        end
        bw = max(f0 / q, fs * 0.005);
        wo = f0 / (fs / 2);
        bwNorm = min(0.99, bw / (fs / 2));
        [b, a] = iirnotch(wo, bwNorm);
        sosMatrix = tf2sos(b, a);
        orden = 2;
    otherwise
        d = designfilt('lowpassiir', 'FilterOrder', orden, ...
            'HalfPowerFrequency', freq(1), 'SampleRate', fs, 'DesignMethod', 'butter');
        sosMatrix = d.Coefficients;
end

out = struct('clase', 'IIR', 'respuesta', char(respuesta), ...
    'descripcion', e.descripcion, 'estructura', e.estructura, ...
    'orden', orden, 'frecuencia', freq, 'b', [], 'a', [], ...
    'sos', sosMatrix, 'coeficientes', sosMatrix, ...
    'metodo', 'Transformada bilineal via designfilt', ...
    'prototipo', 'Butterworth / notch biquad');
end

function out = disenarAuxiliar(e, fs)
out = struct('clase', e.clase, 'respuesta', e.respuesta, ...
    'descripcion', e.descripcion, 'estructura', e.estructura, ...
    'orden', e.orden, 'frecuencia', e.frecuencia, ...
    'b', [], 'a', [], 'sos', [], 'coeficientes', [], ...
    'metodo', 'Etapa auxiliar no lineal/no parametrica', ...
    'prototipo', '', 'fs', fs);
end

function freq = limitarFrecuencia(freq, fs, respuesta)
nyq = fs / 2;
if isempty(freq)
    freq = nyq * 0.2;
end
if lower(string(respuesta)) == "bandpass"
    freq = sort(freq(:).');
    freq(1) = max(freq(1), nyq * 0.001);
    freq(2) = min(freq(2), nyq * 0.95);
    if freq(2) <= freq(1)
        freq = [nyq * 0.1 nyq * 0.4];
    end
else
    if lower(string(respuesta)) == "lowpass"
        freq = freq(end);
    else
        freq = freq(1);
    end
    freq = max(freq, nyq * 0.001);
    freq = min(freq, nyq * 0.9);
end
end
