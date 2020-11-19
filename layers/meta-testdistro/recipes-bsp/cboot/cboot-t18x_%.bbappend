PACKAGECONFIG_remove_secureboot = "recovery"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:${THISDIR}/files:"

SRC_URI += "\
    file://0001-Fix-spurious-console-none-warning.patch \
    file://0002-Add-machine-ID-from-fuses-to-kernel-command-line.patch \
"


