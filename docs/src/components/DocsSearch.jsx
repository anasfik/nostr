import React, {useEffect, useState} from 'react';
import Layout from '@theme/Layout';
import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';
import {useHistory, useLocation} from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';
import {normalizeQuery, searchDocs} from '../search.cjs';
import styles from './DocsSearch.module.css';

export default function DocsSearch({items}) {
  const history = useHistory();
  const location = useLocation();
  const action = useBaseUrl('/search/');
  const [query, setQuery] = useState('');
  const [input, setInput] = useState('');
  useEffect(() => {
    const next = normalizeQuery(new URLSearchParams(location.search).get('q'));
    setQuery(next);
    setInput(next);
  }, [location.search]);
  const results = searchDocs(items, query);

  function submit(event) {
    event.preventDefault();
    const next = normalizeQuery(input);
    history.push({pathname: action, search: next ? `?q=${encodeURIComponent(next)}` : ''});
  }

  return (
    <Layout title="Search the documentation" description="Find dart_nostr guides by topic, capability or identifier.">
      <Head><meta name="robots" content="noindex, follow" /><meta name="referrer" content="same-origin" /></Head>
      <main className={styles.search}>
        <h1>Find the guide you need.</h1>
        <p className={styles.lead}>Find guides by title, summary or topic. Matching runs locally; your query is saved in the URL. Never enter private keys or secrets.</p>
        <form action={action} method="get" onSubmit={submit} role="search" aria-label="Documentation">
          <label htmlFor="docs-query">Topic or capability</label>
          <div className={styles.controls}>
            <input id="docs-query" name="q" type="search" maxLength={120} autoComplete="off" value={input} onChange={event => setInput(event.target.value)} aria-describedby="search-hint" />
            <button type="submit">Search guides</button>
          </div>
          <p id="search-hint" className={styles.hint}>Try “relay”, “keys”, “nip19” or “failure”.</p>
        </form>
        <noscript><p>Search needs JavaScript. You can still browse the guides below.</p></noscript>
        <p role="status" aria-live="polite" aria-atomic="true">{query ? `${results.length} ${results.length === 1 ? 'guide' : 'guides'} found for “${query}”.` : 'Choose a topic to search the documentation.'}</p>
        {query && <Link to="/search/" className={styles.clear}>Clear search</Link>}
        {results.length > 0 && <ul className={styles.results}>{results.map(item => (
          <li key={item.permalink}><Link to={item.permalink}>{item.title}</Link><p>{item.description}</p></li>
        ))}</ul>}
        {query && results.length === 0 && <section className={styles.empty}><h2>Try a broader topic.</h2><p>Use “relay” instead of a relay URL, or browse the documentation below.</p></section>}
        <nav className={styles.startingPoints} aria-label="Documentation starting points">
          <Link to="/docs/quick-start/">Quick start</Link>
          <Link to="/docs/usage/keys-management/">Keys and identity</Link>
          <Link to="/docs/usage/advanced/error-handling/">Typed failures</Link>
          <Link to="/docs/">Browse all guides</Link>
        </nav>
      </main>
    </Layout>
  );
}
