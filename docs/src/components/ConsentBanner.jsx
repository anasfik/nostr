import React, {useEffect, useState} from 'react';
import {readConsent, writeConsent, updateArgs} from '../consent.cjs';
import styles from './ConsentBanner.module.css';

// Fixed bottom bar. Visible by default (SSR included) so the choice is
// offered before any grant; hides after a stored decision is read.
export default function ConsentBanner() {
  const [visible, setVisible] = useState(true);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (readConsent(window.localStorage) !== null) {
      setVisible(false);
    }
  }, []);

  function choose(value) {
    writeConsent(window.localStorage, value);
    if (typeof window.gtag === 'function') {
      window.gtag(...updateArgs(value));
    }
    setSaved(true);
    setVisible(false);
  }

  if (!visible) {
    return null;
  }

  return (
    <section aria-label="Analytics consent" className={styles.bar}>
      <p className={styles.text}>
        Anonymous usage analytics are off unless you accept.
      </p>
      <details className={styles.details}>
        <summary>What changes if I accept</summary>
        <ul>
          <li>No cookies or storage until you accept.</li>
          <li>Accepting records this choice and allows page-view counts.</li>
          <li>Rejecting keeps every analytics default denied.</li>
          <li>Never collected: keys, events, relay URLs or form input.</li>
        </ul>
      </details>
      <div className={styles.actions}>
        <button type="button" onClick={() => choose('granted')}>Accept</button>
        <button type="button" onClick={() => choose('rejected')}>Reject</button>
      </div>
      {saved ? (
        <p aria-live="polite" className={styles.text}>Preference saved.</p>
      ) : null}
    </section>
  );
}
