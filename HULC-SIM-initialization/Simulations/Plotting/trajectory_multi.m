addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

R_moon = 1737.4;
sailScale = 0.06 * R_moon;
busHalf = 0.012 * R_moon;
arrowLen = 0.15 * R_moon;
simDuration = 8;
fps = 60;
numFrames = simDuration * fps;
nRing = 90;
rowsPerCol = 7;

if ~exist('dataFiles', 'var')
    dataDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data');
    listing = dir(fullfile(dataDir, '*.mat'));
    dataFiles = fullfile({listing.folder}, {listing.name});
end

sats = struct('name', {}, 'tout', {}, 'pos', {}, 'vel', {}, 'thrust', {}, 'hasSail', {}, 'att', {}, 'soi', {});
nSat = 0;
for f = 1:numel(dataFiles)
    S = load(dataFiles{f});
    if ~isfield(S, 'position_icrf')
        continue
    end

    p = struct();
    if isfield(S, 'orbit_params')
        p = S.orbit_params;
    end
    [~, fileName] = fileparts(dataFiles{f});

    nSat = nSat + 1;
    sats(nSat).name = getp(p, 'name', fileName);
    sats(nSat).tout = S.tout(:);
    sats(nSat).pos = S.position_icrf / 1e3;
    sats(nSat).vel = S.velocity_icrf / 1e3;
    if isfield(S, 'thrust_icrf')
        sats(nSat).thrust = S.thrust_icrf;
    else
        sats(nSat).thrust = zeros(size(S.position_icrf));
    end
    sats(nSat).hasSail = logical(getp(p, 'has_sail', false));
    sats(nSat).att = prepareAttitude(p, sats(nSat).tout, sats(nSat).pos, sats(nSat).vel);
    sats(nSat).soi = max(getp(p, 'soi_radius_km', 300), 0);
end

if nSat == 0
    error('trajectory_multi:noData', 'No satellite .mat files found');
end

tEnd = min(arrayfun(@(q) q.tout(end), sats));
T = linspace(0, tEnd, numFrames)';

posI = cell(nSat, 1);
velI = cell(nSat, 1);
thrI = cell(nSat, 1);
for s = 1:nSat
    posI{s} = interp1(sats(s).tout, sats(s).pos, T, 'pchip');
    velI{s} = interp1(sats(s).tout, sats(s).vel, T, 'pchip');
    thrI{s} = interp1(sats(s).tout, sats(s).thrust, T, 'linear');
end

maxR = max(arrayfun(@(q) max(vecnorm(q.pos, 2, 2)), sats));
lim = 1.6 * maxR;
soi = [sats.soi];

cols = hsv2rgb([(0:nSat-1)' / nSat, 0.7 * ones(nSat, 1), ones(nSat, 1)]);

fig = figure('Color', 'k', 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
ax = axes('Parent', fig, 'Color', 'k');
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, [-lim lim -lim lim -lim lim]);
axis(ax, 'vis3d');
axis(ax, 'off');
view(ax, [35 20]);
set(ax, 'Projection', 'perspective', 'CLim', [0 1]);
colormap(ax, gray(256));

starDir = randn(2500, 3);
starDir = starDir ./ vecnorm(starDir, 2, 2);
plot3(ax, 3 * lim * starDir(:, 1), 3 * lim * starDir(:, 2), 3 * lim * starDir(:, 3), ...
    '.', 'Color', [1 1 1], 'MarkerSize', 2, 'Clipping', 'off');

[sx, sy, sz] = sphere(160);
theta = atan2(sy, sx);
phi = asin(sz);
noise = zeros(size(sx));
for k = 1:12
    noise = noise + sin(3 * k * theta + 2.3 * k * phi + k^2) / k;
end
noise = noise + 0.4 * sin(17 * theta) .* sin(23 * phi);
C = 0.5 + 0.28 * noise / max(abs(noise(:)));

surf(ax, R_moon * sx, R_moon * sy, R_moon * sz, C, ...
    'FaceColor', 'interp', 'EdgeColor', 'none', ...
    'AmbientStrength', 0.12, 'DiffuseStrength', 0.9, 'SpecularStrength', 0);

light(ax, 'Position', [1 0.4 0.6], 'Style', 'infinite');
lighting(ax, 'gouraud');

L = sailScale;
b = busHalf;
busV = b * [-1 -1 -1; 1 -1 -1; 1 1 -1; -1 1 -1; -1 -1 1; 1 -1 1; 1 1 1; -1 1 1];
busF = [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8];

sailV = [ ...
     b -L/2 0;  b+L -L/2 0;  b+L L/2 0;  b L/2 0; ...
    -b -L/2 0; -b-L -L/2 0; -b-L L/2 0; -b L/2 0; ...
    -L/2  b 0;  L/2  b 0;  L/2  b+L 0; -L/2  b+L 0; ...
    -L/2 -b 0;  L/2 -b 0;  L/2 -b-L 0; -L/2 -b-L 0];
sailF = [1 2 3 4; 5 6 7 8; 9 10 11 12; 13 14 15 16];
faceV = [-0.6 -0.6 -1.02; 0.6 -0.6 -1.02; 0.6 0.6 -1.02; -0.6 0.6 -1.02] * b;

ringAng = linspace(0, 2 * pi, nRing + 1);
fpFaces = [ones(nRing, 1), (2:nRing+1)', [3:nRing+1, 2]'];
[ux, uy, uz] = sphere(24);

tf = gobjects(nSat, 1);
sph = gobjects(nSat, 1);
fp = gobjects(nSat, 1);
rim = gobjects(nSat, 1);
trail = gobjects(nSat, 1);
arrow = gobjects(nSat, 1);
info = gobjects(nSat, 1);

for s = 1:nSat
    col = cols(s, :);

    plot3(ax, sats(s).pos(:, 1), sats(s).pos(:, 2), sats(s).pos(:, 3), ...
        'Color', [col 0.3], 'LineStyle', ':');
    trail(s) = animatedline(ax, 'Color', col, 'LineWidth', 1.5);

    fp(s) = patch('Parent', ax, 'Vertices', zeros(nRing + 1, 3), 'Faces', fpFaces, ...
        'FaceColor', col, 'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
        'FaceLighting', 'none', 'Visible', 'off');
    rim(s) = plot3(ax, nan(nRing + 1, 1), nan(nRing + 1, 1), nan(nRing + 1, 1), ...
        'Color', col, 'LineWidth', 1.5, 'Visible', 'off');

    sph(s) = surf(ax, ux, uy, uz, 'FaceColor', col, 'FaceAlpha', 0.05, ...
        'EdgeColor', col, 'EdgeAlpha', 0.12, 'FaceLighting', 'none');

    tf(s) = hgtransform('Parent', ax);
    patch('Parent', tf(s), 'Vertices', busV, 'Faces', busF, ...
        'FaceColor', 0.2 + 0.8 * col, 'EdgeColor', 'none', 'FaceLighting', 'flat');
    if ~sats(s).hasSail
        patch('Parent', tf(s), 'Vertices', faceV, 'Faces', 1:4, ...
            'FaceColor', [1 1 1], 'EdgeColor', 'none', 'FaceLighting', 'none');
    end
    if sats(s).hasSail
        patch('Parent', tf(s), 'Vertices', sailV, 'Faces', sailF, ...
            'FaceColor', [0.95 0.88 0.6], 'EdgeColor', [1 1 1], 'LineWidth', 0.5, ...
            'FaceLighting', 'gouraud', 'BackFaceLighting', 'lit', ...
            'AmbientStrength', 0.5, 'DiffuseStrength', 0.8, 'SpecularStrength', 0.6);
        arrow(s) = quiver3(ax, 0, 0, 0, 0, 0, 0, 0, 'Color', [1 0.35 0.25], ...
            'LineWidth', 1.8, 'MaxHeadSize', 0.8, 'Visible', 'off');
    end

    infoCol = floor((s - 1) / rowsPerCol);
    infoRow = mod(s - 1, rowsPerCol);
    info(s) = annotation(fig, 'textbox', [0.03 + 0.31 * infoCol, 0.91 - 0.075 * infoRow, 0.30, 0.07], 'String', '', ...
        'Color', col, 'EdgeColor', 'none', 'FontSize', 11, 'FontName', 'Consolas');
end

uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
    'Position', [0.62 0.03 0.13 0.04], 'String', 'SOI spheres', 'Value', 1, ...
    'BackgroundColor', 'k', 'ForegroundColor', 'w', ...
    'Callback', @(src, ~) set(sph, 'Visible', onOff(src.Value)));

timeInfo = annotation(fig, 'textbox', [0.78 0.03 0.20 0.05], 'String', '', ...
    'Color', 'w', 'EdgeColor', 'none', 'FontSize', 13, 'FontName', 'Consolas');

speeds = [0.5 1 2 4 8];
setappdata(fig, 'frame', 1);
setappdata(fig, 'playing', true);

playBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.03 0.03 0.06 0.04], 'String', 'Pause');
backBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.095 0.03 0.03 0.04], 'String', '<');
fwdBtn = uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.13 0.03 0.03 0.04], 'String', '>');
timeSld = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
    'Position', [0.17 0.037 0.35 0.03], 'Min', 1, 'Max', numFrames, 'Value', 1, ...
    'SliderStep', [1 / (numFrames - 1), 0.05]);
speedMenu = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
    'Position', [0.53 0.03 0.07 0.04], 'String', {'0.5x', '1x', '2x', '4x', '8x'}, 'Value', 2);

set(playBtn, 'Callback', @(~, ~) togglePlay(fig, playBtn, numFrames));
set(backBtn, 'Callback', @(~, ~) stepFrame(fig, timeSld, playBtn, -1, numFrames));
set(fwdBtn, 'Callback', @(~, ~) stepFrame(fig, timeSld, playBtn, 1, numFrames));
set(timeSld, 'Callback', @(src, ~) scrub(fig, playBtn, round(src.Value)));
try
    addlistener(timeSld, 'ContinuousValueChange', @(src, ~) scrub(fig, playBtn, round(src.Value)));
catch
end
set(fig, 'KeyPressFcn', @(~, e) onKey(fig, timeSld, playBtn, e, numFrames));

lastFrame = 0;
while ishghandle(fig)
    speed = speeds(get(speedMenu, 'Value'));
    stepSize = max(1, round(speed));

    if getappdata(fig, 'playing') && lastFrame > 0
        if getappdata(fig, 'playing')
            nxt = getappdata(fig, 'frame') + stepSize;
            if nxt >= numFrames
                nxt = numFrames;
                setappdata(fig, 'playing', false);
                set(playBtn, 'String', 'Play');
            end
            setappdata(fig, 'frame', nxt);
            set(timeSld, 'Value', nxt);
        end
    end

    fr = getappdata(fig, 'frame');

    if fr ~= lastFrame
        for s = 1:nSat
            p = posI{s}(fr, :)';
            v = velI{s}(fr, :)';
            th = thrI{s}(fr, :)';
            d = norm(p);
            thrusting = sats(s).hasSail && norm(th) > 0;

            [att, attMode] = attitudeAt(sats(s).att, T(fr), p, v, th);

            M = eye(4);
            M(1:3, 1:3) = att;
            M(1:3, 4) = p;
            set(tf(s), 'Matrix', M);

            rho = max(soi(s), 1e-3);
            set(sph(s), 'XData', p(1) + rho * ux, 'YData', p(2) + rho * uy, 'ZData', p(3) + rho * uz);

            [ring, ctr, ok, gam] = soiFootprint(p, R_moon, rho, ringAng);
            if ok
                set(fp(s), 'Vertices', [ctr; ring(1:nRing, :)], 'Visible', 'on');
                set(rim(s), 'XData', ring(:, 1), 'YData', ring(:, 2), 'ZData', ring(:, 3), 'Visible', 'on');
            else
                set([fp(s) rim(s)], 'Visible', 'off');
            end

            if fr > lastFrame && lastFrame >= 1
                idx = lastFrame + 1:fr;
            else
                clearpoints(trail(s));
                idx = 1:fr;
            end
            addpoints(trail(s), posI{s}(idx, 1), posI{s}(idx, 2), posI{s}(idx, 3));

            if sats(s).hasSail
                if thrusting
                    thHat = th / norm(th);
                    set(arrow(s), 'XData', p(1), 'YData', p(2), 'ZData', p(3), ...
                        'UData', arrowLen * thHat(1), 'VData', arrowLen * thHat(2), 'WData', arrowLen * thHat(3), ...
                        'Visible', 'on');
                else
                    set(arrow(s), 'Visible', 'off');
                end
                tag = 'SAIL';
            else
                tag = 'BARE';
            end

            set(info(s), 'String', sprintf('%s  [%s]\nALT %7.1f km  VEL %7.1f m/s\nSOI %5.0f km  FOOTPRINT RADIUS %6.1f km', ...
                sats(s).name, [tag ' | ' attMode], d - R_moon, norm(v) * 1e3, soi(s), R_moon * gam));
        end

        set(timeInfo, 'String', sprintf('T+ %7.1f s', T(fr)));

        if getappdata(fig, 'playing')
            camorbit(ax, 0.1, 0);
        end
        lastFrame = fr;
    end

    drawnow limitrate;
    waitT = stepSize / (fps * speed);
    t0 = tic;
    while toc(t0) < waitT && ishghandle(fig) && getappdata(fig, 'playing')
        drawnow;       % allow callbacks to run
        pause(0.01);   % short sleep to avoid busy-wait
    end

end

function v = getp(p, name, default)
if isstruct(p) && isfield(p, name) && ~isempty(p.(name))
    v = p.(name);
else
    v = default;
end
end

function togglePlay(fig, playBtn, numFrames)
if getappdata(fig, 'playing')
    setappdata(fig, 'playing', false);
    set(playBtn, 'String', 'Play');
else
    if getappdata(fig, 'frame') >= numFrames
        setappdata(fig, 'frame', 1);
    end
    setappdata(fig, 'playing', true);
    set(playBtn, 'String', 'Pause');
end
end

function stepFrame(fig, timeSld, playBtn, delta, numFrames)
setappdata(fig, 'playing', false);
set(playBtn, 'String', 'Play');
fr = min(max(getappdata(fig, 'frame') + delta, 1), numFrames);
setappdata(fig, 'frame', fr);
set(timeSld, 'Value', fr);
end

function scrub(fig, playBtn, fr)
setappdata(fig, 'playing', false);
set(playBtn, 'String', 'Play');
setappdata(fig, 'frame', fr);
end

function onKey(fig, timeSld, playBtn, e, numFrames)
delta = 1;
if any(strcmp(e.Modifier, 'shift'))
    delta = 10;
end
switch e.Key
    case 'leftarrow'
        stepFrame(fig, timeSld, playBtn, -delta, numFrames);
    case 'rightarrow'
        stepFrame(fig, timeSld, playBtn, delta, numFrames);
    case 'space'
        togglePlay(fig, playBtn, numFrames);
end
end

function str = onOff(flag)
if flag
    str = 'on';
else
    str = 'off';
end
end

function [ring, ctr, ok, gam] = soiFootprint(p, R, rho, ringAng)
ring = [];
ctr = [];
ok = false;
gam = 0;

d = norm(p);
if d <= R || rho <= d - R
    return
end

rhoEff = min(rho, sqrt(d^2 - R^2));
gam = acos(min(max((R^2 + d^2 - rhoEff^2) / (2 * R * d), -1), 1));

u = p / d;
if abs(u(3)) < 0.9
    a = [0; 0; 1];
else
    a = [1; 0; 0];
end
e1 = cross(u, a);
e1 = e1 / norm(e1);
e2 = cross(u, e1);

dirs = cos(ringAng(:)) * e1' + sin(ringAng(:)) * e2';
ring = 1.003 * R * (cos(gam) * u' + sin(gam) * dirs);
ctr = 1.003 * R * u';
ok = true;
end
