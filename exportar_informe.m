function ruta = exportar_informe(filtro, plan, reglas, confianza, entradas, ruta)
%EXPORTAR_INFORME Escribe un informe de la recomendacion y coeficientes.
%
% ruta = exportar_informe(filtro, plan, reglas, confianza, entradas, ruta)
% genera un archivo de texto plano con las etapas disenadas, estructuras,
% ordenes y coeficientes. No depende de variables globales ni de la GUI.

arguments
    filtro struct
    plan struct
    reglas cell
    confianza (1, 1) double
    entradas struct
    ruta {mustBeTextScalar}
end

ruta = char(ruta);
fid = fopen(ruta, 'w');
if fid < 0
    error('exportar_informe:NoSePuedeAbrir', 'No se pudo abrir el archivo de salida.');
end

limpiador = onCleanup(@() fclose(fid));

fprintf(fid, 'INFORME DEL AGENTE FIR/IIR\n');
fprintf(fid, 'Tecnicas Digitales III - UTN\n');
fprintf(fid, 'Generado: %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
fprintf(fid, '\n');

fprintf(fid, '1. ENTRADAS DEL AGENTE\n');
fprintf(fid, 'Opcion del TP: %s\n', campo(entradas, 'opcion_tp'));
fprintf(fid, 'Tipo de senal: %s\n', campo(entradas, 'tipo_senal'));
fprintf(fid, 'Plataforma/MCU: %s\n', campo(entradas, 'mcu'));
fprintf(fid, 'fs: %.6g Hz\n', valor(entradas, 'fs_hz'));
fprintf(fid, 'RAM: %.6g kB\n', valor(entradas, 'ram_kb'));
fprintf(fid, 'Flash: %.6g kB\n', valor(entradas, 'flash_kb'));
fprintf(fid, 'MIPS/MHz: %.6g\n', valor(entradas, 'mips_mhz'));
fprintf(fid, 'Fase lineal requerida: %s\n', campo(entradas, 'fase_lineal'));
fprintf(fid, 'Nivel de ruido: %s\n', campo(entradas, 'nivel_ruido'));
fprintf(fid, 'Latencia: %s\n', campo(entradas, 'latencia'));
fprintf(fid, 'Pendiente de transicion: %s\n', campo(entradas, 'pendiente'));
fprintf(fid, '\n');

fprintf(fid, '2. RECOMENDACION\n');
fprintf(fid, 'Caso: %s\n', plan.descripcion);
fprintf(fid, 'Cadena recomendada: %s\n', filtro.tipo);
fprintf(fid, 'Confianza: %.1f %%\n', confianza);
fprintf(fid, 'Frecuencia de muestreo usada para diseno: %.6g Hz\n', filtro.fs);
fprintf(fid, '\n');

fprintf(fid, '3. REGLAS ACTIVADAS\n');
for k = 1:numel(reglas)
    fprintf(fid, '- %s\n', reglas{k});
end
fprintf(fid, '\n');

fprintf(fid, '4. ETAPAS, ESTRUCTURAS Y COEFICIENTES\n');
for k = 1:numel(filtro.etapas)
    e = filtro.etapas(k);
    fprintf(fid, '\n');
    fprintf(fid, 'Etapa %d\n', k);
    fprintf(fid, 'Tipo: %s\n', e.clase);
    fprintf(fid, 'Respuesta: %s\n', nombreRespuesta(e.respuesta));
    fprintf(fid, 'Descripcion: %s\n', e.descripcion);
    fprintf(fid, 'Estructura sugerida: %s\n', e.estructura);
    fprintf(fid, 'Orden: %d\n', e.orden);
    fprintf(fid, 'Frecuencia(s) caracteristica(s): %s Hz\n', mat2str(e.frecuencia, 10));

    if strcmp(e.clase, 'FIR')
        fprintf(fid, 'Metodo de diseno FIR: %s.\n', e.metodo);
        fprintf(fid, 'Cantidad de coeficientes b[n]: %d\n', numel(e.b));
        fprintf(fid, 'Implementacion sugerida: convolucion FIR directa con buffer circular.\n');
        fprintf(fid, 'Justificacion: ventana Hamming por buen compromiso entre simplicidad, atenuacion lateral y costo bajo en MCU.\n');
        fprintf(fid, 'Ecuacion: y[n] = sum_{k=0}^{N} b[k] x[n-k]\n');
        fprintf(fid, 'Coeficientes b[n]:\n');
        escribirVector(fid, e.b);
    else
        fprintf(fid, 'Metodo/prototipo IIR: %s.\n', e.prototipo);
        fprintf(fid, 'Cantidad de secciones SOS: %d\n', size(e.sos, 1));
        fprintf(fid, 'Implementacion sugerida: cascada de biquads SOS, preferentemente Direct Form II transposed.\n');
        fprintf(fid, 'Formato SOS por fila: [b0 b1 b2 a0 a1 a2]\n');
        fprintf(fid, 'Cada seccion cumple: y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2], con a0 normalizado.\n');
        fprintf(fid, 'Matriz SOS:\n');
        escribirMatriz(fid, e.sos);
    end
end

fprintf(fid, '\n');
fprintf(fid, '5. NOTAS DE IMPLEMENTACION\n');
fprintf(fid, '- Para ESP32/STM32 puede usarse float32 para coeficientes y estados.\n');
fprintf(fid, '- Para Arduino UNO conviene revisar memoria, usar pocas etapas IIR SOS y evitar FIR largos.\n');
fprintf(fid, '- En IIR no implementar orden alto como forma directa unica; usar SOS/biquads para estabilidad numerica.\n');
fprintf(fid, '- Validar siempre la respuesta en frecuencia y la senal filtrada antes de cargar al microcontrolador.\n');
end

function escribirVector(fid, v)
for k = 1:numel(v)
    fprintf(fid, 'b[%03d] = %.12g\n', k - 1, v(k));
end
end

function escribirMatriz(fid, m)
for r = 1:size(m, 1)
    fprintf(fid, 'SOS[%02d] = ', r);
    fprintf(fid, '[ ');
    fprintf(fid, '%.12g ', m(r, :));
    fprintf(fid, ']\n');
end
end

function txt = nombreRespuesta(respuesta)
switch lower(string(respuesta))
    case "lowpass"
        txt = 'Pasa bajos';
    case "highpass"
        txt = 'Pasa altos';
    case "bandpass"
        txt = 'Pasa banda';
    case "notch"
        txt = 'Notch / rechazo estrecho';
    otherwise
        txt = char(respuesta);
end
end

function txt = campo(s, nombre)
if isfield(s, nombre)
    txt = char(string(s.(nombre)));
else
    txt = '-';
end
end

function x = valor(s, nombre)
if isfield(s, nombre)
    x = s.(nombre);
else
    x = NaN;
end
end
