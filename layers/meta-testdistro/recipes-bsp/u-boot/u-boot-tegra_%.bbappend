FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI_append = " \
  file://0014-common-bootm.c-Increase-CONFIG_SYS_BOOTM_LEN-to-64MB.patch \
  file://0015-t210-mender-FIT-image-bootcmd-support.patch \
  file://t210-Enable-FIT-image-support.cfg \
"

