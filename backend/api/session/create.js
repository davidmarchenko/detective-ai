import { requireAuth } from '../_auth.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();
  if (!requireAuth(req, res)) return;

  const response = await fetch('https://api.dev.runwayml.com/v1/realtime_sessions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.RUNWAYML_API_SECRET}`,
      'Content-Type': 'application/json',
      'X-Runway-Version': '2024-11-06',
    },
    body: JSON.stringify(req.body),
  });

  const data = await response.json();
  res.status(response.status).json(data);
}
