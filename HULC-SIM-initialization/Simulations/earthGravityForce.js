function earthGravityForce(state) {
  // Placeholder: zero force until a real model is implemented (newtons, same frame as state).
  return [0, 0, 0];
}

module.exports = earthGravityForce;

if (require.main === module) {
  const state = process.argv.slice(2).map(Number);
  console.log(earthGravityForce(state).join(' '));
}
