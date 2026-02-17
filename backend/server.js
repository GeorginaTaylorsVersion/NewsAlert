import http from 'node:http';
import crypto from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

loadDotEnv(resolve(__dirname, '.env'));

const CONFIG = {
  host: (process.env.HOST || '127.0.0.1').trim(),
  port: Number(process.env.PORT || 8787),
  backendAuthToken: (process.env.BACKEND_AUTH_TOKEN || '').trim(),
  newsApiKey: (process.env.NEWSAPI_KEY || '').trim(),
  newsCatcherKey: (process.env.NEWSCATCHER_API_KEY || '').trim(),
  guardianKey: (process.env.GUARDIAN_API_KEY || '').trim(),
  fredKey: (process.env.FRED_API_KEY || '').trim(),
  scheduleTimeZone: (process.env.BRIEFING_TIMEZONE || 'America/New_York').trim()
};

const CATEGORY_TARGETS = {
  politics: 3,
  technology: 3,
  finance: 2,
  entertainment: 1
};

const PREDICTIONS = {
  politics:
    'Likely development: negotiations widen across committees before a narrower compromise emerges.',
  technology:
    'Likely development: near-term iteration focuses on reliability and cost controls over brand-new capability.',
  finance:
    'Likely development: volatility stays elevated until the next major macro datapoint resets expectations.',
  entertainment:
    'Likely development: distribution strategy shifts toward channels with stronger week-two retention.'
};

const SLOT_HOURS = [7, 12, 19];
const SLOT_TYPE_BY_HOUR = {
  7: 'morning',
  12: 'noon',
  19: 'evening'
};

const DATA_DIRECTORY = resolve(__dirname, '.data');
const PRECOMPUTED_BRIEFINGS_FILE = resolve(DATA_DIRECTORY, 'precomputed_briefings.json');

const initialPrecomputed = loadJSONFile(PRECOMPUTED_BRIEFINGS_FILE, {});
const precomputedBriefings =
  initialPrecomputed && typeof initialPrecomputed === 'object' && !Array.isArray(initialPrecomputed)
    ? initialPrecomputed
    : {};

let precomputePromise = null;
let lastTriggeredSlotID = '';

const server = http.createServer((req, res) => {
  void handleRequest(req, res);
});

server.listen(CONFIG.port, CONFIG.host, () => {
  console.log(`NewsAlarm backend listening on http://${CONFIG.host}:${CONFIG.port}`);
  void bootstrapPrecomputeScheduler();
});

async function handleRequest(req, res) {
  const requestURL = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'OPTIONS') {
    writeJson(res, 204, {});
    return;
  }

  if (req.method === 'GET' && requestURL.pathname === '/health') {
    writeJson(res, 200, {
      ok: true,
      hasProviderKeys: {
        newsApi: Boolean(CONFIG.newsApiKey),
        newsCatcher: Boolean(CONFIG.newsCatcherKey),
        guardian: Boolean(CONFIG.guardianKey),
        fred: Boolean(CONFIG.fredKey)
      },
      scheduler: {
        timeZone: CONFIG.scheduleTimeZone,
        slots: SLOT_HOURS,
        cachedBriefings: Object.keys(precomputedBriefings).length
      },
      generatedAt: new Date().toISOString()
    });
    return;
  }

  if (req.method === 'GET' && requestURL.pathname === '/v1/briefing') {
    if (!isAuthorized(req)) {
      writeJson(res, 401, { error: 'Unauthorized' });
      return;
    }

    try {
      const requestedType = normalizeBriefingType(requestURL.searchParams.get('type'));
      const payload = await resolveBriefingResponse({ requestedType });
      writeJson(res, 200, payload);
    } catch (error) {
      console.error(error);
      writeJson(res, 500, { error: 'Failed to build briefing' });
    }
    return;
  }

  if (req.method === 'POST' && requestURL.pathname === '/v1/precompute') {
    if (!isAuthorized(req)) {
      writeJson(res, 401, { error: 'Unauthorized' });
      return;
    }

    try {
      const body = await readJsonBody(req);
      const requestedType =
        normalizeBriefingType(body?.briefingType) ||
        normalizeBriefingType(requestURL.searchParams.get('type'));
      const slot = requestedType
        ? slotForBriefingType(requestedType, new Date())
        : latestSlotOnOrBefore(new Date(), CONFIG.scheduleTimeZone);

      const entry = await precomputeAndStoreBriefing({
        slot,
        trigger: 'manual'
      });

      writeJson(res, 200, {
        ok: true,
        slotId: entry.slotId,
        briefingType: entry.briefingType,
        generatedAt: entry.generatedAt
      });
    } catch (error) {
      console.error(error);
      writeJson(res, 500, { error: 'Precompute failed.' });
    }
    return;
  }

  writeJson(res, 404, { error: 'Not found' });
}

function isAuthorized(req) {
  if (!CONFIG.backendAuthToken) {
    return true;
  }

  const value = req.headers.authorization || '';
  return value === `Bearer ${CONFIG.backendAuthToken}`;
}

function writeJson(res, statusCode, body) {
  res.statusCode = statusCode;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.end(JSON.stringify(body));
}

async function readJsonBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }

  const raw = Buffer.concat(chunks).toString('utf8').trim();
  if (!raw) {
    return {};
  }

  return JSON.parse(raw);
}

async function buildBriefingPayload() {
  const fallback = buildMockPayload();

  const [politicsCandidates, technologyCandidates, financeCandidates, entertainmentCandidates] =
    await Promise.all([
      getPoliticsCandidates(),
      getTechnologyCandidates(),
      getFinanceCandidates(),
      getEntertainmentCandidates()
    ]);

  const payload = {
    politics: selectArticles(
      CATEGORY_TARGETS.politics,
      politicsCandidates,
      fallback.politics,
      'politics'
    ),
    technology: selectArticles(
      CATEGORY_TARGETS.technology,
      technologyCandidates,
      fallback.technology,
      'technology'
    ),
    finance: selectArticles(
      CATEGORY_TARGETS.finance,
      financeCandidates,
      fallback.finance,
      'finance'
    ),
    entertainment: selectArticles(
      CATEGORY_TARGETS.entertainment,
      entertainmentCandidates,
      fallback.entertainment,
      'entertainment'
    )
  };

  validatePayload(payload);
  return payload;
}

async function getPoliticsCandidates() {
  const [guardian, newsApi, newsCatcher] = await Promise.all([
    safeFetch(() =>
      fetchGuardianArticles({
        category: 'politics',
        section: 'politics',
        query: 'government OR election OR congress',
        pageSize: 10
      })
    ),
    safeFetch(() =>
      fetchNewsApiEverything({
        category: 'politics',
        query: 'US politics OR congress OR election',
        pageSize: 20
      })
    ),
    safeFetch(() =>
      fetchNewsCatcherArticles({
        category: 'politics',
        topic: 'politics',
        query: 'government OR election'
      })
    )
  ]);

  return dedupeByTitle([...guardian, ...newsApi, ...newsCatcher]);
}

async function getTechnologyCandidates() {
  const [guardian, newsApi, newsCatcher] = await Promise.all([
    safeFetch(() =>
      fetchGuardianArticles({
        category: 'technology',
        section: 'technology',
        query: 'ai OR software OR chips',
        pageSize: 10
      })
    ),
    safeFetch(() =>
      fetchNewsApiTopHeadlines({
        category: 'technology',
        apiCategory: 'technology',
        pageSize: 20
      })
    ),
    safeFetch(() =>
      fetchNewsCatcherArticles({
        category: 'technology',
        topic: 'tech',
        query: 'AI OR cloud OR cybersecurity'
      })
    )
  ]);

  return dedupeByTitle([...guardian, ...newsApi, ...newsCatcher]);
}

async function getFinanceCandidates() {
  const [guardian, newsApi, newsCatcher, fredSnapshot] = await Promise.all([
    safeFetch(() =>
      fetchGuardianArticles({
        category: 'finance',
        section: 'business',
        query: 'markets OR inflation OR rates',
        pageSize: 10
      })
    ),
    safeFetch(() =>
      fetchNewsApiTopHeadlines({
        category: 'finance',
        apiCategory: 'business',
        pageSize: 20
      })
    ),
    safeFetch(() =>
      fetchNewsCatcherArticles({
        category: 'finance',
        topic: 'finance',
        query: 'markets OR inflation OR earnings'
      })
    ),
    safeFetch(() => fetchFredSnapshot())
  ]);

  return dedupeByTitle([...guardian, ...newsApi, ...newsCatcher, ...fredSnapshot]);
}

async function getEntertainmentCandidates() {
  const [guardian, newsApi, newsCatcher] = await Promise.all([
    safeFetch(() =>
      fetchGuardianArticles({
        category: 'entertainment',
        section: 'culture',
        query: 'film OR streaming OR music',
        pageSize: 10
      })
    ),
    safeFetch(() =>
      fetchNewsApiTopHeadlines({
        category: 'entertainment',
        apiCategory: 'entertainment',
        pageSize: 20
      })
    ),
    safeFetch(() =>
      fetchNewsCatcherArticles({
        category: 'entertainment',
        topic: 'entertainment',
        query: 'streaming OR film OR music'
      })
    )
  ]);

  return dedupeByTitle([...guardian, ...newsApi, ...newsCatcher]);
}

async function fetchNewsApiTopHeadlines({ category, apiCategory, pageSize }) {
  if (!CONFIG.newsApiKey) {
    return [];
  }

  const endpoint = new URL('https://newsapi.org/v2/top-headlines');
  endpoint.searchParams.set('language', 'en');
  endpoint.searchParams.set('category', apiCategory);
  endpoint.searchParams.set('pageSize', String(pageSize));
  endpoint.searchParams.set('apiKey', CONFIG.newsApiKey);

  const data = await fetchJSON(endpoint.toString());
  const articles = Array.isArray(data.articles) ? data.articles : [];

  return articles
    .map((item) => {
      const title = toNonEmpty(item?.title);
      if (!title) {
        return null;
      }

      return createArticle({
        category,
        title,
        source: toNonEmpty(item?.source?.name) || 'NewsAPI',
        summary: condensedSummary([item?.description, item?.content]),
        url: normalizeURL(item?.url)
      });
    })
    .filter(Boolean);
}

async function fetchNewsApiEverything({ category, query, pageSize }) {
  if (!CONFIG.newsApiKey) {
    return [];
  }

  const endpoint = new URL('https://newsapi.org/v2/everything');
  endpoint.searchParams.set('q', query);
  endpoint.searchParams.set('language', 'en');
  endpoint.searchParams.set('sortBy', 'publishedAt');
  endpoint.searchParams.set('pageSize', String(pageSize));
  endpoint.searchParams.set('apiKey', CONFIG.newsApiKey);

  const data = await fetchJSON(endpoint.toString());
  const articles = Array.isArray(data.articles) ? data.articles : [];

  return articles
    .map((item) => {
      const title = toNonEmpty(item?.title);
      if (!title) {
        return null;
      }

      return createArticle({
        category,
        title,
        source: toNonEmpty(item?.source?.name) || 'NewsAPI',
        summary: condensedSummary([item?.description, item?.content]),
        url: normalizeURL(item?.url)
      });
    })
    .filter(Boolean);
}

async function fetchGuardianArticles({ category, section, query, pageSize }) {
  if (!CONFIG.guardianKey) {
    return [];
  }

  const endpoint = new URL('https://content.guardianapis.com/search');
  endpoint.searchParams.set('section', section);
  endpoint.searchParams.set('q', query);
  endpoint.searchParams.set('show-fields', 'trailText,bodyText');
  endpoint.searchParams.set('page-size', String(pageSize));
  endpoint.searchParams.set('api-key', CONFIG.guardianKey);

  const data = await fetchJSON(endpoint.toString());
  const results = Array.isArray(data?.response?.results) ? data.response.results : [];

  return results
    .map((item) => {
      const title = toNonEmpty(item?.webTitle);
      if (!title) {
        return null;
      }

      return createArticle({
        category,
        title,
        source: 'The Guardian',
        summary: condensedSummary([
          stripHTML(item?.fields?.trailText),
          toNonEmpty(item?.fields?.bodyText)
        ]),
        url: normalizeURL(item?.webUrl)
      });
    })
    .filter(Boolean);
}

async function fetchNewsCatcherArticles({ category, topic, query }) {
  if (!CONFIG.newsCatcherKey) {
    return [];
  }

  const v3Result = await safeFetch(() => fetchNewsCatcherV3({ category, topic, query }));
  if (v3Result.length > 0) {
    return v3Result;
  }

  return safeFetch(() => fetchNewsCatcherV2({ category, topic, query }));
}

async function fetchNewsCatcherV3({ category, topic, query }) {
  const endpoint = new URL('https://v3-api.newscatcherapi.com/api/latest_headlines');
  endpoint.searchParams.set('lang', 'en');
  endpoint.searchParams.set('topic', topic);
  endpoint.searchParams.set('q', query);
  endpoint.searchParams.set('page_size', '25');

  const data = await fetchJSON(endpoint.toString(), {
    headers: { 'x-api-token': CONFIG.newsCatcherKey }
  });

  return mapNewsCatcherArticles({ category, data });
}

async function fetchNewsCatcherV2({ category, topic, query }) {
  const endpoint = new URL('https://api.newscatcherapi.com/v2/latest_headlines');
  endpoint.searchParams.set('lang', 'en');
  endpoint.searchParams.set('topic', topic);
  endpoint.searchParams.set('q', query);
  endpoint.searchParams.set('page_size', '25');

  const data = await fetchJSON(endpoint.toString(), {
    headers: { 'x-api-key': CONFIG.newsCatcherKey }
  });

  return mapNewsCatcherArticles({ category, data });
}

function mapNewsCatcherArticles({ category, data }) {
  const articles = Array.isArray(data.articles) ? data.articles : [];

  return articles
    .map((item) => {
      const title = toNonEmpty(item?.title);
      if (!title) {
        return null;
      }

      return createArticle({
        category,
        title,
        source:
          toNonEmpty(item?.source) ||
          toNonEmpty(item?.clean_url) ||
          toNonEmpty(item?.cleanURL) ||
          'NewsCatcher',
        summary: condensedSummary([item?.summary, item?.excerpt, item?.snippet]),
        url: normalizeURL(item?.link || item?.url)
      });
    })
    .filter(Boolean);
}

async function fetchFredSnapshot() {
  if (!CONFIG.fredKey) {
    return [];
  }

  const [tenYear, unemployment] = await Promise.all([
    fetchFredLatestValue('DGS10'),
    fetchFredLatestValue('UNRATE')
  ]);

  if (!tenYear || !unemployment) {
    return [];
  }

  return [
    createArticle({
      category: 'finance',
      title: 'US Macro Snapshot: Rates and Labor',
      source: 'FRED (St. Louis Fed)',
      summary: condensedSummary([
        `10Y Treasury: ${tenYear.value}% (${tenYear.date}).`,
        `Unemployment rate: ${unemployment.value}% (${unemployment.date}).`
      ]),
      url: 'https://fred.stlouisfed.org/'
    })
  ];
}

async function fetchFredLatestValue(seriesId) {
  const endpoint = new URL('https://api.stlouisfed.org/fred/series/observations');
  endpoint.searchParams.set('series_id', seriesId);
  endpoint.searchParams.set('api_key', CONFIG.fredKey);
  endpoint.searchParams.set('file_type', 'json');
  endpoint.searchParams.set('sort_order', 'desc');
  endpoint.searchParams.set('limit', '10');

  const data = await fetchJSON(endpoint.toString());
  const observations = Array.isArray(data.observations) ? data.observations : [];
  const valid = observations.find((item) => item?.value && item.value !== '.');

  if (!valid) {
    return null;
  }

  return {
    date: String(valid.date),
    value: String(valid.value)
  };
}

async function fetchJSON(url, { headers = {} } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);

  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        ...headers
      },
      signal: controller.signal
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    return await response.json();
  } finally {
    clearTimeout(timer);
  }
}

async function safeFetch(work) {
  try {
    return await work();
  } catch {
    return [];
  }
}

function selectArticles(targetCount, candidates, fallback, category) {
  const selected = [];
  const seen = new Set();

  for (const article of candidates) {
    if (article.category !== category) {
      continue;
    }

    const key = normalizeTitle(article.title);
    if (!key || seen.has(key)) {
      continue;
    }

    seen.add(key);
    selected.push(article);
    if (selected.length === targetCount) {
      return selected;
    }
  }

  for (const article of fallback) {
    const key = normalizeTitle(article.title);
    if (!key || seen.has(key)) {
      continue;
    }

    seen.add(key);
    selected.push(article);
    if (selected.length === targetCount) {
      return selected;
    }
  }

  return selected.slice(0, targetCount);
}

function dedupeByTitle(articles) {
  const output = [];
  const seen = new Set();

  for (const article of articles) {
    const key = normalizeTitle(article.title);
    if (!key || seen.has(key)) {
      continue;
    }

    seen.add(key);
    output.push(article);
  }

  return output;
}

function normalizeTitle(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function condensedSummary(parts) {
  const joined = parts
    .map((part) => toNonEmpty(part))
    .filter(Boolean)
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (!joined) {
    return 'Key points are still loading from this source.';
  }

  return joined.slice(0, 280);
}

function stripHTML(value) {
  return String(value || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function toNonEmpty(value) {
  const trimmed = String(value || '').trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeURL(value) {
  const raw = toNonEmpty(value);
  if (!raw) {
    return null;
  }

  try {
    return new URL(raw).toString();
  } catch {
    return null;
  }
}

function createArticle({ category, title, source, summary, url }) {
  return {
    id: crypto.randomUUID(),
    category,
    title,
    source,
    summary,
    aiPrediction: PREDICTIONS[category],
    url: normalizeURL(url)
  };
}

async function resolveBriefingResponse({ requestedType = null } = {}) {
  const now = new Date();
  const slot = requestedType
    ? slotForBriefingType(requestedType, now)
    : latestSlotOnOrBefore(now, CONFIG.scheduleTimeZone);

  let entry = precomputedBriefings[slot.slotId];
  if (!entry) {
    entry = await precomputeAndStoreBriefing({
      slot,
      trigger: 'on-demand'
    });
  }

  return {
    ...entry.payload,
    briefingType: entry.briefingType,
    slotId: entry.slotId,
    generatedAt: entry.generatedAt,
    source: 'precomputed'
  };
}

async function bootstrapPrecomputeScheduler() {
  try {
    await ensureLatestSlotPrecomputed('startup');
  } catch (error) {
    console.error('Initial precompute failed:', error);
  }

  const timer = setInterval(() => {
    void schedulerTick();
  }, 30_000);
  timer.unref?.();
}

async function schedulerTick() {
  try {
    const now = new Date();
    const exactSlot = exactSlotAt(now, CONFIG.scheduleTimeZone);

    if (exactSlot && exactSlot.slotId !== lastTriggeredSlotID) {
      lastTriggeredSlotID = exactSlot.slotId;
      await precomputeAndStoreBriefing({
        slot: exactSlot,
        trigger: 'scheduled'
      });
      return;
    }

    await ensureLatestSlotPrecomputed('catch-up');
  } catch (error) {
    console.error('Scheduler tick failed:', error);
  }
}

async function ensureLatestSlotPrecomputed(trigger) {
  const slot = latestSlotOnOrBefore(new Date(), CONFIG.scheduleTimeZone);
  if (!precomputedBriefings[slot.slotId]) {
    await precomputeAndStoreBriefing({ slot, trigger });
  }
}

async function precomputeAndStoreBriefing({ slot, trigger }) {
  if (precomputePromise) {
    return precomputePromise;
  }

  precomputePromise = (async () => {
    const payload = await buildBriefingPayload();
    const generatedAt = new Date().toISOString();
    const entry = {
      slotId: slot.slotId,
      briefingType: slot.briefingType,
      generatedAt,
      payload
    };

    precomputedBriefings[slot.slotId] = entry;
    trimPrecomputedCache(12);
    persistPrecomputedBriefings();

    console.log(
      `Precomputed ${slot.briefingType} briefing for slot ${slot.slotId} (${trigger})`
    );

    return entry;
  })().finally(() => {
    precomputePromise = null;
  });

  return precomputePromise;
}

function latestSlotOnOrBefore(date, timeZone) {
  const parts = getZonedDateParts(date, timeZone);
  const hour = Number(parts.hour);

  if (hour >= 19) {
    return makeSlotInfo(parts, 19);
  }
  if (hour >= 12) {
    return makeSlotInfo(parts, 12);
  }
  if (hour >= 7) {
    return makeSlotInfo(parts, 7);
  }

  const previousDay = new Date(date.getTime() - 24 * 60 * 60 * 1000);
  const previousParts = getZonedDateParts(previousDay, timeZone);
  return makeSlotInfo(previousParts, 19);
}

function slotForBriefingType(type, date, timeZone = CONFIG.scheduleTimeZone) {
  const hour = type === 'morning' ? 7 : type === 'noon' ? 12 : 19;
  const parts = getZonedDateParts(date, timeZone);
  return makeSlotInfo(parts, hour);
}

function exactSlotAt(date, timeZone) {
  const parts = getZonedDateParts(date, timeZone);
  const hour = Number(parts.hour);
  const minute = Number(parts.minute);
  if (minute !== 0 || !SLOT_HOURS.includes(hour)) {
    return null;
  }
  return makeSlotInfo(parts, hour);
}

function makeSlotInfo(parts, hour) {
  const dayKey = `${parts.year}-${parts.month}-${parts.day}`;
  return {
    slotId: `${dayKey}-${hour}`,
    briefingType: SLOT_TYPE_BY_HOUR[hour],
    hour
  };
}

function getZonedDateParts(date, timeZone) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });

  const values = {};
  for (const part of formatter.formatToParts(date)) {
    if (part.type !== 'literal') {
      values[part.type] = part.value;
    }
  }

  return values;
}

function normalizeBriefingType(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'morning' || normalized === 'noon' || normalized === 'evening') {
    return normalized;
  }
  return null;
}

function persistPrecomputedBriefings() {
  writeJSONFile(PRECOMPUTED_BRIEFINGS_FILE, precomputedBriefings);
}

function trimPrecomputedCache(limit) {
  const keys = Object.keys(precomputedBriefings).sort();
  while (keys.length > limit) {
    const key = keys.shift();
    delete precomputedBriefings[key];
  }
}

function loadJSONFile(path, fallback) {
  if (!existsSync(path)) {
    return fallback;
  }

  try {
    const text = readFileSync(path, 'utf8');
    const parsed = JSON.parse(text);
    return parsed ?? fallback;
  } catch {
    return fallback;
  }
}

function writeJSONFile(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(value, null, 2));
}

function validatePayload(payload) {
  const matches =
    payload.politics.length === CATEGORY_TARGETS.politics &&
    payload.technology.length === CATEGORY_TARGETS.technology &&
    payload.finance.length === CATEGORY_TARGETS.finance &&
    payload.entertainment.length === CATEGORY_TARGETS.entertainment &&
    payload.politics.every((item) => item.category === 'politics') &&
    payload.technology.every((item) => item.category === 'technology') &&
    payload.finance.every((item) => item.category === 'finance') &&
    payload.entertainment.every((item) => item.category === 'entertainment');

  if (!matches) {
    throw new Error('Invalid payload shape');
  }
}

function buildMockPayload() {
  return {
    politics: [
      createArticle({
        category: 'politics',
        title: 'Fallback: Senate Budget Timeline Narrows',
        source: 'NewsAlarm Fallback',
        summary: 'Temporary fallback article used when external APIs fail.',
        url: null
      }),
      createArticle({
        category: 'politics',
        title: 'Fallback: Election Procedure Hearings Expand',
        source: 'NewsAlarm Fallback',
        summary: 'Temporary fallback article used when external APIs fail.',
        url: null
      }),
      createArticle({
        category: 'politics',
        title: 'Fallback: Trade Policy Panel Schedules Review',
        source: 'NewsAlarm Fallback',
        summary: 'Temporary fallback article used when external APIs fail.',
        url: null
      })
    ],
    technology: [
      createArticle({
        category: 'technology',
        title: 'Fallback: On-Device AI Rollout Continues',
        source: 'NewsAlarm Fallback',
        summary: 'Temporary fallback article used when external APIs fail.',
        url: null
      }),
      createArticle({
        category: 'technology',
        title: 'Fallback: Cloud Spend Governance Tightens',
        source: 'NewsAlarm Fallback',
        summary: 'Temporary fallback article used when external APIs fail.',
        url: null
      }),
      createArticle({
        category: 'technology',
        title: 'Fallback: Package Signing Adoption Increases',
        source: 'NewsAlarm Fallback',
        summary: 'Temporary fallback article used when external APIs fail.',
        url: null
      })
    ],
    finance: [
      createArticle({
        category: 'finance',
        title: 'Fallback: Rate Volatility Monitored by Lenders',
        source: 'NewsAlarm Fallback',
        summary: 'Temporary fallback article used when external APIs fail.',
        url: null
      }),
      createArticle({
        category: 'finance',
        title: 'Fallback: Consumer Value Shift Holds',
        source: 'NewsAlarm Fallback',
        summary: 'Temporary fallback article used when external APIs fail.',
        url: null
      })
    ],
    entertainment: [
      createArticle({
        category: 'entertainment',
        title: 'Fallback: Streaming Window Strategy Evolves',
        source: 'NewsAlarm Fallback',
        summary: 'Temporary fallback article used when external APIs fail.',
        url: null
      })
    ]
  };
}

function loadDotEnv(filePath) {
  if (!existsSync(filePath)) {
    return;
  }

  const text = readFileSync(filePath, 'utf8');
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }

    const separator = line.indexOf('=');
    if (separator <= 0) {
      continue;
    }

    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}
