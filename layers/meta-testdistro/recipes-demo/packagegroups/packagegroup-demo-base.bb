DESCRIPTION = "Packagegroup for inclusion in all Tegra demo images"

LICENSE = "MIT"

inherit packagegroup

RDEPENDS_${PN} = " \
    fuse3 \
    gdb \
    gdbserver \
    haveged \
    procps \
    sshfs-fuse \
    strace \
    tegra-tools-tegrastats \
"