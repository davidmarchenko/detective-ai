import { requireAuth } from '../../_auth.js';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

export default function handler(req, res) {
  if (req.method !== 'GET') return res.status(405).end();
  if (!requireAuth(req, res)) return;

  const { scenarioId } = req.query;
  const type = req.query.type || 'audio'; // 'audio' or 'timings'

  const dir = join(process.cwd(), 'public', 'audio');

  if (type === 'timings') {
    const path = join(dir, `${scenarioId}_briefing_timings.json`);
    if (!existsSync(path)) return res.status(404).json({ error: 'Timings not found' });
    const data = readFileSync(path, 'utf-8');
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Cache-Control', 'public, max-age=86400');
    return res.status(200).send(data);
  }

  const path = join(dir, `${scenarioId}_briefing.mp3`);
  if (!existsSync(path)) return res.status(404).json({ error: 'Audio not found' });
  const data = readFileSync(path);
  res.setHeader('Content-Type', 'audio/mpeg');
  res.setHeader('Cache-Control', 'public, max-age=86400');
  return res.status(200).send(data);
}
