#!/usr/bin/env bash

# Build an HTTPS Everywhere .crx & .xpi extension
#
# To build the current state of the tree:
#
#     ./make.sh
#
# To build a particular tagged release:
#
#     ./make.sh <version number>
#
# eg:
#
#     ./make.sh 2017.8.15
#
# Note that .crx files must be signed; this script makes you a
# "dummy-chromium.pem" private key for you to sign your own local releases,
# but these .crx files won't detect and upgrade to official HTTPS Everywhere
# releases signed by EFF :/.  We should find a more elegant arrangement.


cd $(dirname $0)

if [ -n "$1" ]; then
  BRANCH=`git branch | head -n 1 | cut -d \  -f 2-`
  SUBDIR=checkout
  [ -d $SUBDIR ] || mkdir $SUBDIR
  cp -r -f -a .git $SUBDIR
  cd $SUBDIR
  git reset --hard "$1"
  git submodule update --recursive -f
fi

VERSION=`python3.6 -c "import json ; print(json.loads(open('chromium/manifest.json').read())['version'])"`

echo "Building version" $VERSION

[ -d pkg ] || mkdir -p pkg
[ -e pkg/crx-cws ] && rm -rf pkg/crx-cws
[ -e pkg/crx-eff ] && rm -rf pkg/crx-eff
[ -e pkg/xpi-amo ] && rm -rf pkg/xpi-amo
[ -e pkg/xpi-eff ] && rm -rf pkg/xpi-eff
[ -e pkg/xpi-cliqz ] && rm -rf pkg/xpi-cliqz # cliqz

# Clean up obsolete ruleset databases, just in case they still exist.
rm -f src/chrome/content/rules/default.rulesets src/defaults/rulesets.sqlite

mkdir -p pkg/crx-cws/rules
cd pkg/crx-cws
cp -a ../../chromium/* ./
# Turn the Firefox translations into the appropriate Chrome format:
rm -rf _locales/
mkdir _locales/
python3.6 ../../utils/chromium-translations.py ../../translations/ _locales/
python3.6 ../../utils/chromium-translations.py ../../src/chrome/locale/ _locales/
do_not_ship="*.py *.xml"
rm -f $do_not_ship
cd ../..

python3.6 ./utils/merge-rulesets.py || exit 5

cp src/chrome/content/rules/default.rulesets pkg/crx-cws/rules/default.rulesets

sed -i -e "s/VERSION/$VERSION/g" pkg/crx-cws/manifest.json

for x in `cat .build_exclusions`; do
  rm -rf pkg/crx-cws/$x
done

cp -a pkg/crx-cws pkg/crx-eff
cp -a pkg/crx-cws pkg/xpi-amo
cp -a pkg/crx-cws pkg/xpi-eff
cp -a pkg/crx-cws pkg/xpi-cliqz # cliqz

cp -a src/META-INF pkg/xpi-amo
cp -a src/META-INF pkg/xpi-eff
cp -a src/META-INF pkg/xpi-cliqz # cliqz

# Remove the 'applications' manifest key from the crx version of the extension, change the 'author' string to a hash, and add the "update_url" manifest key
# "update_url" needs to be present to avoid problems reported in https://bugs.chromium.org/p/chromium/issues/detail?id=805755
python3.6 -c "import json; m=json.loads(open('pkg/crx-cws/manifest.json').read()); m['author']={'email': 'eff.software.projects@gmail.com'}; del m['applications']; m['update_url'] = 'https://clients2.google.com/service/update2/crx'; open('pkg/crx-cws/manifest.json','w').write(json.dumps(m,indent=4,sort_keys=True))"
python3.6 -c "import json; m=json.loads(open('pkg/crx-eff/manifest.json').read()); m['author']={'email': 'eff.software.projects@gmail.com'}; del m['applications']; open('pkg/crx-eff/manifest.json','w').write(json.dumps(m,indent=4,sort_keys=True))"
# Remove the 'update_url' manifest key from the xpi version of the extension delivered to AMO
python3.6 -c "import json; m=json.loads(open('pkg/xpi-amo/manifest.json').read()); del m['applications']['gecko']['update_url']; m['applications']['gecko']['id'] = 'https-everywhere@eff.org'; open('pkg/xpi-amo/manifest.json','w').write(json.dumps(m,indent=4,sort_keys=True))"
# Remove the 'update_url' manifest key from the xpi version of the extension delivered to Cliqz
python3.6 -c "import json; m=json.loads(open('pkg/xpi-cliqz/manifest.json').read()); del m['applications']['gecko']['update_url']; m['applications']['gecko']['id'] = 'https-everywhere@cliqz.com'; open('pkg/xpi-cliqz/manifest.json','w').write(json.dumps(m,indent=4,sort_keys=True))"

# If the --remove-extension-update flag is set, ensure the extension is unable to update
if $REMOVE_EXTENSION_UPDATE; then
  echo "Flag --remove-extension-update specified.  Removing the XPI extensions' ability to update."
  python3.6 -c "import json; m=json.loads(open('pkg/xpi-amo/manifest.json').read()); m['applications']['gecko']['update_url'] = 'data:text/plain,'; open('pkg/xpi-amo/manifest.json','w').write(json.dumps(m,indent=4,sort_keys=True))"
  python3.6 -c "import json; m=json.loads(open('pkg/xpi-eff/manifest.json').read()); m['applications']['gecko']['update_url'] = 'data:text/plain,'; open('pkg/xpi-eff/manifest.json','w').write(json.dumps(m,indent=4,sort_keys=True))"
fi

# If the --remove-update-channels flag is set, remove all out-of-band update channels
if $REMOVE_UPDATE_CHANNELS; then
  echo "Flag --remove-update-channels specified.  Removing all out-of-band update channels."
  echo "require.scopes.update_channels.update_channels = [];" >> pkg/crx-cws/background-scripts/update_channels.js
  echo "require.scopes.update_channels.update_channels = [];" >> pkg/crx-eff/background-scripts/update_channels.js
  echo "require.scopes.update_channels.update_channels = [];" >> pkg/xpi-amo/background-scripts/update_channels.js
  echo "require.scopes.update_channels.update_channels = [];" >> pkg/xpi-eff/background-scripts/update_channels.js
fi

if [ -n "$BRANCH" ] ; then
  crx_cws="pkg/https-everywhere-$VERSION-cws.crx"
  crx_eff="pkg/https-everywhere-$VERSION-eff.crx"
  xpi_amo="pkg/https-everywhere-$VERSION-amo.xpi"
  xpi_eff="pkg/https-everywhere-$VERSION-eff.xpi"
  xpi_cliqz="pkg/https-everywhere-$VERSION-cliqz.xpi"
else
  crx_cws="pkg/https-everywhere-$VERSION~pre-cws.crx"
  crx_eff="pkg/https-everywhere-$VERSION~pre-eff.crx"
  xpi_amo="pkg/https-everywhere-$VERSION~pre-amo.xpi"
  xpi_eff="pkg/https-everywhere-$VERSION~pre-eff.xpi"
  xpi_cliqz="pkg/https-everywhere-$VERSION~pre-cliqz.xpi"
fi
if ! [ -f "$KEY" ] ; then
  echo "Making a dummy signing key for local build purposes"
  openssl genrsa -out /tmp/dummy-chromium.pem 768
  openssl pkcs8 -topk8 -nocrypt -in /tmp/dummy-chromium.pem -out $KEY
fi


# now pack the crx'es
BROWSER="chromium-browser"
which $BROWSER || BROWSER="chromium"

$BROWSER --no-message-box --pack-extension="pkg/crx-cws" --pack-extension-key="$KEY" 2> /dev/null
$BROWSER --no-message-box --pack-extension="pkg/crx-eff" --pack-extension-key="$KEY" 2> /dev/null
mv pkg/crx-cws.crx $crx_cws
mv pkg/crx-eff.crx $crx_eff
echo >&2 "CWS crx package has sha256sum: `openssl dgst -sha256 -binary "$crx_cws" | xxd -p`"
echo >&2 "EFF crx package has sha256sum: `openssl dgst -sha256 -binary "$crx_eff" | xxd -p`"


# now zip up the xpi AMO dir
name=pkg/xpi-amo
dir=pkg/xpi-amo
zip="$name.zip"

cwd=$(pwd -P)
(cd "$dir" && ../../utils/create_zip.py -n "$cwd/$zip" -x "../../.build_exclusions" .)
echo >&2 "AMO xpi package has sha256sum: `openssl dgst -sha256 -binary "$cwd/$zip" | xxd -p`"

cp $zip $xpi_amo



# now zip up the xpi EFF dir
name=pkg/xpi-eff
dir=pkg/xpi-eff
zip="$name.zip"

cwd=$(pwd -P)
(cd "$dir" && ../../utils/create_zip.py -n "$cwd/$zip" -x "../../.build_exclusions" .)
echo >&2 "EFF xpi package has sha256sum: `openssl dgst -sha256 -binary "$cwd/$zip" | xxd -p`"

cp $zip $xpi_eff



# now zip up the xpi CLIQZ dir
name=pkg/xpi-cliqz
dir=pkg/xpi-cliqz
zip="$name.zip"

cwd=$(pwd -P)
(cd "$dir" && ../../utils/create_zip.py -n "$cwd/$zip" -x "../../.build_exclusions" .)
echo >&2 "cliqz xpi package has sha256sum: `openssl dgst -sha256 -binary "$cwd/$zip" | xxd -p`"

cp $zip $xpi_cliqz


bash utils/android-push.sh "$xpi_eff"

echo >&2 "Total included rules: `find src/chrome/content/rules -name "*.xml" | wc -l`"
echo >&2 "Rules disabled by default: `find src/chrome/content/rules -name "*.xml" | xargs grep -F default_off | wc -l`"

# send the following to stdout so scripts can parse it
# see test/selenium/shim.py
echo "Created $xpi_amo"
echo "Created $xpi_eff"
echo "Created $xpi_cliqz"
echo "Created $crx_cws"
echo "Created $crx_eff"

if [ -n "$BRANCH" ]; then
  cd ..
  cp $SUBDIR/$crx_cws pkg
  cp $SUBDIR/$crx_eff pkg
  cp $SUBDIR/$xpi_amo pkg
  cp $SUBDIR/$xpi_eff pkg
  cp $SUBDIR/$xpi_cliqz pkg
  rm -rf $SUBDIR
fi
