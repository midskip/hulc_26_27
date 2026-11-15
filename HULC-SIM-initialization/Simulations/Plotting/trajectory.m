if exist('mission', 'var')
    t = mission.SimOutput.tout;
    pos = mission.SimOutput.position_icrf / 1e3;
    vel = mission.SimOutput.velocity_icrf / 1e3;
else
    t = tout;
    pos = position_icrf / 1e3;
    vel = velocity_icrf / 1e3;
end

R_moon = 1737.4;
sailScale = 0.06 * R_moon;
busHalf = 0.012 * R_moon;
simDuration = 8;
fps = 60;
numFrames = simDuration * fps;

N = size(pos, 1);
idx = round(linspace(1, N, numFrames));
lim = 1.6 * max(vecnorm(pos, 2, 2));

figure('Color', 'k', 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
ax = axes('Color', 'k');
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

plot3(ax, pos(:, 1), pos(:, 2), pos(:, 3), ...
    'Color', [1 0.85 0.4 0.25], 'LineStyle', ':');
trail = animatedline(ax, 'Color', [1 0.8 0.3], 'LineWidth', 1.5);

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

tf = hgtransform('Parent', ax);
patch('Parent', tf, 'Vertices', busV, 'Faces', busF, ...
    'FaceColor', [0.6 0.6 0.65], 'EdgeColor', 'none', 'FaceLighting', 'flat');
patch('Parent', tf, 'Vertices', sailV, 'Faces', sailF, ...
    'FaceColor', [0.95 0.88 0.6], 'EdgeColor', [1 1 1], 'LineWidth', 0.5, ...
    'FaceLighting', 'gouraud', 'BackFaceLighting', 'lit', ...
    'AmbientStrength', 0.5, 'DiffuseStrength', 0.8, 'SpecularStrength', 0.6);

info = annotation('textbox', [0.03 0.88 0.4 0.08], 'String', '', ...
    'Color', 'w', 'EdgeColor', 'none', 'FontSize', 13, 'FontName', 'Consolas');

for k = 1:numFrames
    i = idx(k);

    zb = pos(i, :)' / norm(pos(i, :));
    xb = vel(i, :)' - (vel(i, :) * zb) * zb;
    xb = xb / norm(xb);
    yb = cross(zb, xb);

    M = eye(4);
    M(1:3, 1:3) = [xb yb zb];
    M(1:3, 4) = pos(i, :)';
    set(tf, 'Matrix', M);

    addpoints(trail, pos(i, 1), pos(i, 2), pos(i, 3));

    set(info, 'String', sprintf('T+ %7.1f s\nALT %7.1f km\nVEL %7.1f m/s', ...
        t(i), norm(pos(i, :)) - R_moon, norm(vel(i, :)) * 1e3));

    camorbit(ax, 0.1, 0);
    drawnow limitrate;
    pause(1 / fps);
end
