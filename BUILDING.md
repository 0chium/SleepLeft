# Build Sleep Left

The release uses Theos with ARC, a conventional rootless package, arm64/arm64e,
and normal ad-hoc signing. Building requires a suitable macOS/iOS toolchain;
there is no local Windows iOS build requirement.

Established build inputs:

- Xcode 16.4 / 16F6, Apple clang `clang-1700.0.13.5`.
- Theos `304e0799973e8145f32e4ca2de6c747a84b758ce`, including its recursive submodules.
- Theos SDK repository `0222fd5413cf4b9af096f37b4621afa2688572f7`, directory
  `iPhoneOS15.6.sdk` (internally identifies SDK 15.5).
- ldid and xz. Actual hosted build tool hashes are retained privately with build
  evidence; no signing identity or provisioning profile is needed.

The binary deployment baseline is 15.0 to match the established SDK's Objective-C
runtime stubs. The package and runtime guards admit iOS 17–18 and exactly
iOS 26.0.1. This is not an iOS 15 support claim or blanket compatibility;
the owner reports 0.1.1 working on iPhone SE (2nd generation), iOS 26.0.1
(23A355). See README for the limits of that result.

With those inputs prepared and `THEOS` set:

```sh
export DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer
printf '\372\336\014\001\000\000\000\014\000\000\000\000' > "$TMPDIR/fmm-adhoc-requirements"
make clean package messages=yes DEBUG=0 FINALPACKAGE=1 \
  "TARGET_CODESIGN_FLAGS=-S -Cadhoc -Q$TMPDIR/fmm-adhoc-requirements"
```

The empty ad-hoc requirements set avoids ldid generating a certificate-based
designated requirement without a signing identity. Do not bypass signing checks.
Extract the actual Mach-O from the final `.deb`, verify both architecture slices
and `codesign --verify --all-architectures --verbose=2`, and record the package
SHA256. A successful build does not establish jailbreak loading or runtime
compatibility.

`ci/countdown_test.cpp` checks display rounding and delayed-tick arithmetic.
It does not simulate Apple's calendar behavior. It is unchanged from the
accepted alpha and was not rerun for the branding release. The approved artwork
is in `assets/icon-original.png`; the package PNG is a proportional resize.
Existing PNG assets are included and need no regeneration for a normal build.
The internal target and loader name FiveMoreMinutes intentionally remain unchanged.
