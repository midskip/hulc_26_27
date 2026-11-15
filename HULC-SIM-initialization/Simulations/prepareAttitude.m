function att = prepareAttitude(params, tout, pos, vel)
arguments (Input)
    params (1,1) struct
    tout (:,1) double
    pos (:,3) double
    vel (:,3) double
end

arguments (Output)
    att (1,1) struct
end

mu_moon = 4.9028695e12;
validModes = {'nadir', 'tidal_lock', 'inertial', 'pointing', 'thrust', 'spin'};

hasSail = isfield(params, 'has_sail') && params.has_sail;
locked = isfield(params, 'tidally_locked') && params.tidally_locked;

if isfield(params, 'attitude_schedule') && ~isempty(params.attitude_schedule)
    raw = params.attitude_schedule;
    if iscell(raw)
        segs = raw(:);
    else
        segs = num2cell(raw(:));
    end
else
    if hasSail
        defaultMode = 'thrust';
    elseif locked
        defaultMode = 'tidal_lock';
    else
        defaultMode = 'inertial';
    end
    segs = {struct('start_s', 0, 'mode', defaultMode)};
end

if isfield(params, 'semi_major_axis_m')
    a = params.semi_major_axis_m;
else
    a = norm(pos(1, :));
end

seg = struct('start_s', {}, 'mode', {}, 'frame_code', {}, 'direction', {}, ...
    'axis', {}, 'rate', {}, 'r0', {}, 'h0', {});

prev = -inf;
for i = 1:numel(segs)
    s = segs{i};

    if ~isfield(s, 'start_s') || ~isfield(s, 'mode')
        error('prepareAttitude:badSegment', 'every attitude_schedule entry needs start_s and mode');
    end
    if i == 1 && s.start_s ~= 0
        error('prepareAttitude:badStart', 'the first attitude_schedule entry must have start_s = 0');
    end
    if s.start_s <= prev
        error('prepareAttitude:badOrder', 'attitude_schedule start_s values must be strictly increasing');
    end
    prev = s.start_s;

    mode = lower(s.mode);
    if ~any(strcmp(mode, validModes))
        error('prepareAttitude:badMode', 'unknown attitude mode "%s"', mode);
    end

    frameCode = 0;
    direction = [0; 0; 1];
    axisVec = [0; 0; 1];
    rate = 0;

    if strcmp(mode, 'pointing')
        if ~isfield(s, 'direction') || norm(s.direction) == 0
            error('prepareAttitude:badDirection', 'pointing needs a non-zero direction');
        end
        direction = s.direction(:) / norm(s.direction);
        if isfield(s, 'frame')
            switch lower(s.frame)
                case 'inertial'
                    frameCode = 0;
                case 'orbital'
                    frameCode = 1;
                otherwise
                    error('prepareAttitude:badFrame', 'frame must be "inertial" or "orbital"');
            end
        end
    end

    if strcmp(mode, 'spin')
        if ~isfield(s, 'axis') || ~isfield(s, 'rate_deg_s') || norm(s.axis) == 0
            error('prepareAttitude:badSpin', 'spin needs a non-zero axis and rate_deg_s');
        end
        axisVec = s.axis(:) / norm(s.axis);
        rate = deg2rad(s.rate_deg_s);
    end

    r0 = pos(1, :)' / norm(pos(1, :));
    h0 = cross(pos(1, :)', vel(1, :)');
    if strcmp(mode, 'tidal_lock')
        r0 = interp1(tout, pos, s.start_s, 'linear', 'extrap')';
        v0 = interp1(tout, vel, s.start_s, 'linear', 'extrap')';
        h0 = cross(r0, v0);
        r0 = r0 / norm(r0);
    end
    h0 = h0 / norm(h0);

    seg(i) = struct('start_s', s.start_s, 'mode', mode, 'frame_code', frameCode, ...
        'direction', direction, 'axis', axisVec, 'rate', rate, 'r0', r0, 'h0', h0);
end

att.seg = seg;
att.n = sqrt(mu_moon / a^3);
end
