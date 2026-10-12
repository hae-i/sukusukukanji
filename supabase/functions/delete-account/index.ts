import { createClient } from 'npm:@supabase/supabase-js@2';

// JWTs are validated against Auth here, including when the gateway uses the new
// signing keys. The authenticated user is the only deletion authority.
Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response(null, { status: 405 });
  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return new Response(null, { status: 401 });
  const url = Deno.env.get('SUPABASE_URL')!;
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    const { data: { user }, error } = await admin.auth.getUser(authorization.slice(7));
    if (error || !user) return new Response(null, { status: 401 });
    const body = await request.json();
    if (body.expectedUserId !== user.id) return new Response(null, { status: 409 });
    const deletion = await admin.auth.admin.deleteUser(user.id);
    if (deletion.error) return new Response(null, { status: 500 });
    // auth.users FK deletes this user's backup in the same database.
    return Response.json({ deleted: true });
  } catch (_) {
    return new Response(null, { status: 500 });
  }
});
