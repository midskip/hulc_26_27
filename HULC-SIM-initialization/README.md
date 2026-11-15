# HULC SIM

ADCS for GOAT-1

Hopefully simulating the following...

Sensors:
* IMU
* Sun sensor
* Star tracker

# Prerequisites

* Python
  * ```pip install -r requirements.txt```
* Node.js
* Matlab
  * Simulink
  * Aerospace toolbox

# Multi-satellite lunar runs

Every entry in `lunar_orbits.json` is one satellite with its own orbit. Run them all with:

```
python run_orbits.py
```

Each satellite is written to `data/<name>.mat`. Then in MATLAB run `Simulations/Plotting/trajectory_multi.m` to show every satellite in its own orbit at once.

Per-satellite fields (in addition to the orbital elements and `duration_hours`):

| Field | Meaning |
|---|---|
| `mass_kg` | Satellite mass (default 0.25) |
| `has_sail` | `true` for a solar sail satellite, `false` for a bare one |
| `sail.area_m2` | Sail area, used for the thrust magnitude |
| `sail.reflectivity` | Default 0.9 |
| `sail.magnitude_N` | Optional, overrides the area based thrust |
| `sail.frame` | `inertial` or `orbital` (radial, along-track, orbit-normal) |
| `sail.direction` | Thrust direction in that frame, e.g. `[0, 1, 0]` is prograde in `orbital` |
| `tidally_locked` | `true` makes a bare satellite rotate once per orbit (same face toward the Moon). Default `false` (fixed in inertial space). Not allowed with `has_sail` |
| `attitude_schedule` | Optional list of attitude segments, see below |
| `soi_radius_km` | Sphere of influence radius, fixed for the whole run |

Each sail satellite gets its own thrust vector from `Simulations/solarSailThrust.js`. Satellites without a sail never call it.

In the viewer, each satellite's sphere of influence is set by `soi_radius_km` in its entry and does not change during the run. The part of that sphere that reaches the lunar surface (limited to what the satellite can see) is projected onto the surface as a filled circle that follows the satellite. If the sphere does not reach the surface, no circle is drawn. The checkbox hides the spheres themselves.

Playback controls along the bottom: Play/Pause, step back and forward (`<` `>`), a time slider to scrub anywhere in the run, and a speed menu (0.5x to 8x). Keyboard: left and right arrows step one frame (hold shift for 10), space plays or pauses. Scrubbing pauses playback, and the trails are redrawn up to the current time.

Bare satellites have a white face on the side that faces the Moon when tidally locked. A tidally locked satellite spins at the orbit's mean motion, so on an eccentric orbit it librates around nadir instead of staying exactly nadir pointing. Attitude is prescribed in the viewer, not simulated.

To view only some satellites, set `dataFiles` to a cell array of `.mat` paths before running the script. Run `clear dataFiles` to go back to everything in `data/`.

# Attitude schedule

Without `attitude_schedule`, a satellite uses one mode for the whole run: `thrust` for a sail satellite, `tidal_lock` if `tidally_locked` is true, otherwise `inertial`.

With it, each entry switches the attitude at `start_s` (seconds from the start). The first entry must have `start_s` 0 and the times must increase. The switch is instant, with no slew.

```
"attitude_schedule": [
  { "start_s": 0,    "mode": "nadir" },
  { "start_s": 1800, "mode": "pointing", "frame": "orbital", "direction": [0, 0, 1] },
  { "start_s": 3600, "mode": "spin", "axis": [0, 0, 1], "rate_deg_s": 2 },
  { "start_s": 5400, "mode": "tidal_lock" }
]
```

| Mode | Behavior |
|---|---|
| `nadir` | Body +z points away from the Moon, body x toward the velocity |
| `tidal_lock` | Rotates at the mean motion, starting from nadir at the segment start. Exactly nadir on a circular orbit, librates on an eccentric one |
| `inertial` | Fixed in inertial space (identity) |
| `pointing` | Body +z along `direction`, in `frame` `inertial` (default) or `orbital` (radial, along-track, orbit-normal) |
| `thrust` | Body +z along the current thrust vector, `nadir` when there is none |
| `spin` | Rotates about the inertial `axis` at `rate_deg_s`, starting from the inertial attitude at the segment start |

The attitude is prescribed from the trajectory and does not change the orbit. For a sail satellite, the thrust still comes from `sail.direction`, whatever the attitude is. The resulting body to inertial rotation matrices are saved in each `.mat` as `C_b2icrf` (3x3xN, matching `tout`), and the viewer shows the current mode next to each satellite's name.
