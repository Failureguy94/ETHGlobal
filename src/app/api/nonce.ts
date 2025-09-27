import { cookies } from "next/headers";
import { NextRequest, NextResponse } from "next/server";

export async function GET(req: NextRequest) {
  // Expects only alphanumeric characters
  const nonce = crypto.randomUUID().replace(/-/g, "");

  // The nonce should be stored somewhere that is not tamperable by the client
  // Optionally you can HMAC the nonce with a secret key stored in your environment
  // The nonce should be stored somewhere that is not tamperable by the client
  // Optionally you can HMAC the nonce with a secret key stored in your environment
  const cookieStore = await cookies();
  cookieStore.set("siwe", nonce, { secure: true });
  return NextResponse.json({ nonce });
}