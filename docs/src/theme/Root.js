import React from 'react';
import ConsentBanner from '../components/ConsentBanner';

// Mounts the analytics consent bar on every route, including docs pages
// and the search utility. No route changes, no new dependency.
export default function Root({children}) {
  return (
    <>
      <ConsentBanner />
      {children}
    </>
  );
}
