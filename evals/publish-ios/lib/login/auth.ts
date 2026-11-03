const SIGN_IN_URL = 'https://example.com/api/sign-in';

export async function signIn(email: string, password: string): Promise<string> {
  const response = await fetch(SIGN_IN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!response.ok) throw new Error(`Sign-in failed: ${response.status}`);
  const body: { sessionToken: string } = await response.json();
  return body.sessionToken;
}
