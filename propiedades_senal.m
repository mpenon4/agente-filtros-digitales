function props = propiedades_senal(opcion_tp)
%OBTENER_PROPIEDADES_SENAL Hechos conocidos de la senal para opciones A-J.
%
% Esta capa no decide la arquitectura final. Solo expone propiedades de
% dominio y la referencia de catedra para validacion posterior.

op = upper(strtrim(string(opcion_tp)));

props = struct();
props.opcion_tp = char(op);
props.nombre = char(op);
props.fase_lineal_requerida = false;
props.tipo_respuesta = {};
props.pendiente_transicion = {};
props.fc_referencia = {};
props.ancho_transicion_hz = [];
props.nivel_ruido_esperado = 'medio';
props.descripcion = '';

switch op
    case "A"
        props.nombre = 'ECG';
        props.descripcion = 'ECG: rechazo de red y preservacion de morfologia cardiaca.';
        props.fase_lineal_requerida = true;
        props.tipo_respuesta = {'notch', 'lowpass'};
        props.pendiente_transicion = {'estrecha', 'estrecha'};
        props.fc_referencia = {[50 60], 40};
        props.nivel_ruido_esperado = 'alto';
    case "B"
        props.nombre = 'acelerometro MEMS';
        props.descripcion = 'Acelerometro MEMS: banda de vibracion y acondicionamiento anti-aliasing.';
        props.tipo_respuesta = {'bandpass', 'lowpass'};
        props.pendiente_transicion = {'estrecha', 'amplia'};
        props.fc_referencia = {[0.5 20], 20};
        props.nivel_ruido_esperado = 'medio';
    case "C"
        props.nombre = 'PPG';
        props.descripcion = 'PPG cardiaco: banda fisiologica estrecha para frecuencia cardiaca.';
        props.fase_lineal_requerida = true;
        props.tipo_respuesta = {'bandpass'};
        props.pendiente_transicion = {'estrecha'};
        props.fc_referencia = {[0.5 5]};
        props.nivel_ruido_esperado = 'medio';
    case "D"
        props.nombre = 'EMG';
        props.descripcion = 'EMG superficial: banda muscular y envolvente lenta.';
        props.tipo_respuesta = {'bandpass', 'lowpass'};
        props.pendiente_transicion = {'estrecha', 'amplia'};
        props.fc_referencia = {[20 450], 5};
        props.nivel_ruido_esperado = 'alto';
    case "E"
        props.nombre = 'temperatura PT100';
        props.descripcion = 'Temperatura PT100: suavizado lento de medicion industrial.';
        props.tipo_respuesta = {'lowpass'};
        props.pendiente_transicion = {'amplia'};
        props.fc_referencia = {0.5};
        props.nivel_ruido_esperado = 'bajo';
    case "F"
        props.nombre = 'presion con bomba';
        props.descripcion = 'Presion con bomba: rechazo de pulsacion y suavizado de ruido.';
        props.tipo_respuesta = {'notch', 'lowpass'};
        props.pendiente_transicion = {'estrecha', 'amplia'};
        props.fc_referencia = {35, 10};
        props.nivel_ruido_esperado = 'alto';
    case "G"
        props.nombre = 'nivel ultrasonico';
        props.descripcion = 'Nivel ultrasonico: suavizado exponencial luego de rechazo de outliers.';
        props.tipo_respuesta = {'lowpass'};
        props.pendiente_transicion = {'amplia'};
        props.fc_referencia = {1};
        props.nivel_ruido_esperado = 'medio';
    case "H"
        props.nombre = 'corriente electrica';
        props.descripcion = 'Corriente electrica: banco de pasa banda para armonicos principales.';
        props.tipo_respuesta = {'bandpass', 'bandpass', 'bandpass'};
        props.pendiente_transicion = {'estrecha', 'estrecha', 'estrecha'};
        props.fc_referencia = {[45 55], [95 105], [140 160]};
        props.nivel_ruido_esperado = 'medio';
    case "I"
        props.nombre = 'encoder';
        props.descripcion = 'Encoder: suavizado posterior al derivador discreto.';
        props.tipo_respuesta = {'lowpass'};
        props.pendiente_transicion = {'amplia'};
        props.fc_referencia = {50};
        props.nivel_ruido_esperado = 'bajo';
    case "J"
        props.nombre = 'CGM/SpO2';
        props.descripcion = 'CGM/SpO2: suavizado fisiologico y remocion de deriva/DC.';
        props.fase_lineal_requerida = true;
        props.tipo_respuesta = {'lowpass', 'highpass'};
        props.pendiente_transicion = {'amplia', 'amplia'};
        props.fc_referencia = {0.5, 0.01};
        props.nivel_ruido_esperado = 'medio';
    otherwise
        error('obtener_propiedades_senal:NoExiste', ...
            'No hay propiedades de senal para la opcion %s.', opcion_tp);
end

props.arquitectura_referencia_catedra = referenciasCatedra(op);
end

function refs = referenciasCatedra(op)
refs = struct();
refs.Arduino_UNO = referenciaSegura(op, 'Arduino Uno');
refs.ESP32 = referenciaSegura(op, 'ESP32');
refs.STM32F4 = referenciaSegura(op, 'STM32F4');
refs.ATtiny85 = refs.Arduino_UNO;
if ~isempty(refs.ATtiny85)
    refs.ATtiny85.plataforma_tabla = 'ATtiny85';
end
end

function plan = referenciaSegura(op, plataforma)
try
    plan = tabla_arquitecturas(op, plataforma);
catch
    plan = [];
end
end
