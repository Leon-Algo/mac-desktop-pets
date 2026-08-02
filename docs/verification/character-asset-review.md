# Character Asset Review

Date: 2026-08-02

## Result

Accepted for the local macOS MVP: four locally extracted identity portraits embedded in a semi-realistic/stylized procedural crawling body. This preserves the exact faces, hair, glasses, skin tones, and the four distinguishing clothing treatments without bundling the full original photograph.

The built-in identity-preserving image-generation edit was attempted twice and failed at the network transport layer before producing any image. No API/CLI model downgrade was used. The deterministic local portrait approach therefore became the production MVP asset path, while the renderer retains a face-free procedural fallback for missing or corrupt resources.

## Visual checks

- PASS — four identities remain in the original left-to-right order.
- PASS — first and third people retain their glasses.
- PASS — all four crops retain recognizable hairstyle and facial structure.
- PASS — runtime composite contains exactly four separated crawling figures.
- PASS — each body has two arms/hands and two legs/feet in a human quadrupedal pose.
- PASS — plaid, black sleeveless, mint, and black/white clothing cues are distinct.
- PASS — output has an alpha channel and transparent surrounding pixels.
- PASS — no full source photograph is present in the bundle.
- LIMITATION — bodies are clean procedural illustrations rather than generatively reconstructed photorealistic clothing and limbs.
- LIMITATION — one generated crawl pose is procedurally transformed for crawl, climb, jump, fall, greet, play, and sleep states rather than using hand-painted frame-by-frame animation.

## SHA-256

- `person-left.jpg`: `19b2b1d72ae0b0e48fd85236c16c4f67840c1ef14e7c47d7647e928dbb1f4596`
- `person-center-left.jpg`: `f2164c2268941436996087cf38ed1fb041fd0ad5c2cfa3c08cf882639a0170e2`
- `person-center-right.jpg`: `decf2175cecf9af44ea4003470a1a0d22e6715782a5f670d23f24bceb960fbfa`
- `person-right.jpg`: `d2a057aae7f64cc3a20f962b4d6f0677d2e74e2b0bfde84cedb9c3c739d3bfb2`
- `identity-characters.png`: `7f51eb117d134ae5f374d753320f523ad1b56a0fa5a48da140ad077902f7f55f`

## Runtime preview

See `docs/verification/identity-characters.png`.
