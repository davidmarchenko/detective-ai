import { requireAuth } from '../../_auth.js';

export default async function handler(req, res) {
  if (req.method !== 'GET') return res.status(405).end();
  if (!requireAuth(req, res)) return;

  const { id } = req.query;

  const response = await fetch(`https://api.dev.runwayml.com/v1/realtime_sessions/${id}`, {
    headers: {
      'Authorization': `Bearer ${process.env.RUNWAYML_API_SECRET}`,
      'X-Runway-Version': '2024-11-06',
    },
  });

  const data = await response.json();
  res.status(response.status).json(data);
}
