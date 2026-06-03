/*
 * Pure ArkTS MD5 implementation — no external dependencies.
 * Reference: RFC 1321
 */

// Per-round shift amounts
const S: number[] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
]

// Pre-computed table: T[i] = floor(abs(sin(i+1)) * 2^32)
const K: number[] = [
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
  0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
  0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
  0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
  0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
  0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
  0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
  0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
  0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
  0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
  0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
  0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
  0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
  0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
  0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
]

function safeAdd(x: number, y: number): number {
  const lsw = (x & 0xffff) + (y & 0xffff)
  const msw = (x >> 16) + (y >> 16) + (lsw >> 16)
  return (msw << 16) | (lsw & 0xffff)
}

function rotateLeft(x: number, n: number): number {
  return (x << n) | (x >>> (32 - n))
}

function md5Round(a: number, b: number, c: number, d: number,
  x: number, s: number, t: number, f: number): number {
  return safeAdd(rotateLeft(safeAdd(safeAdd(a, f), safeAdd(x, t)), s), b)
}

function stringToWords(str: string): number[] {
  const bytes: number[] = []
  for (let i = 0; i < str.length; i++) {
    const code = str.charCodeAt(i)
    if (code < 0x80) {
      bytes.push(code)
    } else if (code < 0x800) {
      bytes.push(0xc0 | (code >> 6))
      bytes.push(0x80 | (code & 0x3f))
    } else {
      bytes.push(0xe0 | (code >> 12))
      bytes.push(0x80 | ((code >> 6) & 0x3f))
      bytes.push(0x80 | (code & 0x3f))
    }
  }

  const bitLen = bytes.length * 8
  bytes.push(0x80)
  while (bytes.length % 64 !== 56) {
    bytes.push(0)
  }
  // Append original bit length as 64-bit little-endian
  for (let i = 0; i < 8; i++) {
    bytes.push((bitLen >>> (i * 8)) & 0xff)
  }

  const words: number[] = []
  for (let i = 0; i < bytes.length; i += 4) {
    words.push(
      (bytes[i]) |
      ((bytes[i + 1] ?? 0) << 8) |
      ((bytes[i + 2] ?? 0) << 16) |
      ((bytes[i + 3] ?? 0) << 24)
    )
  }
  return words
}

function wordToHex(val: number): string {
  const hex = '0123456789abcdef'
  let result = ''
  for (let i = 0; i < 4; i++) {
    const byte = (val >>> (i * 8)) & 0xff
    result += hex.charAt((byte >> 4) & 0xf) + hex.charAt(byte & 0xf)
  }
  return result
}

export function md5(input: string): string {
  const M = stringToWords(input)

  let a0 = 0x67452301
  let b0 = 0xefcdab89
  let c0 = 0x98badcfe
  let d0 = 0x10325476

  for (let chunk = 0; chunk < M.length; chunk += 16) {
    let A = a0
    let B = b0
    let C = c0
    let D = d0

    for (let i = 0; i < 64; i++) {
      let F = 0
      let g = 0
      if (i < 16) {
        F = (B & C) | (~B & D)
        g = i
      } else if (i < 32) {
        F = (D & B) | (~D & C)
        g = (5 * i + 1) % 16
      } else if (i < 48) {
        F = B ^ C ^ D
        g = (3 * i + 5) % 16
      } else {
        F = C ^ (B | ~D)
        g = (7 * i) % 16
      }
      const temp = D
      D = C
      C = B
      B = md5Round(A, B, C, D, M[chunk + g] ?? 0, S[i], K[i], F)
      A = temp
    }

    a0 = safeAdd(a0, A)
    b0 = safeAdd(b0, B)
    c0 = safeAdd(c0, C)
    d0 = safeAdd(d0, D)
  }

  return wordToHex(a0) + wordToHex(b0) + wordToHex(c0) + wordToHex(d0)
}
