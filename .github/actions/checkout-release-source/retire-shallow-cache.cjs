'use strict';

const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

module.exports = function retireShallowCache({core, env = process.env}) {
  const repository = env.GITHUB_REPOSITORY || '';
  if (env.GITHUB_ACTIONS !== 'true' || !/^[\w.-]+\/[\w.-]+$/.test(repository)) {
    throw new Error('Release checkout requires a GitHub Actions repository workspace.');
  }
  const workspace = fs.realpathSync.native(env.GITHUB_WORKSPACE);
  const temporary = fs.realpathSync.native(env.RUNNER_TEMP);
  const name = repository.split('/')[1];
  const expected = path.join(path.dirname(temporary), name, name);
  const equal = (a, b) => process.platform === 'win32'
    ? a.toLowerCase() === b.toLowerCase() : a === b;
  if (!equal(workspace, expected) || fs.lstatSync(env.GITHUB_WORKSPACE).isSymbolicLink()) {
    throw new Error('Refusing to alter Git metadata outside the runner-owned repository workspace.');
  }
  const metadata = path.join(workspace, '.git');
  let information;
  try { information = fs.lstatSync(metadata); }
  catch (error) { if (error.code === 'ENOENT') return {retired: false}; throw error; }
  if (!information.isDirectory() || information.isSymbolicLink()) {
    throw new Error('Refusing a linked Git directory or worktree.');
  }
  const git = (...args) => execFileSync('git', ['-C', workspace, ...args], {
    env: {...env, GIT_OPTIONAL_LOCKS: '0'}, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
  }).trim();
  if (git('rev-parse', '--is-shallow-repository') !== 'true') return {retired: false};
  const origin = new URL(git('config', '--get', 'remote.origin.url'));
  if (origin.protocol !== 'https:' || origin.hostname !== 'github.com'
      || origin.username || origin.password
      || origin.pathname.replace(/\.git$/, '').replace(/^\//, '').toLowerCase() !== repository.toLowerCase()) {
    throw new Error('The shallow cache does not belong to the calling GitHub repository.');
  }
  for (const name of ['worktrees', 'modules']) {
    const directory = path.join(metadata, name);
    if (fs.existsSync(directory) && fs.readdirSync(directory).length) {
      throw new Error('Retaining Git metadata with registered worktrees or submodules.');
    }
  }
  for (const name of ['index.lock', 'shallow.lock', 'HEAD.lock']) {
    if (fs.existsSync(path.join(metadata, name))) throw new Error('Retaining locked Git metadata.');
  }
  try { git('diff', '--quiet'); git('diff', '--cached', '--quiet'); }
  catch { throw new Error('Could not verify clean tracked source; retaining the CI Git metadata.'); }
  if (git('ls-files', '--others', '--exclude-standard') || git('for-each-ref', '--format=%(objectname)', 'refs/stash')) {
    throw new Error('Retaining unexpected untracked files or stashed work in the CI workspace.');
  }
  const publicRefs = new Set(git('for-each-ref', '--format=%(objectname)', 'refs/remotes', 'refs/tags').split('\n'));
  const branches = git('for-each-ref', '--format=%(objectname)', 'refs/heads').split('\n').filter(Boolean);
  if (branches.some(oid => !publicRefs.has(oid))) {
    throw new Error('Retaining a local branch that is not represented by the cached remote refs.');
  }
  const backup = fs.mkdtempSync(path.join(temporary, 'zstandard-shallow-git-'));
  fs.chmodSync(backup, 0o700);
  fs.writeFileSync(path.join(backup, '.owner'), JSON.stringify({repository, run: env.GITHUB_RUN_ID,
    attempt: env.GITHUB_RUN_ATTEMPT, head: git('rev-parse', 'HEAD')}), {mode: 0o600});
  fs.renameSync(metadata, path.join(backup, 'git'));
  core.notice('Retired shallow CI Git metadata to private job temporary storage; checkout will fetch complete history.');
  return {retired: true};
};
