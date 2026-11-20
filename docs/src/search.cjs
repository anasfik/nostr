function normalizeQuery(query) {
  return String(query ?? '').trim().slice(0, 120);
}

function searchable(text) {
  return text.toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
}

function searchDocs(items, query) {
  const terms = normalizeQuery(query).split(/\s+/).map(searchable).filter(Boolean);
  if (!terms.length) return [];
  return items.filter(item => {
    const text = searchable(`${item.title} ${item.description} ${item.permalink}`);
    return terms.every(term => text.includes(term));
  }).slice(0, 20);
}

module.exports = {normalizeQuery, searchDocs};
