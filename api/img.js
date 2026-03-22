export default async function handler(req) {
  const url = new URL(req.url);
  const path = url.searchParams.get('u');
  if (!path) {
    return new Response('Missing u param', { status: 400 });
  }

  const imageUrl = `https://toolorkg.com/wp-content/uploads/${path}`;

  try {
    const res = await fetch(imageUrl);
    if (!res.ok) {
      return new Response('Image not found', { status: 404 });
    }

    const contentType = res.headers.get('content-type') || 'image/jpeg';
    const body = await res.arrayBuffer();

    return new Response(body, {
      status: 200,
      headers: {
        'Content-Type': contentType,
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=86400, s-maxage=604800',
      },
    });
  } catch (e) {
    return new Response('Fetch failed', { status: 500 });
  }
}

export const config = { runtime: 'edge' };
