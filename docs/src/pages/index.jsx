import React from 'react';
import Layout from '@theme/Layout';
import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';
import CodeBlock from '@theme/CodeBlock';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import styles from './index.module.css';

const example = `import 'package:dart_nostr/dart_nostr.dart';

final nostr = Nostr();
final connected = await nostr.connect([
  'wss://relay.damus.io',
]);

if (connected.isSuccess) {
  final event = NostrEvent.fromPartialData(
    kind: 1,
    content: 'Hello, Nostr.',
    keyPairs: nostr.keys.generateKeyPair(),
  );
  final result = await nostr.publish(event);
  result.fold(
    (ok) => print(ok.isEventAccepted),
    (error) => print(error.message),
  );
}
await nostr.disconnect();`;

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  const playgroundUrl = siteConfig.baseUrl === '/' ? '/playground/' : 'https://nostr.gwhyyy.com/playground/';
  return (
    <Layout title="Nostr SDK for Dart & Flutter" description="Build Nostr apps with dart_nostr. Connect to relays, sign and publish events, and subscribe to streams from Dart and Flutter.">
      <Head>
        <script type="application/ld+json">{JSON.stringify({
          '@context': 'https://schema.org', '@type': 'SoftwareSourceCode',
          name: 'dart_nostr', description: 'An open-source Nostr SDK for Dart and Flutter.',
          codeRepository: 'https://github.com/anasfik/nostr',
          programmingLanguage: 'Dart', runtimePlatform: 'Dart and Flutter',
          license: 'https://github.com/anasfik/nostr/blob/main/LICENSE',
          author: {'@type': 'Person', name: 'Anas Fikhi', url: 'https://gwhyyy.com'},
        })}</script>
      </Head>
      <main className={styles.landing}>
        <section className={styles.hero} aria-labelledby="intro">
          <div className={styles.heroCopy}>
            <p className={styles.eyebrow}>dart_nostr / Dart + Flutter</p>
            <h1 id="intro">Build Nostr apps.<br /><span>Keep your Dart.</span></h1>
            <p className={styles.lead}>Connect to relays, publish signed events, and subscribe to streams with one Dart and Flutter SDK.</p>
            <div className={styles.actions}>
              <a className={styles.primary} href={playgroundUrl}>Try it in real time <span aria-hidden="true">↗</span></a>
              <Link className={styles.secondary} to="/docs/quick-start/">Quick start <span aria-hidden="true">↗</span></Link>
            </div>
          </div>
          <div className={styles.protocol} role="img" aria-label="Your Dart or Flutter app uses dart_nostr to manage keys, events and subscriptions across your chosen Nostr relays.">
            <div className={styles.protocolTitle}>Your app, on Nostr</div>
            <div className={styles.appNode}>Dart / Flutter</div>
            <div className={styles.connector} aria-hidden="true">↓</div>
            <div className={styles.sdkNode}><strong>dart_nostr</strong><span>Keys · events · subscriptions</span></div>
            <div className={styles.connector} aria-hidden="true">↓</div>
            <div className={styles.relayNodes}><span>Relay A</span><span>Relay B</span><span>Relay C</span></div>
            <p>A shared protocol. Your choice of relays.</p>
          </div>
        </section>

        <section className={styles.install} aria-label="Install dart_nostr">
          <div><strong>Start in your project.</strong><span>pub.dev: 10.0.1. These guides preview 11.0.0.</span></div>
          <CodeBlock language="bash">flutter pub add dart_nostr</CodeBlock>
          <Link to="/docs/installation/">Install the preview <span aria-hidden="true">↗</span></Link>
        </section>

        <section className={styles.codeSection} aria-labelledby="publish">
          <div className={styles.codeIntro}>
            <h2 id="publish">From an idea<br />to a signed event.</h2>
            <p>Use the same package in a Flutter interface, a Dart service, or a command-line tool.</p>
            <dl className={styles.steps}>
              <div><dt>01 / Connect</dt><dd>Choose the relays your app talks to.</dd></div>
              <div><dt>02 / Publish</dt><dd>Create an event and inspect the relay receipt.</dd></div>
              <div><dt>03 / Handle results</dt><dd>Branch on typed success and failure values.</dd></div>
            </dl>
            <p className={styles.note}>Illustrative snippet. Publishing sends a public event. The quick start covers connection errors and subscription cleanup.</p>
            <Link to="/docs/quick-start/">Quick start <span aria-hidden="true">↗</span></Link>
          </div>
          <div className={styles.code}><CodeBlock language="dart" title="A first public note · 11.0.0 source preview">{example}</CodeBlock></div>
        </section>

        <section className={styles.guides} aria-labelledby="guides">
          <h2 id="guides">Follow the part you need.</h2>
          <div className={styles.guideRows}>
            <Link to="/docs/usage/relays-and-events/connecting-to-relays/"><span>Relay connections</span><p>Connect, reconnect, and manage the transport lifecycle.</p><span aria-hidden="true">↗</span></Link>
            <Link to="/docs/usage/keys-management/"><span>Keys & identity</span><p>Generate key pairs and work with Nostr identities.</p><span aria-hidden="true">↗</span></Link>
            <Link to="/docs/usage/relays-and-events/subscribing-to-events/"><span>Event streams</span><p>Filter subscriptions and close them when your app is done.</p><span aria-hidden="true">↗</span></Link>
            <Link to="/docs/usage/advanced/error-handling/"><span>Typed failures</span><p>Handle NostrResult values explicitly in your application.</p><span aria-hidden="true">↗</span></Link>
          </div>
        </section>

        <section className={styles.openSource} aria-labelledby="open-source">
          <h2 id="open-source">Read it. Build with it. Improve it.</h2>
          <p>Maintained by <a href="https://gwhyyy.com">Anas Fikhi</a>. Explore the implementation, report an issue, or contribute a change.</p>
          <div className={styles.actions}>
            <Link className={styles.primary} href="https://pub.dev/packages/dart_nostr">Get the package <span aria-hidden="true">↗</span></Link>
            <Link className={styles.secondary} href="https://github.com/anasfik/nostr">View source <span aria-hidden="true">↗</span></Link>
          </div>
        </section>
      </main>
    </Layout>
  );
}
