function resultados = enviar_cadena_esp32(s, filtro, entradas)
%ENVIAR_CADENA_ESP32 Envia coeficientes al ESP32 con el protocolo real 0xAA.
%
% Formato implementado por protocolo.cpp:
% [0xAA][tipo][N uint16 LE][json_len uint16 LE][JSON UTF-8]
% [N floats32 LE][CRC16-CCITT-FALSE uint16 LE]
%
% tipo: 0x00 FIR, 0x01 IIR-SOS.
% FIR: N = cantidad de taps b[n].
% IIR: N = cantidad total de floats SOS, multiplo de 6.

arguments
    s
    filtro struct
    entradas struct = struct()
end

MAX_FIR_FLOATS_ESP32 = 200;
MAX_IIR_FLOATS_ESP32 = 120;

resultados = repmat(struct('etapa', 0, 'tipo', '', 'n', 0, 'ack', false), ...
    1, numel(filtro.etapas));

for k = 1:numel(filtro.etapas)
    etapa = filtro.etapas(k);
    if ~strcmp(etapa.clase, 'FIR') && ~strcmp(etapa.clase, 'IIR')
        resultados(k).etapa = k;
        resultados(k).tipo = etapa.clase;
        resultados(k).n = 0;
        resultados(k).ack = true;
        warning('enviar_cadena_esp32:EtapaAuxiliar', ...
            'Etapa %d (%s) no se envia por UART porque no es FIR/IIR.', k, etapa.clase);
        continue;
    end
    validarEtapaParaESP32(etapa, k, MAX_FIR_FLOATS_ESP32, MAX_IIR_FLOATS_ESP32);
    pkt = armarPaquete(filtro, etapa, k, numel(filtro.etapas), entradas);
    limpiarEntrada(s);
    write(s, pkt, 'uint8');
    [ack, respuestaACK] = esperarACK(s, 5.0);

    resultados(k).etapa = k;
    resultados(k).tipo = etapa.clase;
    if strcmp(etapa.clase, 'FIR')
        resultados(k).n = numel(etapa.b);
    else
        resultados(k).n = numel(etapa.sos);
    end
    resultados(k).ack = ack;

    if ~ack
        error('enviar_cadena_esp32:ACK', ...
            'El ESP32 rechazo o no confirmo la etapa %d (%s). Respuesta recibida: %s', ...
            k, etapa.clase, respuestaACK);
    end
end

end

function validarEtapaParaESP32(etapa, idx, maxFIR, maxIIR)
if strcmp(etapa.clase, 'FIR')
    n = numel(etapa.b);
    if n < 1 || n > maxFIR
        error('enviar_cadena_esp32:FIRFueraDeRango', ...
            ['La etapa %d (FIR) tiene N=%d coeficientes, pero el firmware ESP32 ', ...
            'acepta 1..%d. En MATLAB un FIR de orden %d genera %d coeficientes; ', ...
            'baje el orden a %d o aumente el limite del firmware.'], ...
            idx, n, maxFIR, etapa.orden, n, maxFIR - 1);
    end
elseif strcmp(etapa.clase, 'IIR')
    n = numel(etapa.sos);
    if n < 6 || n > maxIIR || mod(n, 6) ~= 0
        error('enviar_cadena_esp32:IIRFueraDeRango', ...
            ['La etapa %d (IIR) tiene N=%d floats SOS, pero el firmware ESP32 ', ...
            'requiere N multiplo de 6 y rango 6..%d.'], ...
            idx, n, maxIIR);
    end
end
end

function limpiarEntrada(s)
try
    flush(s, 'input');
catch
    flush(s);
end
end

function pkt = armarPaquete(filtro, etapa, idx, total, entradas)
if strcmp(etapa.clase, 'FIR')
    tipo = uint8(0);
    coefs = single(etapa.b(:));
else
    tipo = uint8(1);
    coefs = single(reshape(etapa.sos.', [], 1));
end

n = uint16(numel(coefs));
meta = struct();
meta.fs = filtro.fs;
meta.etapa = idx;
meta.etapas_total = total;
meta.orden = etapa.orden;
meta.frecuencia = frecuenciaPrincipal(etapa.frecuencia);
meta.clase = etapa.clase;
meta.respuesta = etapa.respuesta;
meta.estructura = etapa.estructura;
meta.opcion_tp = campoEntrada(entradas, 'opcion_tp', '?');
meta.mcu = campoEntrada(entradas, 'mcu', 'ESP32');

json = uint8(char(jsonencode(meta)));
jsonLen = uint16(numel(json));
payload = typecast(coefs, 'uint8');

pktSinCRC = [ ...
    uint8(hex2dec('AA')), ...
    tipo, ...
    typecast(n, 'uint8'), ...
    typecast(jsonLen, 'uint8'), ...
    json(:).', ...
    payload(:).' ...
];
crc = crc16(pktSinCRC);
pkt = [pktSinCRC typecast(crc, 'uint8')];
end

function [ack, respuestaTxt] = esperarACK(s, timeoutSeg)
t0 = tic;
ack = false;
respuestaTxt = '<sin bytes>';
rx = uint8([]);
while toc(t0) < timeoutSeg
    if s.NumBytesAvailable > 0
        nuevos = read(s, s.NumBytesAvailable, 'uint8');
        rx = [rx nuevos(:).']; %#ok<AGROW>
        if any(rx == uint8(1)) || any(rx == uint8(6))
            ack = true;
            return;
        end
        texto = upper(char(rx(rx >= 9 & rx <= 126)));
        if contains(string(texto), "ACK") || contains(string(texto), "OK")
            ack = true;
            return;
        end
        if contains(string(texto), "ERR") || contains(string(texto), "CRC")
            respuestaTxt = textoLegible(rx);
            return;
        end
    else
        pause(0.005);
    end
end
respuestaTxt = textoLegible(rx);
end

function txt = textoLegible(rx)
if isempty(rx)
    txt = '<sin bytes>';
    return;
end
ascii = char(rx(rx >= 32 & rx <= 126));
hex = sprintf('%02X ', rx);
hex = strtrim(hex);
if isempty(ascii)
    txt = sprintf('hex[%s]', hex);
else
    txt = sprintf('"%s" hex[%s]', ascii, hex);
end
end

function f = frecuenciaPrincipal(freq)
if isempty(freq)
    f = 0;
else
    f = double(freq(1));
end
end

function v = campoEntrada(s, nombre, def)
if isfield(s, nombre)
    v = s.(nombre);
else
    v = def;
end
end
