function [C, mode] = attitudeAt(att, t, p, v, th)
arguments (Input)
    att (1,1) struct
    t (1,1) double
    p (3,1) double
    v (3,1) double
    th (3,1) double
end

arguments (Output)
    C (3,3) double
    mode char
end

i = find([att.seg.start_s] <= t, 1, 'last');
seg = att.seg(i);
mode = seg.mode;
pHat = p / norm(p);

switch mode
    case 'inertial'
        C = eye(3);

    case 'spin'
        K = [0 -seg.axis(3) seg.axis(2); seg.axis(3) 0 -seg.axis(1); -seg.axis(2) seg.axis(1) 0];
        ang = seg.rate * (t - seg.start_s);
        C = eye(3) + sin(ang) * K + (1 - cos(ang)) * (K * K);

    case 'tidal_lock'
        ang = att.n * (t - seg.start_s);
        zb = cos(ang) * seg.r0 + sin(ang) * cross(seg.h0, seg.r0);
        yb = seg.h0;
        C = [cross(yb, zb) yb zb];

    otherwise
        if strcmp(mode, 'thrust') && norm(th) > 0
            zb = th / norm(th);
        elseif strcmp(mode, 'pointing')
            if seg.frame_code == 0
                zb = seg.direction;
            else
                nHat = cross(p, v);
                nHat = nHat / norm(nHat);
                tHat = cross(nHat, pHat);
                zb = seg.direction(1) * pHat + seg.direction(2) * tHat + seg.direction(3) * nHat;
            end
        else
            zb = pHat;
        end
        [xb, yb] = bodyAxes(zb, v);
        C = [xb yb zb];
end
end

function [xb, yb] = bodyAxes(zb, ref)
ref = ref / norm(ref);
xb = ref - (ref' * zb) * zb;
if norm(xb) < 1e-6
    ref = [0; 0; 1];
    xb = ref - (ref' * zb) * zb;
end
if norm(xb) < 1e-6
    ref = [1; 0; 0];
    xb = ref - (ref' * zb) * zb;
end
xb = xb / norm(xb);
yb = cross(zb, xb);
end
