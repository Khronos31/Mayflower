# Mayflower Swift: use legacy C++ driver without the deprecation warning.
# new_driver_not_found has no mute; opt into old driver intentionally instead.
export SWIFT_USE_OLD_DRIVER=1
export SWIFT_AVOID_WARNING_USING_OLD_DRIVER=1
