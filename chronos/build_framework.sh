set -e

FRAMEWORK_NAME="chronos"
 
if [ -d "../${SRCROOT}/build" ]; then
rm -rf "../${SRCROOT}/build"
fi
 
xcodebuild -target "${FRAMEWORK_NAME}" -configuration Release -arch arm64 only_active_arch=no defines_module=yes -sdk "iphoneos"

mv build ..