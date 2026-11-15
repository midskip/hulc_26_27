function [x_dot] = get_step(state, mass, sail)
arguments (Input)
    state
    mass
    sail (1,1) struct = struct('enabled', false)
end

arguments (Output)
    x_dot
end

mu_moon = 4.9028695e12;
sims_dir = fileparts(mfilename('fullpath'));

r = state(1:3);

x_dot = zeros(6, 1);
x_dot(1:3) = state(4:6);

a_moon = -mu_moon * r / norm(r)^3;

F_earth = jsValue(fullfile(sims_dir, 'earthGravityForce.js'), state);

if sail.enabled
    F_thrust = jsValue(fullfile(sims_dir, 'solarSailThrust.js'), ...
        [state(:); sail.magnitude_N; sail.frame_code; sail.direction(:)]);
else
    F_thrust = zeros(3, 1);
end

x_dot(4:6) = a_moon + (F_earth + F_thrust) / mass;
end
