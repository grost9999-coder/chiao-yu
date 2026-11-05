'use strict';
// No input UID is accepted: only the verified callable identity determines scope.
async function deleteOwnedAccount(request, deps) {
  const uid = request.auth?.uid;
  if (!uid) throw deps.error('unauthenticated', 'Sign in first.');
  const authTime = request.auth.token?.auth_time;
  const now = deps.now();
  if (typeof authTime !== 'number' || !Number.isFinite(authTime) || now - authTime > 300 || now < authTime - 30)
    throw deps.error('failed-precondition', 'Reauthenticate before deleting your account.');
  await deps.lock(uid, now + 7 * 86400);
  await deps.deleteSnapshots(uid);
  await deps.deleteUser(uid);
  return {deleted: true};
}
module.exports = {deleteOwnedAccount};
