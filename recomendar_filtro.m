function [tipo, estructura, reglas, confianza, plan] = recomendar_filtro(fs, ram_kb, flash_kb, mips_mhz, fase_lineal, nivel_ruido, latencia, pendiente, opcion_tp, tipo_senal, plataforma)
%RECOMENDAR_FILTRO Sistema experto ponderado para recomendar FIR/IIR.
%
% Las constantes de configuracion implementan el criterio de reglas
% ponderadas requerido por el punto 4.4 del enunciado. A_s y los anchos de
% transicion son referencias de ingenieria para la aproximacion de Kaiser;
% ajustar si el informe define otro criterio.

cfg = configuracionReglas();

if nargin < 9 || strlength(string(opcion_tp)) == 0
    opcion_tp = "Personalizado";
end
if nargin < 10 || strlength(string(tipo_senal)) == 0
    tipo_senal = "Generica";
end
if nargin < 11 || strlength(string(plataforma)) == 0
    plataforma = "";
end

opcion_tp = upper(strtrim(string(opcion_tp)));
tipo_senal = lower(strtrim(string(tipo_senal)));
nivel_ruido = lower(strtrim(string(nivel_ruido)));
latencia = lower(strtrim(string(latencia)));
pendiente = lower(strtrim(string(pendiente)));

plataformaInfo = specsPlataforma(plataforma, ram_kb, flash_kb, mips_mhz);

if opcion_tp == "PERSONALIZADO"
    props = propiedadesPersonalizadas(fs, fase_lineal, nivel_ruido, pendiente, tipo_senal);
else
    props = obtener_propiedades_senal(opcion_tp);
end

props = completarConEntradas(props, fase_lineal, nivel_ruido, pendiente);
[plan, reglas, puntajeFIR, puntajeIIR, metricas] = construirPlanPonderado( ...
    props, fs, ram_kb, flash_kb, mips_mhz, fase_lineal, nivel_ruido, ...
    latencia, plataformaInfo, cfg);

plan.fs = fs;
plan.ram_kb = ram_kb;
plan.flash_kb = flash_kb;
plan.mips = mips_mhz;
plan.caso = char(opcion_tp);
plan.tipo_senal = char(tipo_senal);
plan.plataforma_inferida = plataformaInfo.nombre;
plan.tiene_fpu = plataformaInfo.tiene_fpu;
plan.puntaje_FIR = puntajeFIR;
plan.puntaje_IIR = puntajeIIR;
plan.metricas = metricas;
plan.resumen = resumenPlan(plan);
plan.validacion_referencia = validarReferencia(props, plataformaInfo, plan, metricas);

tipo = string(plan.resumen);
estructura = string(estructuraPlan(plan));
total = puntajeFIR + puntajeIIR;
if total <= 0
    confianza = 55;
else
    confianza = 100 * max(puntajeFIR, puntajeIIR) / total;
end
confianza = min(97, max(55, confianza));
end

function cfg = configuracionReglas()
cfg.PESO_FASE_LINEAL = 3;
cfg.PESO_RAM_CRITICA = 3;
cfg.PESO_ESTABILIDAD = 2;
cfg.PESO_TRANSICION_COMPUTO = 1;
cfg.PESO_FACTIBILIDAD = 3;
cfg.PESO_REFERENCIA_ETAPA = 2;
cfg.AS_REFERENCIA_DB = 40;
cfg.DELTA_F_ESTRECHA = 0.05;
cfg.DELTA_F_AMPLIA = 0.20;
cfg.BYTES_FLOAT32 = 4;
cfg.RAM_CRITICA_KB = 2;
cfg.ORDEN_FIR_RAM_CRITICO = 50;
end

function props = completarConEntradas(props, fase_lineal, nivel_ruido, pendiente)
if ~isfield(props, 'fase_lineal_requerida') || isempty(props.fase_lineal_requerida)
    props.fase_lineal_requerida = fase_lineal;
end
if ~isfield(props, 'nivel_ruido_esperado') || strlength(string(props.nivel_ruido_esperado)) == 0
    props.nivel_ruido_esperado = char(nivel_ruido);
end
if ~isfield(props, 'pendiente_transicion') || isempty(props.pendiente_transicion)
    props.pendiente_transicion = repmat({char(pendiente)}, 1, numel(props.tipo_respuesta));
end
end

function [plan, reglas, puntajeFIRTotal, puntajeIIRTotal, metricas] = construirPlanPonderado(props, fs, ram_kb, flash_kb, mips_mhz, fase_lineal, nivel_ruido, latencia, plataformaInfo, cfg)
reglas = {};
etapas = repmat(etapa("FIR", "lowpass", "", 1, 1, []), 1, numel(props.tipo_respuesta));
metricas = repmat(struct('orden_fir_estimado', 0, 'ram_fir_kb', 0, ...
    'ram_disponible_kb', ram_kb, 'puntaje_FIR', 0, 'puntaje_IIR', 0, ...
    'clase_recomendada', '', 'respuesta', '', 'pendiente', ''), ...
    1, numel(props.tipo_respuesta));
puntajeFIRTotal = 0;
puntajeIIRTotal = 0;
ordenesFIR = zeros(1, numel(props.tipo_respuesta));
ramFIRPorEtapaKb = zeros(1, numel(props.tipo_respuesta));
refEtapas = etapasReferencia(props, plataformaInfo);
refPorEtapa = cell(1, numel(props.tipo_respuesta));
usarEtapa = false(1, numel(props.tipo_respuesta));

for k = 1:numel(props.tipo_respuesta)
    respuesta = lower(string(props.tipo_respuesta{k}));
    pendienteEtapa = lower(string(props.pendiente_transicion{k}));
    refPorEtapa{k} = buscarEtapaReferencia(refEtapas, respuesta, k);
    usarEtapa(k) = isempty(refEtapas) || ~isempty(refPorEtapa{k});
    ordenesFIR(k) = estimarOrdenFIR(fs, pendienteEtapa, props, k, cfg, refPorEtapa{k});
    ramFIRPorEtapaKb(k) = memoriaFIRKb(ordenesFIR(k), cfg);
end
if ~any(usarEtapa)
    usarEtapa(:) = true;
end
ramFIRTotalKb = sum(ramFIRPorEtapaKb(usarEtapa));
etapasCalculadas = {};
metricasCalculadas = {};

for k = 1:numel(props.tipo_respuesta)
    if ~usarEtapa(k)
        reglas{end + 1} = sprintf('Etapa %d: la referencia de plataforma resuelve esta funcion dentro de otra etapa; no se agrega una etapa FIR/IIR adicional.', k); %#ok<AGROW>
        continue;
    end

    respuesta = lower(string(props.tipo_respuesta{k}));
    pendienteEtapa = lower(string(props.pendiente_transicion{k}));
    frecuencia = props.fc_referencia{k};
    ordenFIR = ordenesFIR(k);
    ramFIRKb = ramFIRPorEtapaKb(k);
    firNoEntra = ramFIRTotalKb > ram_kb;
    estabilidadCritica = esEstabilidadCritica(respuesta, pendienteEtapa, ordenFIR);
    ref = refPorEtapa{k};
    claseReferencia = claseEtapaReferencia(ref);

    puntajeFIR = 0;
    puntajeIIR = 0;
    reglasEtapa = {};

    if claseReferencia == "FIR"
        puntajeFIR = puntajeFIR + cfg.PESO_REFERENCIA_ETAPA;
        reglasEtapa{end + 1} = sprintf('Etapa %d: la referencia usa FIR; se toma como sesgo base y orden de referencia si aplica.', k); %#ok<AGROW>
    elseif claseReferencia == "IIR"
        puntajeIIR = puntajeIIR + cfg.PESO_REFERENCIA_ETAPA;
        reglasEtapa{end + 1} = sprintf('Etapa %d: la referencia usa IIR; se mantiene como sesgo base salvo que recursos/fase justifiquen cambiar.', k); %#ok<AGROW>
    end

    if fase_lineal && (claseReferencia == "FIR" || claseReferencia == "")
        puntajeFIR = puntajeFIR + cfg.PESO_FASE_LINEAL;
        reglasEtapa{end + 1} = sprintf('Etapa %d: fase lineal solicitada por el usuario en una etapa compatible con FIR; se suma peso %d a FIR.', k, cfg.PESO_FASE_LINEAL); %#ok<AGROW>
    elseif fase_lineal && claseReferencia == "IIR"
        reglasEtapa{end + 1} = sprintf('Etapa %d: fase lineal global activada, pero la etapa de referencia es IIR; no se convierte automaticamente a FIR.', k); %#ok<AGROW>
    elseif ~fase_lineal
        reglasEtapa{end + 1} = sprintf('Etapa %d: fase lineal no solicitada por el usuario; no se suma peso a FIR por fase.', k); %#ok<AGROW>
    end

    if ram_kb < cfg.RAM_CRITICA_KB && ordenFIR > cfg.ORDEN_FIR_RAM_CRITICO
        puntajeIIR = puntajeIIR + cfg.PESO_RAM_CRITICA;
        reglasEtapa{end + 1} = sprintf('Etapa %d: RAM < %.1f kB y FIR estimado de orden %d; se suma peso %d a IIR.', k, cfg.RAM_CRITICA_KB, ordenFIR, cfg.PESO_RAM_CRITICA); %#ok<AGROW>
    end

    if ~plataformaInfo.tiene_fpu && estabilidadCritica
        reglasEtapa{end + 1} = sprintf('Etapa %d: sin FPU hardware y estabilidad numerica critica; se fuerza estructura SOS en etapas IIR.', k); %#ok<AGROW>
    end

    if pendienteEtapa == "estrecha" && mips_mhz > 40
        puntajeIIR = puntajeIIR + cfg.PESO_TRANSICION_COMPUTO;
        reglasEtapa{end + 1} = sprintf('Etapa %d: transicion estrecha con computo disponible; se suma peso %d a IIR por menor orden.', k, cfg.PESO_TRANSICION_COMPUTO); %#ok<AGROW>
    end

    if firNoEntra
        puntajeIIR = puntajeIIR + cfg.PESO_FACTIBILIDAD;
        reglasEtapa{end + 1} = sprintf('Etapa %d: la cadena FIR estimada usa %.2f kB y no entra en %.2f kB; se suma peso %d a IIR como trade-off de recursos.', k, ramFIRTotalKb, ram_kb, cfg.PESO_FACTIBILIDAD); %#ok<AGROW>
    else
        reglasEtapa{end + 1} = sprintf('Etapa %d: FIR estimado de orden %d usa %.2f kB; cadena completa %.2f de %.2f kB disponibles.', k, ordenFIR, ramFIRKb, ramFIRTotalKb, ram_kb); %#ok<AGROW>
    end

    if nivel_ruido == "alto" || lower(string(props.nivel_ruido_esperado)) == "alto"
        reglasEtapa{end + 1} = sprintf('Etapa %d: ruido alto; mantener A_s de referencia en %.0f dB y validar SNR.', k, cfg.AS_REFERENCIA_DB); %#ok<AGROW>
    end
    if flash_kb < 16
        reglasEtapa{end + 1} = sprintf('Etapa %d: flash reducida; conviene exportar coeficientes compactos.', k); %#ok<AGROW>
    end

    if claseReferencia ~= ""
        clase = claseReferencia;
    else
        clase = "FIR";
    end
    if puntajeIIR > puntajeFIR || (firNoEntra && puntajeIIR == puntajeFIR)
        clase = "IIR";
    elseif puntajeFIR > puntajeIIR
        clase = "FIR";
    end

    if clase == "FIR"
        orden = ordenFIR;
    else
        orden = ordenIIRCalculado(respuesta, pendienteEtapa, latencia, estabilidadCritica, ref);
    end

    descripcion = descripcionEtapa(clase, respuesta, orden, frecuencia, props.nombre);
    etapaCalculada = etapa(clase, respuesta, descripcion, orden, frecuencia, qPorRespuesta(respuesta));

    if clase == "IIR" && (~plataformaInfo.tiene_fpu || estabilidadCritica)
        etapaCalculada.estructura = 'SOS / Direct Form II transposed';
    end

    metricaCalculada = metricas(k);
    metricaCalculada.orden_fir_estimado = ordenFIR;
    metricaCalculada.ram_fir_kb = ramFIRKb;
    metricaCalculada.ram_disponible_kb = ram_kb;
    metricaCalculada.puntaje_FIR = puntajeFIR;
    metricaCalculada.puntaje_IIR = puntajeIIR;
    metricaCalculada.clase_recomendada = char(clase);
    metricaCalculada.respuesta = char(respuesta);
    metricaCalculada.pendiente = char(pendienteEtapa);
    etapasCalculadas{end + 1} = etapaCalculada; %#ok<AGROW>
    metricasCalculadas{end + 1} = metricaCalculada; %#ok<AGROW>

    puntajeFIRTotal = puntajeFIRTotal + puntajeFIR;
    puntajeIIRTotal = puntajeIIRTotal + puntajeIIR;
    reglas = [reglas reglasEtapa]; %#ok<AGROW>
end

plan = struct();
plan.etapas = [etapasCalculadas{:}];
metricas = [metricasCalculadas{:}];
plan.confianzaBase = 70;
plan.descripcion = props.descripcion;
end

function n = estimarOrdenFIR(fs, pendiente, props, idx, cfg, ref)
if isfield(props, 'ancho_transicion_hz') && numel(props.ancho_transicion_hz) >= idx && props.ancho_transicion_hz(idx) > 0
    deltaF = props.ancho_transicion_hz(idx) / fs;
elseif pendiente == "estrecha"
    deltaF = cfg.DELTA_F_ESTRECHA;
else
    deltaF = cfg.DELTA_F_AMPLIA;
end
deltaF = max(deltaF, 1e-6);
n = ceil((cfg.AS_REFERENCIA_DB - 8) / (2.285 * 2 * pi * deltaF));
if ~isempty(ref) && isfield(ref, 'clase') && upper(string(ref.clase)) == "FIR" && isfield(ref, 'orden') && ref.orden > 0
    n = max(n, round(ref.orden));
end
end

function kb = memoriaFIRKb(orden, cfg)
taps = orden + 1;
bytesCoeficientes = taps * cfg.BYTES_FLOAT32;
bytesBufferCircular = taps * cfg.BYTES_FLOAT32;
kb = (bytesCoeficientes + bytesBufferCircular) / 1024;
end

function tf = esEstabilidadCritica(respuesta, pendiente, ordenFIR)
tf = respuesta == "notch" || respuesta == "bandpass" || pendiente == "estrecha" || ordenFIR > 80;
end

function orden = ordenIIRCalculado(respuesta, pendiente, latencia, estabilidadCritica, ref)
if ~isempty(ref) && isfield(ref, 'clase') && upper(string(ref.clase)) == "IIR" && isfield(ref, 'orden') && ref.orden > 0
    orden = round(ref.orden);
elseif respuesta == "notch"
    orden = 2;
elseif respuesta == "bandpass"
    orden = 6;
elseif pendiente == "estrecha"
    orden = 4;
else
    orden = 2;
end
if lower(string(latencia)) == "baja"
    orden = max(2, min(orden, 4));
end
if estabilidadCritica && orden < 4 && respuesta ~= "notch"
    orden = 4;
end
end

function refEtapas = etapasReferencia(props, plataformaInfo)
refEtapas = [];
key = plataformaInfo.key;
if isfield(props, 'arquitectura_referencia_catedra') && isfield(props.arquitectura_referencia_catedra, key)
    refPlan = props.arquitectura_referencia_catedra.(key);
    if ~isempty(refPlan) && isfield(refPlan, 'etapas')
        refEtapas = refPlan.etapas;
    end
end
end

function ref = buscarEtapaReferencia(refEtapas, respuesta, idx)
ref = [];
if isempty(refEtapas)
    return;
end
respuesta = lower(string(respuesta));
for k = 1:numel(refEtapas)
    if lower(string(refEtapas(k).respuesta)) == respuesta
        ref = refEtapas(k);
        return;
    end
end
end

function clase = claseEtapaReferencia(ref)
clase = "";
if ~isempty(ref) && isfield(ref, 'clase')
    c = upper(string(ref.clase));
    if c == "FIR" || c == "IIR"
        clase = c;
    end
end
end

function q = qPorRespuesta(respuesta)
if lower(string(respuesta)) == "notch"
    q = 4;
else
    q = [];
end
end

function txt = descripcionEtapa(clase, respuesta, orden, frecuencia, nombre)
txt = sprintf('%s %s calculado por reglas ponderadas para %s, orden %d, fc=%s Hz', ...
    char(clase), char(respuesta), char(nombre), orden, mat2str(frecuencia));
end

function validacion = validarReferencia(props, plataformaInfo, plan, metricas)
tipoCalculado = resumenPlan(plan);
validacion = struct('plataforma', plataformaInfo.nombre, 'consistente', false, ...
    'mensaje', 'Sin arquitectura de referencia para comparar.', ...
    'tipo_referencia', '', 'tipo_calculado', char(tipoCalculado));

ref = [];
key = plataformaInfo.key;
if isfield(props, 'arquitectura_referencia_catedra') && isfield(props.arquitectura_referencia_catedra, key)
    ref = props.arquitectura_referencia_catedra.(key);
end
if isempty(ref) || ~isfield(ref, 'etapas')
    return;
end

tipoRef = resumenPlan(ref);
tipoCalc = resumenPlan(plan);
validacion.tipo_referencia = char(tipoRef);
validacion.tipo_calculado = char(tipoCalc);
validacion.consistente = strcmp(char(tipoRef), char(tipoCalc));

if validacion.consistente
    validacion.mensaje = 'Consistente con arquitectura de referencia del Anexo I para esta combinacion.';
else
    ordenMax = max([metricas.orden_fir_estimado]);
    ramUsada = sum([metricas.ram_fir_kb]);
    if contains(tipoCalc, "FIR") && ramUsada <= plan.ram_kb
        validacion.mensaje = sprintf('Difiere de la referencia (que sugiere %s): con esta plataforma el orden FIR estimado maximo (%d) entra en RAM (%.2f de %.2f kB usados), por lo que se prioriza preservar fase lineal.', char(tipoRef), ordenMax, ramUsada, plan.ram_kb);
    else
        validacion.mensaje = sprintf('Difiere de la referencia (que sugiere %s): el motor ponderado prioriza recursos/latencia con orden FIR estimado maximo %d y %.2f de %.2f kB requeridos.', char(tipoRef), ordenMax, ramUsada, plan.ram_kb);
    end
end
end

function info = specsPlataforma(plataforma, ram_kb, flash_kb, mips_mhz)
p = upper(strtrim(string(plataforma)));
p = replace(p, " ", "");
switch p
    case "ESP32"
        info = struct('nombre', 'ESP32', 'key', 'ESP32', 'tiene_fpu', true);
    case "STM32F4"
        info = struct('nombre', 'STM32F4', 'key', 'STM32F4', 'tiene_fpu', true);
    case {"ARDUINOUNO", "ARDUINO", "UNO"}
        info = struct('nombre', 'Arduino UNO', 'key', 'Arduino_UNO', 'tiene_fpu', false);
    case "ATTINY85"
        info = struct('nombre', 'ATtiny85', 'key', 'ATtiny85', 'tiene_fpu', false);
    otherwise
        if ram_kb <= 1 && flash_kb <= 16 && mips_mhz <= 10
            info = struct('nombre', 'ATtiny85', 'key', 'ATtiny85', 'tiene_fpu', false);
        elseif ram_kb <= 3 && flash_kb <= 64 && mips_mhz <= 25
            info = struct('nombre', 'Arduino UNO', 'key', 'Arduino_UNO', 'tiene_fpu', false);
        elseif ram_kb >= 150 && mips_mhz >= 120
            info = struct('nombre', 'ESP32 / STM32', 'key', 'ESP32', 'tiene_fpu', true);
        else
            info = struct('nombre', 'Intermedia / personalizada', 'key', 'Personalizada', 'tiene_fpu', mips_mhz >= 80);
        end
end
end

function props = propiedadesPersonalizadas(fs, fase_lineal, nivel_ruido, pendiente, tipo_senal)
props = struct();
props.nombre = 'caso personalizado';
props.descripcion = 'Caso personalizado: propiedades inferidas desde entradas de usuario.';
props.fase_lineal_requerida = fase_lineal;
props.nivel_ruido_esperado = char(nivel_ruido);
if contains(tipo_senal, "medica") || contains(tipo_senal, "biomed") || contains(tipo_senal, "glucosa") || contains(tipo_senal, "spo")
    props.tipo_respuesta = {'lowpass', 'highpass'};
    props.pendiente_transicion = {char(pendiente), 'amplia'};
    props.fc_referencia = {min(0.5, 0.4 * fs), min(0.01, 0.05 * fs)};
    props.descripcion = 'Caso personalizado biomedico: suavizado util y remocion de deriva.';
else
    props.tipo_respuesta = {'lowpass'};
    props.pendiente_transicion = {char(pendiente)};
    props.fc_referencia = {min(0.2 * fs, 0.4 * fs)};
end
props.ancho_transicion_hz = [];
props.arquitectura_referencia_catedra = struct();
end

function e = etapa(clase, respuesta, descripcion, orden, frecuencia, q)
e = struct('clase', char(clase), 'respuesta', char(respuesta), ...
    'descripcion', char(descripcion), 'orden', orden, ...
    'frecuencia', frecuencia, 'q', q, 'estructura', estructuraEtapa(clase));
end

function txt = estructuraEtapa(clase)
if upper(string(clase)) == "IIR"
    txt = 'SOS / Direct Form II transposed';
else
    txt = 'FIR directo con buffer circular';
end
end

function txt = resumenPlan(plan)
clases = strings(1, numel(plan.etapas));
for k = 1:numel(plan.etapas)
    clases(k) = string(plan.etapas(k).clase);
end
txt = strjoin(clases, " + ");
end

function txt = estructuraPlan(plan)
partes = strings(1, numel(plan.etapas));
for k = 1:numel(plan.etapas)
    partes(k) = sprintf('%s: %s', plan.etapas(k).clase, plan.etapas(k).estructura);
end
txt = strjoin(partes, " | ");
end
