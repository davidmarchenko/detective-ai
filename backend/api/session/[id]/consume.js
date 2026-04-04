import { requireAuth } from '../../_auth.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  if (!requireAuth(req, res)) return;

  const { id } = req.query;
  const sessionKey = req.headers['x-session-key'];

  if (!sessionKey) return res.status(400).json({ error: 'Missing x-session-key header' });

  const response = await fetch(`https://api.dev.runwayml.com/v1/realtime_sessions/${id}/consume`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${sessionKey}`,
      'Content-Type': 'application/json',
      'X-Runway-Version': '2024-11-06',
    },
  });

  const data = await response.json();
  res.status(response.status).json(data);
}
