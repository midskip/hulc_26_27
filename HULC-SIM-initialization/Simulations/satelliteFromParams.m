function [mass, sail] = satelliteFromParams(params)
arguments (Input)
    params (1,1) struct
end

arguments (Output)
    mass (1,1) double
    sail (1,1) struct
end

solarPressure = 4.56e-6;

mass = 0.25;
if isfield(params, 'mass_kg')
    mass = params.mass_kg;
end

if isfield(params, 'tidally_locked') && params.tidally_locked ...
        && isfield(params, 'has_sail') && params.has_sail
    error('satelliteFromParams:lockedSail', 'a sail satellite cannot be tidally_locked');
end

sail = struct('enabled', false, 'magnitude_N', 0, 'frame_code', 0, 'direction', [1; 0; 0]);

if ~isfield(params, 'has_sail') || ~params.has_sail
    return
end

if ~isfield(params, 'sail')
    error('satelliteFromParams:missingSail', 'has_sail is true but no "sail" block was given');
end

s = params.sail;

reflectivity = 0.9;
if isfield(s, 'reflectivity')
    reflectivity = s.reflectivity;
end

if isfield(s, 'magnitude_N')
    magnitude = s.magnitude_N;
else
    magnitude = solarPressure * (1 + reflectivity) * s.area_m2;
end

frame = 'orbital';
if isfield(s, 'frame')
    frame = s.frame;
end

switch lower(frame)
    case 'inertial'
        frameCode = 0;
    case 'orbital'
        frameCode = 1;
    otherwise
        error('satelliteFromParams:badFrame', 'sail.frame must be "inertial" or "orbital"');
end

direction = [0; 1; 0];
if isfield(s, 'direction')
    direction = s.direction(:);
end

if norm(direction) == 0
    error('satelliteFromParams:badDirection', 'sail.direction must be non-zero');
end

sail.enabled = true;
sail.magnitude_N = magnitude;
sail.frame_code = frameCode;
sail.direction = direction / norm(direction);
end
