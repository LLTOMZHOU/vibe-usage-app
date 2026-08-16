import { parsers } from './parsers/index.js';
import { normalizeParserResult } from './parsers/contract.js';
import { mapWithConcurrency } from './concurrency.js';

export const LOCAL_PARSER_CONCURRENCY = 4;

function finiteDate(value, label) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new Error(`Invalid ${label} date`);
  return date;
}

export function parseSnapshotArguments(args, now = new Date()) {
  if (args.length === 0) return { from: null, to: null };
  if (args.length === 2 && args[0] === '--days') {
    const days = Number(args[1]);
    if (!Number.isInteger(days) || days < 1 || days > 3650) {
      throw new Error('--days must be an integer from 1 through 3650');
    }
    return { from: new Date(now.getTime() - days * 86_400_000), to: null };
  }
  if ((args.length === 2 || args.length === 4) && args[0] === '--from') {
    const from = finiteDate(args[1], '--from');
    if (args.length === 2) return { from, to: null };
    if (args[2] !== '--to') throw new Error('Expected --to after --from');
    const to = finiteDate(args[3], '--to');
    if (to <= from) throw new Error('--to must be later than --from');
    return { from, to };
  }
  throw new Error('snapshot accepts --days N or --from ISO [--to ISO]');
}

function within(timestamp, from, to) {
  const time = new Date(timestamp).getTime();
  if (!Number.isFinite(time)) return false;
  if (from && time < from.getTime()) return false;
  if (to && time >= to.getTime()) return false;
  return true;
}

function stableSort(items, field) {
  return items.sort((left, right) => {
    const timeOrder = String(left[field]).localeCompare(String(right[field]));
    if (timeOrder !== 0) return timeOrder;
    return `${left.source}\0${left.model || ''}\0${left.project}`
      .localeCompare(`${right.source}\0${right.model || ''}\0${right.project}`);
  });
}

/**
 * Build the dashboard response entirely from local parser output.
 * This module deliberately has no dependency on api.js, config.js, sync.js,
 * state.js, or any HTTP primitive.
 */
export async function buildLocalSnapshot({
  registry = parsers,
  from = null,
  to = null,
  hostname = process.env.VIBE_USAGE_HOSTNAME?.trim() || 'Mac-private',
  onWarning = () => {},
} = {}) {
  const outcomes = await mapWithConcurrency(
    Object.entries(registry),
    LOCAL_PARSER_CONCURRENCY,
    async ([source, parse]) => {
      try {
        return { source, result: await parse() };
      } catch (error) {
        return { source, error };
      }
    },
  );

  const buckets = [];
  const sessions = [];
  for (const { source, result, error } of outcomes) {
    if (error) {
      onWarning(`${source}: ${error.message}`);
      continue;
    }
    let normalized;
    try {
      normalized = normalizeParserResult(source, result);
    } catch (contractError) {
      onWarning(`${source}: ${contractError.message}`);
      continue;
    }
    for (const warning of normalized.warnings) onWarning(warning);
    for (const bucket of normalized.buckets) {
      if (!within(bucket.bucketStart, from, to)) continue;
      buckets.push({ ...bucket, hostname: bucket.hostname || hostname });
    }
    for (const session of normalized.sessions) {
      if (!within(session.firstMessageAt, from, to)) continue;
      sessions.push({ ...session, hostname: session.hostname || hostname });
    }
  }

  stableSort(buckets, 'bucketStart');
  stableSort(sessions, 'firstMessageAt');
  return {
    buckets,
    sessions,
    hasAnyData: buckets.length > 0 || sessions.length > 0,
  };
}

export async function runLocalSnapshot(args = []) {
  const range = parseSnapshotArguments(args);
  const response = await buildLocalSnapshot({
    ...range,
    onWarning: message => process.stderr.write(`warning: ${message}\n`),
  });
  process.stdout.write(`${JSON.stringify(response)}\n`);
}
