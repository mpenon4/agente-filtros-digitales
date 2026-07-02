function plan = tabla_arquitecturas(opcion_tp, plataforma)
%OBTENER_ARQUITECTURA Tabla hardcodeada del Anexo I por plataforma.
%
% Los valores marcados como "por defecto" son referencias iniciales de
% literatura/clase. Deben ajustarse segun el analisis espectral real de la
% senal en los Pasos 1-3 del informe si el grupo cuenta con esos datos.

FC_BP_ACEL = [0.5 20];
FC_BP_PPG = [0.5 5];
FC_BP_EMG = [20 450];
FC_LP_TEMP = [0.1 1];
FC_PRESION_LP = 10;
FC_NIVEL_EMA = 1;
FC_ARMONICOS = [50 100 150];
FC_ENCODER_LP = 50;
FC_CGM_LP = 0.5;
FC_CGM_HP = 0.01;
FC_ECG_NOTCH = [50 60];
FC_ECG_LP = 40;

ORD_FIR_ESP_BP = 60;
ORD_FIR_ESP_NOTCH_LP = 60;
ORD_FIR_BANCO_H = 80;
ORD_FIR_DERIVADOR = 60;
ORD_FIR_J = 200;
ORD_IIR_ENV = 2;

op = upper(strtrim(string(opcion_tp)));
plat = normalizarPlataforma(plataforma);

plan = basePlan(op, plat);

switch plat
    case "ARDUINO"
        switch op
            case "A"
                plan.descripcion = 'ECG en Arduino UNO: IIR unico orden 4 reemplaza notch + lowpass.';
                plan.etapas = etapa("IIR", "lowpass", plan.descripcion, 4, FC_ECG_LP, []);
                plan.notas = {'fc_notch referencia=[50 60] Hz; fc_lp=40 Hz.'};
            case "B"
                plan.descripcion = 'Acelerometro MEMS en Arduino UNO: IIR unico orden 6 reemplaza bandpass + lowpass.';
                plan.etapas = etapa("IIR", "bandpass", plan.descripcion, 6, FC_BP_ACEL, []);
            case "C"
                plan.descripcion = 'PPG cardiaco en Arduino UNO: FIR bandpass estrecho.';
                plan.etapas = etapa("FIR", "bandpass", plan.descripcion, 100, FC_BP_PPG, []);
            case "D"
                plan.descripcion = 'EMG superficial en Arduino UNO: IIR cascada orden 6 reemplaza bandpass + envolvente.';
                plan.etapas = etapa("IIR", "bandpass", plan.descripcion, 6, FC_BP_EMG, []);
            case "E"
                plan.descripcion = 'Temperatura PT100 en Arduino UNO: mediana + IIR lowpass orden 2.';
                plan.etapas = [ ...
                    etapa("MEDIANA", "median", "Filtro de mediana para spikes", 5, 0, []), ...
                    etapa("IIR", "lowpass", "IIR lowpass orden 2 para suavizado", 2, FC_LP_TEMP, [])];
            case "F"
                plan.descripcion = 'Presion de bomba en Arduino UNO: IIR unico orden 4 reemplaza notch ajustable + lowpass.';
                plan.etapas = etapa("IIR", "lowpass", plan.descripcion, 4, FC_PRESION_LP, []);
            case "G"
                plan.descripcion = 'Nivel ultrasonico en Arduino UNO: mediana + EMA trivial.';
                plan.etapas = [ ...
                    etapa("MEDIANA", "median", "Filtro de mediana para ecos espurios", 5, 0, []), ...
                    etapa("IIR", "lowpass", "EMA equivalente a IIR de primer orden", 1, FC_NIVEL_EMA, [])];
            case "H"
                plan.descripcion = 'Corriente electrica en Arduino UNO: banco IIR de filtros pasa banda, recursos marginales.';
                plan.etapas = [ ...
                    etapa("IIR", "bandpass", "IIR BP fundamental 50 Hz", 4, [45 55], []), ...
                    etapa("IIR", "bandpass", "IIR BP armonico 100 Hz", 4, [95 105], []), ...
                    etapa("IIR", "bandpass", "IIR BP armonico 150 Hz", 4, [140 160], [])];
                plan.confianzaBase = 50;
                plan.advertencias = {'MARGINAL: Arduino UNO queda justo para banco de filtros; validar carga de CPU y memoria.'};
                plan.fc_referencia = FC_ARMONICOS;
            case "I"
                plan.descripcion = 'Encoder en Arduino UNO: IIR unico orden 2 reemplaza derivador + lowpass.';
                plan.etapas = etapa("IIR", "lowpass", plan.descripcion, 2, FC_ENCODER_LP, []);
            case "J"
                plan.descripcion = 'SpO2/CGM en Arduino UNO: FIR lowpass + IIR highpass para deriva.';
                plan.etapas = [ ...
                    etapa("FIR", "lowpass", "FIR lowpass fc=0.5 Hz", ORD_FIR_J, FC_CGM_LP, []), ...
                    etapa("IIR", "highpass", "IIR highpass orden 1 fc=0.01 Hz", 1, FC_CGM_HP, [])];
        end

    case {"ESP32", "STM32F4"}
        switch op
            case "A"
                plan.descripcion = sprintf('%s: ECG con notch IIR + FIR lowpass.', plat);
                plan.etapas = [ ...
                    etapa("IIR", "notch", "Notch IIR orden 2 para red 50/60 Hz", 2, FC_ECG_NOTCH, 4), ...
                    etapa("FIR", "lowpass", "FIR lowpass orden 80 fc=40 Hz", 80, FC_ECG_LP, [])];
            case "B"
                plan.descripcion = sprintf('%s: acelerometro con FIR bandpass + IIR lowpass.', plat);
                plan.etapas = [ ...
                    etapa("FIR", "bandpass", "FIR bandpass orden 60", 60, FC_BP_ACEL, []), ...
                    etapa("IIR", "lowpass", "IIR lowpass orden 2 de acondicionamiento", 2, FC_BP_ACEL(2), [])];
            case "C"
                plan.descripcion = sprintf('%s: PPG con FIR bandpass estrecho.', plat);
                plan.etapas = etapa("FIR", "bandpass", plan.descripcion, 200, FC_BP_PPG, []);
            case "D"
                plan.descripcion = sprintf('%s: EMG con FIR bandpass + IIR envolvente.', plat);
                plan.etapas = [ ...
                    etapa("FIR", "bandpass", "FIR bandpass EMG, orden por defecto 60", ORD_FIR_ESP_BP, FC_BP_EMG, []), ...
                    etapa("IIR", "lowpass", "IIR envolvente, orden por defecto 2", ORD_IIR_ENV, 5, [])];
            case "E"
                plan.descripcion = sprintf('%s: temperatura con mediana + IIR lowpass orden 2.', plat);
                plan.etapas = [ ...
                    etapa("MEDIANA", "median", "Filtro de mediana para spikes", 5, 0, []), ...
                    etapa("IIR", "lowpass", "IIR lowpass orden 2", 2, FC_LP_TEMP, [])];
            case "F"
                plan.descripcion = sprintf('%s: presion con FIR notch ajustable + FIR lowpass.', plat);
                plan.etapas = [ ...
                    etapa("FIR", "notch", "FIR notch ajustable, orden por defecto 60", ORD_FIR_ESP_NOTCH_LP, 35, []), ...
                    etapa("FIR", "lowpass", "FIR lowpass fc=10 Hz, orden por defecto 60", ORD_FIR_ESP_NOTCH_LP, FC_PRESION_LP, [])];
            case "G"
                plan.descripcion = sprintf('%s: nivel ultrasonico con mediana + EMA.', plat);
                plan.etapas = [ ...
                    etapa("MEDIANA", "median", "Filtro de mediana para ecos espurios", 5, 0, []), ...
                    etapa("IIR", "lowpass", "EMA equivalente a IIR de primer orden", 1, FC_NIVEL_EMA, [])];
            case "H"
                plan.descripcion = sprintf('%s: banco FIR bandpass para armonicos.', plat);
                plan.etapas = [ ...
                    etapa("FIR", "bandpass", "FIR BP fundamental 50 Hz", ORD_FIR_BANCO_H, [45 55], []), ...
                    etapa("FIR", "bandpass", "FIR BP armonico 100 Hz", ORD_FIR_BANCO_H, [95 105], []), ...
                    etapa("FIR", "bandpass", "FIR BP armonico 150 Hz", ORD_FIR_BANCO_H, [140 160], [])];
                plan.fc_referencia = FC_ARMONICOS;
            case "I"
                plan.descripcion = sprintf('%s: FIR derivador + FIR lowpass.', plat);
                plan.etapas = [ ...
                    etapa("FIR", "derivative", "FIR derivador discreto, orden por defecto 60", ORD_FIR_DERIVADOR, 0, []), ...
                    etapa("FIR", "lowpass", "FIR lowpass fc=50 Hz, orden por defecto 60", ORD_FIR_DERIVADOR, FC_ENCODER_LP, [])];
            case "J"
                plan.descripcion = sprintf('%s: SpO2/CGM con FIR lowpass + IIR highpass.', plat);
                plan.etapas = [ ...
                    etapa("FIR", "lowpass", "FIR lowpass orden 200 fc=0.5 Hz", ORD_FIR_J, FC_CGM_LP, []), ...
                    etapa("IIR", "highpass", "IIR highpass orden 1 fc=0.01 Hz", 1, FC_CGM_HP, [])];
        end
end

if isempty(plan.etapas)
    error('tabla_arquitecturas:NoExiste', ...
        'No hay arquitectura hardcodeada para opcion %s y plataforma %s.', op, plataforma);
end

plan.resumen = resumenPlan(plan);
end

function plan = basePlan(op, plat)
plan = struct();
plan.etapas = [];
plan.confianzaBase = 90;
plan.descripcion = '';
plan.caso = char(op);
plan.plataforma_tabla = char(plat);
plan.advertencias = {};
plan.notas = {};
end

function p = normalizarPlataforma(plataforma)
p = upper(strtrim(string(plataforma)));
p = replace(p, " ", "");
switch p
    case {"ARDUINOUNO", "ARDUINO", "UNO"}
        p = "ARDUINO";
    case "ESP32"
        p = "ESP32";
    case {"STM32F4", "STM32"}
        p = "STM32F4";
    otherwise
        p = "";
end
end

function e = etapa(clase, respuesta, descripcion, orden, frecuencia, q)
e = struct('clase', char(clase), 'respuesta', char(respuesta), ...
    'descripcion', char(descripcion), 'orden', orden, ...
    'frecuencia', frecuencia, 'q', q, 'estructura', estructuraEtapa(clase));
end

function txt = estructuraEtapa(clase)
switch upper(string(clase))
    case "IIR"
        txt = 'SOS / Direct Form II transposed';
    case "FIR"
        txt = 'FIR directo con buffer circular';
    case "MEDIANA"
        txt = 'Filtro no lineal de mediana';
    otherwise
        txt = 'Etapa auxiliar';
end
end

function txt = resumenPlan(plan)
clases = strings(1, numel(plan.etapas));
for k = 1:numel(plan.etapas)
    clases(k) = string(plan.etapas(k).clase);
end
txt = strjoin(clases, " + ");
end
