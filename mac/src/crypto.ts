import sodium from "libsodium-wrappers";

export const NONCE_SENTINEL_B64 = Buffer.from("sealed-box-no-nonce").toString("base64");

let ready = false;

export async function initCrypto(): Promise<void> {
  if (!ready) {
    await sodium.ready;
    ready = true;
  }
}

export function generateKeypair(): { publicKey: Uint8Array; privateKey: Uint8Array } {
  const kp = sodium.crypto_box_keypair();
  return { publicKey: kp.publicKey, privateKey: kp.privateKey };
}

export function encryptForDevice(
  plaintext: string,
  recipientPubKey: Uint8Array
): { ciphertext_b64: string; nonce: string } {
  const message = sodium.from_string(plaintext);
  const ciphertext = sodium.crypto_box_seal(message, recipientPubKey);
  return {
    ciphertext_b64: sodium.to_base64(ciphertext, sodium.base64_variants.ORIGINAL),
    nonce: NONCE_SENTINEL_B64,
  };
}

export function decryptFromDevice(
  ciphertext_b64: string,
  publicKey: Uint8Array,
  privateKey: Uint8Array
): string {
  const ciphertext = sodium.from_base64(ciphertext_b64, sodium.base64_variants.ORIGINAL);
  const plaintext = sodium.crypto_box_seal_open(ciphertext, publicKey, privateKey);
  return sodium.to_string(plaintext);
}

export function pubKeyFromB64(b64: string): Uint8Array {
  return sodium.from_base64(b64, sodium.base64_variants.ORIGINAL);
}

export function toB64(data: Uint8Array): string {
  return sodium.to_base64(data, sodium.base64_variants.ORIGINAL);
}

export function fromB64(b64: string): Uint8Array {
  return sodium.from_base64(b64, sodium.base64_variants.ORIGINAL);
}
