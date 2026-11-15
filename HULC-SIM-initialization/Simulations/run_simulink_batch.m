function run_simulink_batch(paramsFile, outFile)

params = jsondecode(fileread(paramsFile));

mission.StartDate = datetime(2025,1,1,12,0,0);

if isfield(params, 'duration_hours')
    mission.Duration = hours(params.duration_hours);
else
    mission.Duration = hours(2.2);
end

mu_moon = 4.9028695e12;
sims_dir = fileparts(mfilename('fullpath'));

mission.Satellite.SemiMajorAxis  = params.semi_major_axis_m;
mission.Satellite.Eccentricity   = params.eccentricity;
mission.Satellite.Inclination    = params.inclination_deg;
mission.Satellite.ArgOfPeriapsis = params.arg_periapsis_deg;
mission.Satellite.RAAN           = params.raan_deg;
mission.Satellite.TrueAnomaly    = params.true_anomaly_deg;

[mass, sail] = satelliteFromParams(params);

mission.Satellite.x0 = orbitalElementsToState( ...
    mission.Satellite.SemiMajorAxis, ...
    mission.Satellite.Eccentricity, ...
    mission.Satellite.Inclination, ...
    mission.Satellite.RAAN, ...
    mission.Satellite.ArgOfPeriapsis, ...
    mission.Satellite.TrueAnomaly, ...
    mu_moon);

opts = odeset('RelTol', 1e-9, 'AbsTol', 1e-6);

[tout, yout] = ode45(@(t, x) get_step(x, mass, sail), ...
    [0, seconds(mission.Duration)], mission.Satellite.x0, opts);

position_icrf = yout(:, 1:3);
velocity_icrf = yout(:, 4:6);

thrust_icrf = zeros(size(yout, 1), 3);
if sail.enabled
    for i = 1:size(yout, 1)
        thrust_icrf(i, :) = jsValue(fullfile(sims_dir, 'solarSailThrust.js'), ...
            [yout(i, :)'; sail.magnitude_N; sail.frame_code; sail.direction])';
    end
end

att = prepareAttitude(params, tout, position_icrf, velocity_icrf);
C_b2icrf = zeros(3, 3, numel(tout));
for i = 1:numel(tout)
    C_b2icrf(:, :, i) = attitudeAt(att, tout(i), position_icrf(i, :)', velocity_icrf(i, :)', thrust_icrf(i, :)');
end

orbit_params = params;

[outDir, ~, ~] = fileparts(outFile);
if ~isempty(outDir) && ~exist(outDir, 'dir')
    mkdir(outDir);
end

save(outFile, 'tout', 'yout', 'position_icrf', 'velocity_icrf', 'thrust_icrf', 'C_b2icrf', 'mass', 'sail', 'orbit_params', '-v7.3');

fprintf('Saved results for "%s" to %s\n', params.name, outFile);

end
