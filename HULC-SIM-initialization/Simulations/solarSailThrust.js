function normalize(v) {
  const n = Math.hypot(v[0], v[1], v[2]);
  return n > 0 ? [v[0] / n, v[1] / n, v[2] / n] : [0, 0, 0];
}

function cross(a, b) {
  return [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];
}

function solarSailThrust(state, magnitude, frame, direction) {
  if (!(magnitude > 0)) {
    return [0, 0, 0];
  }

  const d = normalize(direction);

  if (frame === 0) {
    return d.map((c) => magnitude * c);
  }

  const r = state.slice(0, 3);
  const v = state.slice(3, 6);
  const rHat = normalize(r);
  const nHat = normalize(cross(r, v));
  const tHat = cross(nHat, rHat);

  return [0, 1, 2].map(
    (i) => magnitude * (d[0] * rHat[i] + d[1] * tHat[i] + d[2] * nHat[i])
  );
}

module.exports = solarSailThrust;

if (require.main === module) {
  const a = process.argv.slice(2).map(Number);
  console.log(solarSailThrust(a.slice(0, 6), a[6], a[7], a.slice(8, 11)).join(' '));
}
