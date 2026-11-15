function state = orbitalElementsToState(a, e, inc, raan, argp, nu, mu)
arguments (Input)
    a
    e
    inc
    raan
    argp
    nu
    mu
end

arguments (Output)
    state
end

p = a * (1 - e^2);
r = p / (1 + e * cosd(nu));

r_pf = [r * cosd(nu); r * sind(nu); 0];
v_pf = sqrt(mu / p) * [-sind(nu); e + cosd(nu); 0];

R3 = @(t) [cosd(t), -sind(t), 0; sind(t), cosd(t), 0; 0, 0, 1];
R1 = @(t) [1, 0, 0; 0, cosd(t), -sind(t); 0, sind(t), cosd(t)];

Q = R3(raan) * R1(inc) * R3(argp);

state = [Q * r_pf; Q * v_pf];
end
