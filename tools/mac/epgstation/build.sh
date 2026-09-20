#!/bin/sh
# Mayflower | Mac で EPGStation の JS をコンパイルし、端末用 payload を梱包する。
#
#   export MAYFLOWER=/path/to/Mayflower
#   $MAYFLOWER/tools/mac/epgstation/build.sh
#
# 成果は ${EPGSTATION_BUILD_DIR:-$HOME/epgstation-ios}/dist/epgstation-<ver>-aarch64-apple-ios.tar.xz。
# native の .node は入れない。sqlite3 は端末の nodejs-sqlite3 をシンボリックリンクする。
set -eu

EPGSTATION_VERSION=2.10.0
EPGSTATION_TAG="v${EPGSTATION_VERSION}"

MAYFLOWER="${MAYFLOWER:-}"
if [ -z "${MAYFLOWER}" ]; then
  MAYFLOWER="$(cd "$(dirname "$0")/../../.." && pwd)"
fi

BUILD_DIR="${EPGSTATION_BUILD_DIR:-${HOME}/epgstation-ios}"
SRC="${BUILD_DIR}/EPGStation-${EPGSTATION_VERSION}"
DIST="${BUILD_DIR}/dist"
STAGE="${BUILD_DIR}/stage"
NAME="epgstation-${EPGSTATION_VERSION}-aarch64-apple-ios"

HOST_NODE="$(command -v node)"
HOST_NPM="$(command -v npm)"
[ -n "${HOST_NODE}" ] || { echo "error: host node が無い" >&2; exit 1; }
[ -n "${HOST_NPM}" ] || { echo "error: host npm が無い" >&2; exit 1; }

mkdir -p "${BUILD_DIR}" "${DIST}"
cd "${BUILD_DIR}"
export COPYFILE_DISABLE=1

if [ ! -f "${SRC}/package.json" ]; then
  rm -rf "${SRC}"
  git clone --depth 1 --branch "${EPGSTATION_TAG}" \
    https://github.com/l3tnun/EPGStation.git "${SRC}"
fi

if [ ! -f "${SRC}/dist/index.js" ]; then
  (cd "${SRC}" && "${HOST_NPM}" ci --ignore-scripts --no-audit --no-fund)
  (cd "${SRC}" && "${HOST_NPM}" run compile)
fi
# argv[0] は Mach-O ラッパ。IPC 子は最初から node-bin である必要がある。
python3 -c "
from pathlib import Path
old = 'spawn(process.argv[0], ['
new = \"spawn(process.execPath, ['--jitless', \"
for rel in ('dist/index.js', 'dist/model/epgUpdater/EPGUpdateExecutorManageModel.js'):
    p = Path(r'''${SRC}''') / rel
    t = p.read_text()
    if new in t:
        print('already patched', rel)
        continue
    if old not in t:
        raise SystemExit('spawn patch missing: ' + rel)
    p.write_text(t.replace(old, new, 1))
    print('patched', rel)
"

if [ ! -f "${SRC}/client/dist/index.html" ]; then
  (cd "${SRC}/client" && "${HOST_NPM}" ci --ignore-scripts --no-audit --no-fund)
  (cd "${SRC}/client" && "${HOST_NPM}" run build)
fi
(cd "${SRC}" && "${HOST_NPM}" prune --omit=dev --no-audit --no-fund)

rm -rf "${STAGE}"
mkdir -p "${STAGE}/${NAME}"
stage="${STAGE}/${NAME}"

cp -R "${SRC}/dist" "${stage}/"
mkdir -p "${stage}/client"
cp -R "${SRC}/client/dist" "${stage}/client/dist"
cp -R "${SRC}/config" "${stage}/config"
cp -R "${SRC}/node_modules" "${stage}/node_modules"
cp "${SRC}/package.json" "${stage}/package.json"
cp "${SRC}/api.yml" "${stage}/api.yml"
cp "${SRC}/LICENSE" "${stage}/LICENSE"

# ログ設定はサンプルを本番名へ。config.yml は端末の package() がパスを直す。
for sample in operatorLogConfig epgUpdaterLogConfig serviceLogConfig; do
  if [ -f "${stage}/config/${sample}.sample.yml" ] && [ ! -f "${stage}/config/${sample}.yml" ]; then
    cp "${stage}/config/${sample}.sample.yml" "${stage}/config/${sample}.yml"
  fi
done
if [ -f "${stage}/config/enc.js.template" ] && [ ! -f "${stage}/config/enc.js" ]; then
  cp "${stage}/config/enc.js.template" "${stage}/config/enc.js"
fi

# ホストの ELF / macOS Mach-O を残さない。sqlite3 の JS も捨てて端末でリンクする。
find "${stage}" \( -name '*.node' -o -name '*.so' -o -name '*.dylib' \) -type f -delete
rm -rf "${stage}/node_modules/sqlite3"
rm -rf "${stage}/node_modules/.bin"
find "${stage}/node_modules" -type d -name 'prebuilds' -prune -exec rm -rf {} +
find "${stage}" -name '*.map' -type f -delete
rm -rf "${stage}/node_modules/typescript" \
  "${stage}/node_modules/@types" 2>/dev/null || true

out="${DIST}/${NAME}.tar.xz"
rm -f "${out}"
tar -C "${STAGE}" -cJf "${out}" "${NAME}"
echo "できあがり ${out}"
ls -lh "${out}"
