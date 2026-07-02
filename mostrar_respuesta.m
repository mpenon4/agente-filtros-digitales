function fig = mostrar_respuesta(filtro, fp, fr, Rp, As)
%MOSTRAR_RESPUESTA Abre una ventana uifigure con magnitud y fase.
%
% fig = mostrar_respuesta(filtro, fp, fr, Rp, As) grafica las respuestas en
% frecuencia usando exclusivamente los coeficientes ya presentes en filtro.

if nargin < 2 || isempty(fp)
    fp = cell(1, numel(filtro.etapas));
end
if nargin < 3 || isempty(fr)
    fr = cell(1, numel(filtro.etapas));
end
if nargin < 4 || isempty(Rp)
    Rp = 1;
end
if nargin < 5 || isempty(As)
    As = 40;
end

numEtapas = numel(filtro.etapas);
if numEtapas == 1
    figTitle = sprintf('Respuesta en Frecuencia - %s', nombreEtapa(filtro.etapas(1)));
    fig = uifigure('Name', figTitle, 'Position', [180 120 850 650]);
    grid = uigridlayout(fig, [3 1]);
    grid.RowHeight = {'1x', '1x', 36};
    grid.Padding = [12 12 12 12];
    grid.RowSpacing = 10;

    axMag = uiaxes(grid);
    axMag.Layout.Row = 1;
    axFase = uiaxes(grid);
    axFase.Layout.Row = 2;
    graficarEtapa(axMag, axFase, filtro.etapas(1), filtro.fs, 1, obtener(fp, 1), obtener(fr, 1), Rp, As);
elseif numEtapas == 2
    fig = uifigure('Name', sprintf('Respuesta en Frecuencia - %s', filtro.tipo), ...
        'Position', [140 100 1100 650]);
    grid = uigridlayout(fig, [3 2]);
    grid.RowHeight = {'1x', '1x', 36};
    grid.ColumnWidth = {'1x', '1x'};
    grid.Padding = [12 12 12 12];
    grid.RowSpacing = 10;
    grid.ColumnSpacing = 12;

    for k = 1:2
        axMag = uiaxes(grid);
        axMag.Layout.Row = 1;
        axMag.Layout.Column = k;
        axFase = uiaxes(grid);
        axFase.Layout.Row = 2;
        axFase.Layout.Column = k;
        graficarEtapa(axMag, axFase, filtro.etapas(k), filtro.fs, k, obtener(fp, k), obtener(fr, k), Rp, As);
    end
else
    filasGraficas = min(2, numEtapas);
    colsGraficas = ceil(numEtapas / filasGraficas);
    fig = uifigure('Name', sprintf('Respuesta en Frecuencia - %s', filtro.tipo), ...
        'Position', [140 80 1100 720]);
    grid = uigridlayout(fig, [2 * filasGraficas + 1, colsGraficas]);
    grid.RowHeight = repmat({'1x'}, 1, 2 * filasGraficas + 1);
    grid.RowHeight{end} = 36;
    grid.ColumnWidth = repmat({'1x'}, 1, colsGraficas);
    grid.Padding = [12 12 12 12];
    grid.RowSpacing = 10;
    grid.ColumnSpacing = 12;

    for k = 1:numEtapas
        col = ceil(k / filasGraficas);
        bloque = mod(k - 1, filasGraficas);
        axMag = uiaxes(grid);
        axMag.Layout.Row = 2 * bloque + 1;
        axMag.Layout.Column = col;
        axFase = uiaxes(grid);
        axFase.Layout.Row = 2 * bloque + 2;
        axFase.Layout.Column = col;
        graficarEtapa(axMag, axFase, filtro.etapas(k), filtro.fs, k, obtener(fp, k), obtener(fr, k), Rp, As);
    end
end

btn = uibutton(grid, 'push', 'Text', 'Cerrar', 'ButtonPushedFcn', @(~, ~) delete(fig));
btn.Layout.Row = numel(grid.RowHeight);
numColumnas = numel(grid.ColumnWidth);
if numColumnas == 1
    btn.Layout.Column = 1;
else
    btn.Layout.Column = [1 numColumnas];
end
end

function graficarEtapa(axMag, axFase, etapa, fs, idx, fp, fr, Rp, As)
n = 2048;
if strcmp(etapa.clase, 'FIR')
    [h, f] = freqz(etapa.b, 1, n, fs);
    color = [0 0.35 0.80];
elseif strcmp(etapa.clase, 'IIR')
    [h, f] = respuestaSOS(etapa.sos, n, fs);
    color = [0.82 0.12 0.12];
else
    f = linspace(0, fs / 2, n).';
    h = ones(n, 1);
    color = [0.45 0.45 0.45];
end

magDb = 20 * log10(abs(h) + eps);
faseDeg = unwrap(angle(h)) * 180 / pi;
titulo = sprintf('Etapa %d - %s', idx, nombreEtapa(etapa));

plot(axMag, f, magDb, 'Color', color, 'LineWidth', 1.35);
title(axMag, [titulo ' - Magnitud']);
xlabel(axMag, 'Frecuencia (Hz)');
ylabel(axMag, 'Magnitud (dB)');
xlim(axMag, [0 fs / 2]);
grid(axMag, 'on');
marcarEspecificaciones(axMag, fp, fr, Rp, As);

plot(axFase, f, faseDeg, 'Color', color, 'LineWidth', 1.35);
title(axFase, [titulo ' - Fase']);
xlabel(axFase, 'Frecuencia (Hz)');
ylabel(axFase, 'Fase (grados)');
xlim(axFase, [0 fs / 2]);
grid(axFase, 'on');
marcarFrecuencias(axFase, fp, fr);
end

function [h, f] = respuestaSOS(sosMatrix, n, fs)
h = ones(n, 1);
f = [];
for k = 1:size(sosMatrix, 1)
    b = sosMatrix(k, 1:3);
    a = sosMatrix(k, 4:6);
    [hk, f] = freqz(b, a, n, fs);
    h = h .* hk;
end
end

function marcarEspecificaciones(ax, fp, fr, Rp, As)
marcarFrecuencias(ax, fp, fr);
yline(ax, -abs(Rp), ':', sprintf('Rp %.1f dB', abs(Rp)), 'Color', [0.25 0.55 0.25]);
yline(ax, -abs(As), ':', sprintf('As %.1f dB', abs(As)), 'Color', [0.35 0.35 0.35]);
end

function marcarFrecuencias(ax, fp, fr)
for f = valoresFrecuencia(fp)
    xline(ax, f, ':', sprintf('fp %.3g Hz', f), 'Color', [0.20 0.55 0.20]);
end
for f = valoresFrecuencia(fr)
    xline(ax, f, ':', sprintf('fr %.3g Hz', f), 'Color', [0.45 0.45 0.45]);
end
end

function valores = valoresFrecuencia(x)
if isempty(x)
    valores = [];
elseif iscell(x)
    valores = valoresFrecuencia(x{1});
else
    valores = x(:).';
    valores = valores(isfinite(valores) & valores >= 0);
end
end

function x = obtener(c, idx)
if iscell(c)
    if numel(c) >= idx
        x = c{idx};
    else
        x = [];
    end
else
    x = c;
end
end

function nombre = nombreEtapa(etapa)
switch lower(etapa.respuesta)
    case 'lowpass'
        resp = 'Pasa Bajos';
    case 'highpass'
        resp = 'Pasa Altos';
    case 'bandpass'
        resp = 'Pasa Banda';
    case 'notch'
        resp = 'Notch';
    otherwise
        resp = etapa.respuesta;
end
nombre = sprintf('%s %s', etapa.clase, resp);
end
