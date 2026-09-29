const SITE = 'https://hackman.kr';

export async function GET(): Promise<Response> {
  const res = await fetch(
    `${process.env.VITE_SUPABASE_URL}/rest/v1/contests?in_sitemap=eq.true&select=slug,updated_at`,
    { headers: { apikey: process.env.VITE_SUPABASE_ANON_KEY! } }
  );
  const rows: { slug: string; updated_at: string }[] = res.ok ? await res.json() : [];
  const urls = [
    `<url><loc>${SITE}/</loc></url>`,
    ...rows.map(
      (c) => `<url><loc>${SITE}/c/${encodeURIComponent(c.slug)}</loc><lastmod>${c.updated_at.slice(0, 10)}</lastmod></url>`
    ),
  ];
  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>\n`;
  return new Response(xml, {
    headers: { 'content-type': 'application/xml', 'cache-control': 's-maxage=3600' },
  });
}
