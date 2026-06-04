const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');

function getCandidate(envKey, fallbackName) {
  const envValue = process.env[envKey];
  if (envValue && fs.existsSync(envValue)) {
    return envValue;
  }

  const javaHome = process.env.JAVA_HOME || '';
  if (javaHome.length > 0) {
    const javaHomeCandidate = path.join(javaHome, 'bin', fallbackName);
    if (fs.existsSync(javaHomeCandidate)) {
      return javaHomeCandidate;
    }
  }

  return '';
}

function resolveCommand(command) {
  if (process.platform !== 'win32') {
    return command;
  }

  if (command === 'java') {
    const javaCandidate = getCandidate('FITTRACKER_JAVA_EXE', 'java.exe');
    if (javaCandidate.length > 0) {
      return javaCandidate;
    }
  }

  if (command === 'javac') {
    const javacCandidate = getCandidate('FITTRACKER_JAVAC_EXE', 'javac.exe');
    if (javacCandidate.length > 0) {
      return javacCandidate;
    }
  }

  return command;
}

function wrapSpawnLike(originalFn) {
  return function wrappedSpawnLike(command, ...args) {
    return originalFn.call(this, resolveCommand(command), ...args);
  };
}

childProcess.spawn = wrapSpawnLike(childProcess.spawn);
childProcess.spawnSync = wrapSpawnLike(childProcess.spawnSync);
childProcess.execFile = wrapSpawnLike(childProcess.execFile);
childProcess.execFileSync = wrapSpawnLike(childProcess.execFileSync);
