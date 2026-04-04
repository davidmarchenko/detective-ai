export function requireAuth(req, res) {
  const token = req.headers['x-app-token'];
  if (!token || token !== process.env.APP_AUTH_TOKEN) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  return true;
}
