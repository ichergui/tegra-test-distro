# Entries needed to create a FIT image;
FITIMAGE_KERNEL_LOADADDR = "0x80080000"
FITIMAGE_KERNEL_ENTRYPOINT = "0x80080000"
FITIMAGE_DTB_LOADADDR = "0x80000000"
FITIMAGE_DTB_ENTRYPOINT = "0x80000000"
FITIMAGE_INITRD_LOADADDR = "0x82a00000"
FITIMAGE_INITRD_ENTRYPOINT = "0x82a00000"

FITIMAGE_HASH_ALGORITHM = "sha256"
FITIMAGE_SIGNATURE_ALGORITHM = "rsa2048"

DTC_OPTS = "-I dts -O dtb -p 0x1000"

# FIT variables;
FIT_NAME = "fit-image.its"
FIT_INSTALL_NAME = "fit-image-${MACHINE}-${PV}-${PR}.its"
FIT_SYMLINK = "fit-image-${MACHINE}.its"
FIT_KERNEL_NAME = "${KERNEL_IMAGETYPE}" 
FIT_DTB_NAME = "${DTBFILE}"
FIT_INITRD_NAME = "${INITRAMFS_IMAGE}-${MACHINE}.cpio.gz"
FIT_IMAGE_NAME = "fit-image-${MACHINE}-${PV}-${PR}"
FIT_IMAGE_SYMLINK = "fitImage"

# UBOOT variables;
UBOOT_DTB_NAME = "u-boot-${MACHINE}.dtb"
UBOOT_NODTB_BIN_NAME = "u-boot-nodtb-${MACHINE}.bin"
UBOOT_BOOTIMG_BOARD = "/dev/mmcblk0p1"

do_oe4t_fitimage[depends] += " \
  u-boot-mkimage-native:do_populate_sysroot \
  coreutils-native:do_populate_sysroot \
  dtc-native:do_populate_sysroot \
"

construct_its_file() {
    bbnote "Constructing $FIT_FILE"

    if [ -e "${DEPLOY_DIR_IMAGE}/${FIT_KERNEL_NAME}" -a -e "${DEPLOY_DIR_IMAGE}/${FIT_DTB_NAME}" \
         -a -e "${DEPLOY_DIR_IMAGE}/${FIT_INITRD_NAME}" ]; then
        its_file_add_header ${1}
        its_file_add_section_wrappers ${1} imagestart
        its_file_add_kernel ${1} ${FIT_KERNEL_NAME}
        its_file_add_fdt ${1} ${FIT_DTB_NAME}
        its_file_add_initrd ${1} ${FIT_INITRD_NAME}
        its_file_add_section_wrappers ${1} sectend
        its_file_add_section_wrappers ${1} confstart

        its_file_add_config_no_signature ${1}

        its_file_add_section_wrappers ${1} sectend
        its_file_add_section_wrappers ${1} fitend
   else
       bbfatal "Required kernel, dtb and initrd files are not in ${DEPLOY_DIR_IMAGE}"
   fi
}

its_file_add_header() {
    cat << EOF >> ${1}
/dts-v1/;
/ {
        description = "U-Boot fitImage for ${DISTRO_NAME}/${PV}/${MACHINE}";
        #address-cells = <1>;
EOF
}

its_file_add_section_wrappers() {
        bbdebug 2 "Adding section wrapper ${2} to .its file: ${1}"
        case $2 in
        imagestart)
                cat << EOF >> ${1}

        images {
EOF
        ;;
        confstart)
                cat << EOF >> ${1}

        configurations {
EOF
        ;;
        sectend)
                cat << EOF >> ${1}
        };
EOF
        ;;
        fitend)
                cat << EOF >> ${1}
};
EOF
        ;;
        esac
}

its_file_add_kernel() {
        bbdebug 2 "Adding kernel section, kernel name: ${2} to .its file: ${1}"
        cat << EOF >> ${1}
                kernel@1 {
                        description = "Linux kernel";
                        data = /incbin/("./${2}");
                        type = "kernel";
                        arch = "arm64";
                        os = "linux";
                        compression = "none";
                        load = <${FITIMAGE_KERNEL_LOADADDR}>;
                        entry = <${FITIMAGE_KERNEL_ENTRYPOINT}>;
                        hash@1 {
                                algo = "${FITIMAGE_HASH_ALGORITHM}";
                        };
                };
EOF
}

its_file_add_fdt() {
      bbdebug 2 "Adding fdt section, fdt name: ${2} to .its file: ${1}"
      cat << EOF >> ${1}
                fdt@1 {
                        description = "Flattened Device Tree blob";
                        data = /incbin/("./${2}");
                        type = "flat_dt";
                        arch = "arm64";
                        os = "linux";
                        compression = "none";
                        load = <${FITIMAGE_DTB_LOADADDR}>;
                        entry = <${FITIMAGE_DTB_ENTRYPOINT}>;
                        hash@1 {
                                algo = "${FITIMAGE_HASH_ALGORITHM}";
                        };
                };
EOF
}

its_file_add_initrd() {
      bbdebug 2 "Adding initrd section, initrd name: ${2} to .its file: ${1}"
      cat << EOF >> ${1}
                ramdisk@1 {
                        description = "Initrd image";
                        data = /incbin/("./${2}");
                        type = "ramdisk";
                        arch = "arm64";
                        os = "linux";
                        compression = "none";
                        load = <${FITIMAGE_INITRD_LOADADDR}>;
                        entry = <${FITIMAGE_INITRD_ENTRYPOINT}>;
                        hash@1 {
                                algo = "${FITIMAGE_HASH_ALGORITHM}";
                        };
                };
EOF
}

its_file_add_config_no_signature() {
      bbdebug 2 "Adding configuration to .its file: ${1}"
      cat << EOF >> ${1}
                default = "conf@1";
                conf@1 {
                        description = "Unsigned FIT image configuration";
                        kernel = "kernel@1";
                        fdt = "fdt@1";
                        ramdisk = "ramdisk@1";
                };
EOF
}

generate_fit_image() {
    bbnote "Generating FIT image - unsigned, leaving space for signature to be appended: ${STAGING_BINDIR_NATIVE}"

    bbdebug 2 "Verified boot signature not enabled - key validation not required"
    if [ -e "${DEPLOY_DIR_IMAGE}/${FIT_INSTALL_NAME}" ]; then
         bbdebug 2 "Running mkimage to create fit image"
         ${STAGING_BINDIR_NATIVE}/mkimage -f "${DEPLOY_DIR_IMAGE}/${FIT_INSTALL_NAME}" \
                  "${DEPLOY_DIR_IMAGE}/${FIT_IMAGE_NAME}"
    else
         bbfatal "Cannot mkimage, missing required files"
    fi

    # Add symlink to fit image output
    bbdebug 2 "Deploying ${FIT_IMAGE} symlink to ${DEPLOY_DIR_IMAGE}"
    if [ -e "${DEPLOY_DIR_IMAGE}/${FIT_IMAGE_NAME}" ]; then
       cd ${DEPLOY_DIR_IMAGE}
       ln -sf ${FIT_IMAGE_NAME} ${FIT_IMAGE_SYMLINK}
       cd -
    else
       bbwarn "${FIT_IMAGE_NAME} does not exist. Cannot create symlink!"
    fi
}

generate_uboot_bin() {
   bbnote "Concatenate u-boot-nodtb.bin with u-boot.dtb to create u-boot-dtb.bin"
   bbnote "Note that this is required because u-boot.dtb now has the signature appended"

   # Get full name of u-boot deployed binary
   uboot_image=$( ls u-boot-${MACHINE}-*.bin )

   if [ "${VBOOT_SIGN_ENABLE}" -eq "1" ]; then
       if [ -e "${DEPLOY_DIR_IMAGE}/${UBOOT_NODTB_BIN_NAME}" -a  \
            -e "${DEPLOY_DIR_IMAGE}/${UBOOT_DTB_NAME}" ]; then
            bbdebug 2 "Concatenating u-boot nodtb binary and u-boot-dtb with signature"
            cat ${DEPLOY_DIR_IMAGE}/${UBOOT_NODTB_BIN_NAME} ${DEPLOY_DIR_IMAGE}/${UBOOT_DTB_NAME} > ${DEPLOY_DIR_IMAGE}/$uboot_image
            # Add the bootimg header to the u-boot binary
            bbdebug 2 "Adding bootimg header to u-boot binary"
            uboot_image_deploy_dir="${DEPLOY_DIR_IMAGE}/$uboot_image"
            mv $uboot_image_deploy_dir $uboot_image_deploy_dir.orig
            # ramdisk required for mkbootimg to pass, even if not required
            # pass an empty initrd file and then remove
            touch ${B}/initrd
            ${STAGING_BINDIR_NATIVE}/${SOC_FAMILY}-flash/mkbootimg \
                  --kernel $uboot_image_deploy_dir.orig --ramdisk ${B}/initrd --cmdline "" \
                  --board "${UBOOT_BOOTIMG_BOARD}" --output $uboot_image_deploy_dir
            # remove now mkbootimg is done
            rm -f ${B}/initrd
            # clean up original u-boot binary
            rm -f $uboot_image_deploy_dir.orig
       else
            bbfatal "Cannot concatenate u-boot-nodtb.bin with u-boot.dtb, missing required files"
       fi
   else
      bbdebug 2 "Verified boot signature not enabled - u-boot concatenation skipped"
      bbdebug 2 "Default u-boot has not been modified - $uboot_image"
   fi
}

cleaning_boot_folder () {
    if [ -d "${IMAGE_ROOTFS}/boot" ]; then
        # Remove all unneccesary files/dirs - Image, DTB, u-boot, initrd, extlinux
        bbdebug 2 "Removing unnecessary files from folder /boot (RootFS) - Kernel Image, DTBs, u-boot binary and initrd"
        rm -f ${IMAGE_ROOTFS}/boot/Image*
        rm -f ${IMAGE_ROOTFS}/boot/*.dtb
        rm -f ${IMAGE_ROOTFS}/boot/u-boot*
        rm -f ${IMAGE_ROOTFS}/boot/initrd
        rm -rf ${IMAGE_ROOTFS}/boot/extlinux
    fi
}

copy_fitimage_to_rootfs () {
    if [ -d "${IMAGE_ROOTFS}/boot" ]; then
        if [ -e "${DEPLOY_DIR_IMAGE}/${FIT_IMAGE_NAME}" ]; then
            # Copy fitImage to rootfs /boot
            bbdebug 2 "Copying ${FIT_IMAGE_NAME} to RFS /boot"
            cp ${DEPLOY_DIR_IMAGE}/${FIT_IMAGE_NAME} ${IMAGE_ROOTFS}/boot/fitImage
        fi
    fi
}


do_oe4t_fitimage () {
    bbnote "Running FIT image generation..."

    if [ -e "${B}/${FIT_NAME}" ]; then
       rm -f ${B}/${FIT_NAME}
    fi
    cd ${B}

    # Construct the FIT image ITS file
    # <Header, Kernel, DTB, initrd, Configuration, Signature>
    construct_its_file ${FIT_NAME}
   
    if [ -e "${DEPLOY_DIR_IMAGE}" ]; then
       bbdebug 2 "Deploying fit image to ${DEPLOY_DIR_IMAGE}"
       install -m 0644 ${B}/${FIT_NAME} ${DEPLOY_DIR_IMAGE}/${FIT_INSTALL_NAME}
       cd ${DEPLOY_DIR_IMAGE}
       ln -sf ${FIT_INSTALL_NAME} ${FIT_SYMLINK}
    else
       bbfatal "DEPLOY_DIR_IMAGE does not exist, cannot generate FIT image"
    fi

    # Generate the FIT image, create with space for signature later
    generate_fit_image

    # Generate the final u-boot binary by concatenating u-boot-nodtb.bin
    # with u-boot.dtb to create u-boot-dtb.bin
    generate_uboot_bin

    # Cleaning in /boot directory under RootFS.
    cleaning_boot_folder

    # Now that the FIT image has been generated, append fit image to /boot
    copy_fitimage_to_rootfs

}

addtask oe4t_fitimage after do_rootfs before do_image_ext4
