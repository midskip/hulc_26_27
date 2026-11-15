mission.StartDate = datetime(2025,1,1,12,0,0);
mission.Duration = hours(2.2);

mu_moon = 4.9028695e12;

mission.Satellite.SemiMajorAxis  = 1837400;  % meters (R_moon 1737.4 km + 100 km altitude)
mission.Satellite.Eccentricity   = 0.0002;
mission.Satellite.Inclination    = 90;
mission.Satellite.ArgOfPeriapsis = 0;
mission.Satellite.RAAN           = 0;
mission.Satellite.TrueAnomaly    = 0;

mass = 0.25;

mission.Satellite.x0 = orbitalElementsToState( ...
    mission.Satellite.SemiMajorAxis, ...
    mission.Satellite.Eccentricity, ...
    mission.Satellite.Inclination, ...
    mission.Satellite.RAAN, ...
    mission.Satellite.ArgOfPeriapsis, ...
    mission.Satellite.TrueAnomaly, ...
    mu_moon);

opts = odeset('RelTol', 1e-9, 'AbsTol', 1e-6);

[tout, yout] = ode45(@(t, x) get_step(x, mass), ...
    [0, seconds(mission.Duration)], mission.Satellite.x0, opts);

mission.SimOutput.tout = tout;
mission.SimOutput.position_icrf = yout(:, 1:3);
mission.SimOutput.velocity_icrf = yout(:, 4:6);
