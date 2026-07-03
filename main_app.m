function main_app()
%MAIN_APP Lanza el agente experto FIR/IIR para el TP de Tecnicas Digitales III.

app = struct();
app.filtro = [];
app.plan = [];
app.serial = [];
app.respFig = [];
app.stream = [];
app.reglasActuales = {};
app.confianzaActual = NaN;
app.edicion = struct();
app.edicionData = {};
app.editActual = 1;

app.fig = uifigure('Name', 'Agente experto FIR/IIR - UTN TDI III', ...
    'Position', [100 100 1180 720], ...
    'CloseRequestFcn', @cerrarApp);

root = uigridlayout(app.fig, [1 2]);
root.ColumnWidth = {390, '1x'};
root.RowHeight = {'1x'};
root.Padding = [12 12 12 12];
root.ColumnSpacing = 14;

left = uigridlayout(root, [22 2]);
left.Layout.Row = 1;
left.Layout.Column = 1;
left.RowHeight = repmat({28}, 1, 22);
left.ColumnWidth = {155, '1x'};
left.RowSpacing = 7;
left.Padding = [8 8 8 8];

titulo = uilabel(left, 'Text', 'Entrada del agente', 'FontSize', 16, 'FontWeight', 'bold');
titulo.Layout.Row = 1;
titulo.Layout.Column = [1 2];

uilabel(left, 'Text', 'Opcion del TP');
app.caso = uidropdown(left, ...
    'Items', {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'Personalizado'}, ...
    'Value', 'J', 'ValueChangedFcn', @actualizarCaso);

uilabel(left, 'Text', 'Tipo de senal');
app.tipoSenal = uidropdown(left, ...
    'Items', {'Medica / biomedica', 'Industrial lenta', 'Vibracion mecanica', ...
    'Audio / comunicaciones', 'Corriente electrica', 'Control / encoder', 'Personalizada'}, ...
    'Value', 'Medica / biomedica');

uilabel(left, 'Text', 'Plataforma/MCU');
app.ddMcu = uidropdown(left, ...
    'Items', {'ESP32', 'STM32F4', 'Arduino Uno', 'ATtiny85', 'Personalizado'}, ...
    'Value', 'ESP32', 'ValueChangedFcn', @actualizarMcu);

uilabel(left, 'Text', 'fs (Hz)');
app.fs = uieditfield(left, 'numeric', 'Value', 10, 'Limits', [0.1 Inf]);

uilabel(left, 'Text', 'RAM (kB)');
app.ram = uieditfield(left, 'numeric', 'Value', 320, 'Limits', [0 Inf]);

uilabel(left, 'Text', 'Flash (kB)');
app.flash = uieditfield(left, 'numeric', 'Value', 4096, 'Limits', [0 Inf]);

uilabel(left, 'Text', 'MIPS/MHz');
app.mips = uieditfield(left, 'numeric', 'Value', 240, 'Limits', [0 Inf]);

uilabel(left, 'Text', 'Fase lineal');
app.fase = uidropdown(left, 'Items', {'Si', 'No'}, 'Value', 'Si');

uilabel(left, 'Text', 'Nivel de ruido');
app.ruido = uidropdown(left, 'Items', {'Bajo', 'Medio', 'Alto'}, 'Value', 'Medio');

uilabel(left, 'Text', 'Latencia');
app.latencia = uidropdown(left, 'Items', {'Baja', 'Media', 'Alta'}, 'Value', 'Media');

uilabel(left, 'Text', 'Pendiente transicion');
app.pendiente = uidropdown(left, 'Items', {'Estrecha', 'Amplia'}, 'Value', 'Amplia');

app.btnCalc = uibutton(left, 'push', 'Text', 'Recomendar', ...
    'ButtonPushedFcn', @recomendar);
app.btnCalc.Layout.Row = 13;
app.btnCalc.Layout.Column = [1 2];

app.btnCrear = uibutton(left, 'push', 'Text', 'Crear filtro recomendado', ...
    'ButtonPushedFcn', @crearFiltro);
app.btnCrear.Layout.Row = 14;
app.btnCrear.Layout.Column = [1 2];

app.btnCopiar = uibutton(left, 'push', 'Text', 'Exportar informe', ...
    'ButtonPushedFcn', @exportarInforme);
app.btnCopiar.Layout.Row = 15;
app.btnCopiar.Layout.Column = [1 2];

serialTitle = uilabel(left, 'Text', 'Envio opcional al ESP32', 'FontWeight', 'bold');
serialTitle.Layout.Row = 17;
serialTitle.Layout.Column = [1 2];

uilabel(left, 'Text', 'Puerto COM');
app.puerto = uieditfield(left, 'text', 'Value', 'COM4');

uilabel(left, 'Text', 'Baudios');
app.baudios = uieditfield(left, 'numeric', 'Value', 115200, ...
    'Limits', [1 Inf], 'RoundFractionalValues', 'on', ...
    'ValueDisplayFormat', '%.0f');

app.btnSerial = uibutton(left, 'push', 'Text', 'Conectar al microcontrolador', ...
    'ButtonPushedFcn', @enviarEsp32);
app.btnSerial.Layout.Row = 20;
app.btnSerial.Layout.Column = [1 2];

app.lblSerial = uilabel(left, 'Text', 'Sin conexión', 'FontColor', [0.45 0.45 0.45]);
app.lblSerial.Layout.Row = 21;
app.lblSerial.Layout.Column = [1 2];
app.lblSerial.WordWrap = 'on';

right = uigridlayout(root, [11 1]);
right.Layout.Row = 1;
right.Layout.Column = 2;
right.RowHeight = {42, 44, 28, 105, 150, 28, 96, 26, '1x', 40, 28};
right.Padding = [8 8 8 8];
right.RowSpacing = 8;

app.lblTipo = uilabel(right, 'Text', 'Resultado: -', ...
    'FontSize', 24, 'FontWeight', 'bold');
app.lblDescripcion = uilabel(right, 'Text', 'Caso: -', 'FontSize', 14);
app.lblConfianza = uilabel(right, 'Text', 'Confianza: -', ...
    'FontSize', 14, 'FontWeight', 'bold');

app.reglas = uilistbox(right, 'Items', {'Ejecute el calculo para ver reglas activadas'});
app.etapas = uitextarea(right, 'Editable', 'off', 'Value', {'Etapas recomendadas: -'});

app.lblEdicion = uilabel(right, 'Text', 'Ajustes antes de crear', ...
    'FontSize', 14, 'FontWeight', 'bold');
app.editor = uigridlayout(right, [2 5]);
app.editor.RowHeight = {24, 36};
app.editor.ColumnWidth = {105, 105, 130, 90, '1x'};
app.editor.RowSpacing = 6;
app.editor.ColumnSpacing = 8;
app.editor.Padding = [0 4 0 4];

editorLabels = {'Etapa', 'Tipo', 'Respuesta', 'Orden', 'Frecuencia Hz'};
for c = 1:numel(editorLabels)
    lbl = uilabel(app.editor, 'Text', editorLabels{c}, 'FontWeight', 'bold');
    lbl.Layout.Row = 1;
    lbl.Layout.Column = c;
end

app.edicion.etapa = uidropdown(app.editor, 'Items', {'-'}, ...
    'ValueChangedFcn', @cambiarEtapaEditor);
app.edicion.etapa.Layout.Row = 2;
app.edicion.etapa.Layout.Column = 1;

app.edicion.tipo = uidropdown(app.editor, 'Items', {'FIR', 'IIR', 'MEDIANA'});
app.edicion.tipo.Layout.Row = 2;
app.edicion.tipo.Layout.Column = 2;

app.edicion.respuesta = uidropdown(app.editor, ...
    'Items', {'lowpass', 'highpass', 'bandpass', 'notch', 'median', 'derivative'});
app.edicion.respuesta.Layout.Row = 2;
app.edicion.respuesta.Layout.Column = 3;

app.edicion.orden = uieditfield(app.editor, 'numeric', ...
    'Limits', [1 1200], 'RoundFractionalValues', 'on', ...
    'ValueDisplayFormat', '%.0f');
app.edicion.orden.Layout.Row = 2;
app.edicion.orden.Layout.Column = 4;

app.edicion.frecuencia = uieditfield(app.editor, 'text');
app.edicion.frecuencia.Layout.Row = 2;
app.edicion.frecuencia.Layout.Column = 5;

app.lblCoef = uilabel(right, 'Text', 'Coeficientes exportables', ...
    'FontSize', 14, 'FontWeight', 'bold');
app.coefs = uitextarea(right, 'Editable', 'off', 'Value', {'-'});

app.nota = uilabel(right, 'Text', ...
    'Nota: primero recomienda y justifica; luego ajuste y cree el filtro. Use "Conectar al microcontrolador" para enviar y graficar en vivo.', ...
    'FontColor', [0.35 0.35 0.35]);

actualizarMcu();
actualizarCaso();

    function actualizarMcu(~, ~)
        switch app.ddMcu.Value
            case 'ESP32'
                valores = [320, 4096, 240];
            case 'STM32F4'
                valores = [192, 1024, 168];
            case 'Arduino Uno'
                valores = [2, 32, 16];
            case 'ATtiny85'
                valores = [0.5, 8, 8];
            otherwise
                return;
        end
        app.ram.Value = valores(1);
        app.flash.Value = valores(2);
        app.mips.Value = valores(3);
    end

    function actualizarCaso(~, ~)
        switch app.caso.Value
            case 'A'
                app.fs.Value = 500;
                app.tipoSenal.Value = 'Medica / biomedica';
                app.fase.Value = 'Si';
                app.pendiente.Value = 'Estrecha';
            case 'B'
                app.fs.Value = 1000;
                app.tipoSenal.Value = 'Vibracion mecanica';
                app.fase.Value = 'No';
            case 'C'
                app.fs.Value = 125;
                app.tipoSenal.Value = 'Medica / biomedica';
                app.fase.Value = 'Si';
            case 'D'
                app.fs.Value = 1000;
                app.tipoSenal.Value = 'Medica / biomedica';
                app.fase.Value = 'No';
            case 'E'
                app.fs.Value = 50;
                app.tipoSenal.Value = 'Industrial lenta';
                app.fase.Value = 'No';
            case 'F'
                app.fs.Value = 500;
                app.tipoSenal.Value = 'Industrial lenta';
                app.fase.Value = 'No';
            case 'G'
                app.fs.Value = 100;
                app.tipoSenal.Value = 'Industrial lenta';
                app.fase.Value = 'No';
            case 'H'
                app.fs.Value = 2000;
                app.tipoSenal.Value = 'Corriente electrica';
                app.fase.Value = 'No';
            case 'I'
                app.fs.Value = 1000;
                app.tipoSenal.Value = 'Control / encoder';
                app.fase.Value = 'No';
            case 'J'
                app.fs.Value = 10;
                app.tipoSenal.Value = 'Medica / biomedica';
                app.fase.Value = 'Si';
                app.latencia.Value = 'Media';
                app.pendiente.Value = 'Amplia';
        end
    end

    function recomendar(~, ~)
        faseLineal = strcmp(app.fase.Value, 'Si');
        [tipo, estructura, reglas, confianza, app.plan] = recomendar_filtro( ...
            app.fs.Value, app.ram.Value, app.flash.Value, app.mips.Value, ...
            faseLineal, app.ruido.Value, app.latencia.Value, app.pendiente.Value, ...
            app.caso.Value, app.tipoSenal.Value, app.ddMcu.Value);

        app.filtro = [];
        app.lblTipo.Text = sprintf('Resultado: %s', char(tipo));
        app.lblDescripcion.Text = sprintf('%s | %s', app.plan.descripcion, char(estructura));
        app.lblConfianza.Text = sprintf('Confianza: %.1f %%', confianza);
        app.reglas.Items = reglas;
        app.etapas.Value = describirPlan(app.plan);
        app.coefs.Value = {'Ajuste los valores y presione "Crear filtro recomendado".'};
        app.reglasActuales = reglas;
        app.confianzaActual = confianza;
        cargarEditorPlan();
        if ~isempty(app.respFig) && isvalid(app.respFig)
            delete(app.respFig);
        end
    end

    function crearFiltro(~, ~)
        if isempty(app.plan)
            recomendar();
        end
        app.plan = planDesdeEditor(app.plan);
        app.fs.Value = app.plan.fs;
        app.filtro = disenar_filtro(char(app.plan.resumen), app.plan.fs, app.plan);
        app.etapas.Value = describirEtapas(app.plan, app.filtro);
        app.coefs.Value = resumenCoeficientes(app.filtro);
        abrirRespuestaFrecuencia();
    end

    function cargarEditorPlan()
        app.edicionData = cell(numel(app.plan.etapas), 5);
        items = cell(1, numel(app.plan.etapas));
        for k = 1:numel(app.plan.etapas)
            e = app.plan.etapas(k);
            items{k} = sprintf('Etapa %d/%d - %s %s', ...
                k, numel(app.plan.etapas), e.clase, upper(e.respuesta));
            app.edicionData{k, 1} = items{k};
            app.edicionData{k, 2} = e.clase;
            app.edicionData{k, 3} = e.respuesta;
            app.edicionData{k, 4} = e.orden;
            app.edicionData{k, 5} = mat2str(e.frecuencia);
        end
        app.editActual = 1;
        app.edicion.etapa.Items = items;
        if ~isempty(items)
            app.edicion.etapa.Value = items{1};
            cargarEditorEtapa(1);
        end
    end

    function cambiarEtapaEditor(~, ~)
        guardarEditorActual();
        idx = find(strcmp(app.edicion.etapa.Items, app.edicion.etapa.Value), 1, 'first');
        if isempty(idx)
            idx = 1;
        end
        app.editActual = idx;
        cargarEditorEtapa(idx);
    end

    function guardarEditorActual()
        if isempty(app.edicionData)
            return;
        end
        k = app.editActual;
        app.edicionData{k, 2} = app.edicion.tipo.Value;
        app.edicionData{k, 3} = app.edicion.respuesta.Value;
        app.edicionData{k, 4} = round(app.edicion.orden.Value);
        app.edicionData{k, 5} = app.edicion.frecuencia.Value;
    end

    function cargarEditorEtapa(k)
        if isempty(app.edicionData)
            return;
        end
        app.edicion.tipo.Value = app.edicionData{k, 2};
        app.edicion.respuesta.Value = app.edicionData{k, 3};
        app.edicion.orden.Value = app.edicionData{k, 4};
        app.edicion.frecuencia.Value = app.edicionData{k, 5};
    end

    function plan = planDesdeEditor(plan)
        guardarEditorActual();
        plan.fs = app.fs.Value;
        for k = 1:min(numel(plan.etapas), size(app.edicionData, 1))
            plan.etapas(k).clase = char(app.edicionData{k, 2});
            plan.etapas(k).respuesta = char(app.edicionData{k, 3});
            plan.etapas(k).orden = round(app.edicionData{k, 4});
            plan.etapas(k).frecuencia = str2num(char(app.edicionData{k, 5})); %#ok<ST2NM>
            if isempty(plan.etapas(k).frecuencia)
                plan.etapas(k).frecuencia = 0.2 * plan.fs;
            end
            if strcmp(plan.etapas(k).clase, 'IIR')
                plan.etapas(k).estructura = 'SOS / Direct Form II transposed';
            elseif strcmp(plan.etapas(k).clase, 'FIR')
                plan.etapas(k).estructura = 'FIR directo con buffer circular';
            end
        end
        plan.resumen = resumenPlanLocal(plan);
    end

    function abrirRespuestaFrecuencia()
        if ~isempty(app.respFig) && isvalid(app.respFig)
            delete(app.respFig);
        end
        [fp, fr, Rp, As] = especificacionesGrafica(app.filtro);
        app.respFig = mostrar_respuesta(app.filtro, fp, fr, Rp, As);
    end

    function exportarInforme(~, ~)
        if isempty(app.filtro)
            crearFiltro();
        end
        nombreDefault = sprintf('informe_filtros_opcion_%s.txt', lower(app.caso.Value));
        [archivo, carpeta] = uiputfile({'*.txt', 'Informe de texto (*.txt)'}, ...
            'Guardar informe del agente', nombreDefault);
        if isequal(archivo, 0)
            return;
        end
        ruta = fullfile(carpeta, archivo);
        entradas = entradasActuales();
        exportar_informe(app.filtro, app.plan, app.reglasActuales, ...
            app.confianzaActual, entradas, ruta);
        app.coefs.Value = {sprintf('Informe exportado en:'), ruta};
    end

    function enviarEsp32(~, ~)
        try
            cerrarStreamActual();
            cerrarSerialActual();

            puerto = strtrim(app.puerto.Value);
            baudios = round(app.baudios.Value);
            app.serial = serialport(puerto, baudios, 'Timeout', 3);

            % Esperar reinicio del ESP32 (DTR/RTS toggle) y limpiar buffer.
            app.lblSerial.Text = sprintf('Conectando a %s...', puerto);
            drawnow;
            pause(2.0);
            flush(app.serial);

            % Abrir directamente la ventana de monitoreo en vivo.
            app.lblSerial.Text = sprintf('Conectado a %s - monitoreo en vivo abierto.', puerto);
            drawnow;
            fcFIR = 0.5;
            fcIIR = 0.01;
            if ~isempty(app.filtro)
                [fcFIR, fcIIR] = frecuenciasStreaming(app.filtro);
            end
            app.stream = stream_esp32(app.serial, 200, app.fs.Value, fcFIR, fcIIR);

        catch err
            cerrarSerialActual();
            pause(0.2);
            disponibles = serialportlist('available');
            if isempty(disponibles)
                todos = serialportlist('all');
                if isempty(todos)
                    lista = 'ninguno';
                else
                    lista = sprintf('ninguno disponible; detectados: %s', strjoin(cellstr(todos), ', '));
                end
            else
                lista = strjoin(cellstr(disponibles), ', ');
            end
            app.lblSerial.Text = sprintf('Error serial: %s | Puertos disponibles: %s', ...
                limpiarMensaje(err.message), lista);
        end
    end

    function cerrarSerialActual()
        if ~isempty(app.serial) && isvalid(app.serial)
            try
                configureCallback(app.serial, 'off');
            catch
            end
            try
                flush(app.serial);
            catch
            end
            app.serial = [];
        end
    end

    function cerrarStreamActual()
        if isstruct(app.stream) && isfield(app.stream, 'figure') && ...
                ~isempty(app.stream.figure) && isvalid(app.stream.figure)
            delete(app.stream.figure);
        end
        app.stream = [];
    end

    function entradas = entradasActuales()
        entradas = struct();
        entradas.opcion_tp = app.caso.Value;
        entradas.tipo_senal = app.tipoSenal.Value;
        entradas.mcu = app.ddMcu.Value;
        entradas.fs_hz = app.fs.Value;
        entradas.ram_kb = app.ram.Value;
        entradas.flash_kb = app.flash.Value;
        entradas.mips_mhz = app.mips.Value;
        entradas.fase_lineal = app.fase.Value;
        entradas.nivel_ruido = app.ruido.Value;
        entradas.latencia = app.latencia.Value;
        entradas.pendiente = app.pendiente.Value;
    end

    function cerrarApp(~, ~)
        cerrarStreamActual();
        cerrarSerialActual();
        if ~isempty(app.respFig) && isvalid(app.respFig)
            delete(app.respFig);
        end
        delete(app.fig);
    end
end

function lineas = describirEtapas(plan, filtro)
lineas = cell(1, numel(plan.etapas));
for k = 1:numel(plan.etapas)
    e = plan.etapas(k);
    f = filtro.etapas(k);
    if strcmp(e.clase, 'FIR')
        detalle = sprintf('%d coeficientes b[n]. Metodo: %s', numel(f.b), f.metodo);
    elseif strcmp(e.clase, 'IIR')
        detalle = sprintf('%d secciones SOS. Prototipo: %s', size(f.sos, 1), f.prototipo);
    else
        detalle = sprintf('Etapa auxiliar: %s', f.metodo);
    end
    lineas{k} = sprintf('%d) %s %s, orden %d, f=%s Hz. %s. %s', ...
        k, e.clase, upper(e.respuesta), e.orden, mat2str(e.frecuencia), ...
        e.descripcion, detalle);
end
end

function lineas = describirPlan(plan)
lineas = cell(1, numel(plan.etapas));
for k = 1:numel(plan.etapas)
    e = plan.etapas(k);
    if strcmp(e.clase, 'FIR')
        metodo = 'Metodo propuesto: ventana Hamming; orden maximo sugerido: 80.';
    elseif strcmp(e.clase, 'IIR')
        metodo = 'Metodo propuesto: Butterworth/notch en SOS para estabilidad numerica.';
    else
        metodo = 'Etapa auxiliar indicada por tabla; no se exporta como FIR/IIR.';
    end
    lineas{k} = sprintf('%d) %s %s, orden %d, f=%s Hz. %s. %s', ...
        k, e.clase, upper(e.respuesta), e.orden, mat2str(e.frecuencia), ...
        e.descripcion, metodo);
end
end

function txt = resumenPlanLocal(plan)
clases = strings(1, numel(plan.etapas));
for k = 1:numel(plan.etapas)
    clases(k) = string(plan.etapas(k).clase);
end
txt = strjoin(clases, " + ");
end

function lineas = resumenCoeficientes(filtro)
lineas = {};
for k = 1:numel(filtro.etapas)
    e = filtro.etapas(k);
    lineas{end + 1} = sprintf('Etapa %d - %s %s', k, e.clase, upper(e.respuesta)); %#ok<AGROW>
    if strcmp(e.clase, 'FIR')
        lineas{end + 1} = sprintf('metodo = %s', e.metodo); %#ok<AGROW>
        lineas{end + 1} = sprintf('b = %s', mat2str(e.b, 6)); %#ok<AGROW>
    elseif strcmp(e.clase, 'IIR')
        lineas{end + 1} = sprintf('prototipo = %s', e.prototipo); %#ok<AGROW>
        lineas{end + 1} = sprintf('sos = %s', mat2str(e.sos, 6)); %#ok<AGROW>
    else
        lineas{end + 1} = sprintf('metodo = %s', e.metodo); %#ok<AGROW>
        lineas{end + 1} = 'coeficientes = etapa auxiliar sin paquete FIR/IIR'; %#ok<AGROW>
    end
    lineas{end + 1} = ''; %#ok<AGROW>
end
end

function [fp, fr, Rp, As] = especificacionesGrafica(filtro)
Rp = 1;
As = 40;
fp = cell(1, numel(filtro.etapas));
fr = cell(1, numel(filtro.etapas));
for k = 1:numel(filtro.etapas)
    e = filtro.etapas(k);
    freq = e.frecuencia;
    switch lower(e.respuesta)
        case 'lowpass'
            fp{k} = 0.85 * freq(1);
            fr{k} = min(1.25 * freq(1), 0.98 * filtro.fs / 2);
        case 'highpass'
            fp{k} = min(1.25 * freq(1), 0.98 * filtro.fs / 2);
            fr{k} = 0.85 * freq(1);
        case 'bandpass'
            fp{k} = freq;
            ancho = max(diff(freq), filtro.fs * 0.02);
            fr{k} = [max(freq(1) - 0.25 * ancho, 0), min(freq(2) + 0.25 * ancho, 0.98 * filtro.fs / 2)];
        case 'notch'
            fp{k} = freq(1);
            fr{k} = freq(1);
        otherwise
            fp{k} = freq(1);
            fr{k} = freq(1);
    end
end
end

function msg = limpiarMensaje(msg)
msg = regexprep(char(msg), '<[^>]*>', '');
msg = strrep(msg, newline, ' ');
msg = strtrim(msg);
end

function [fcFIR, fcIIR] = frecuenciasStreaming(filtro)
fcFIR = 0.5;
fcIIR = 0.01;
for k = 1:numel(filtro.etapas)
    e = filtro.etapas(k);
    if strcmp(e.clase, 'FIR') && strcmp(e.respuesta, 'lowpass')
        fcFIR = e.frecuencia(1);
    elseif strcmp(e.clase, 'IIR') && strcmp(e.respuesta, 'highpass')
        fcIIR = e.frecuencia(1);
    end
end
end
