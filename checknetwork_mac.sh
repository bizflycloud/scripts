#!/bin/bash


err() { echo "$*" >&2; exit 1; }

trim() {
    set -f
    # shellcheck disable=2048,2086
    set -- $*
    printf '%s\n' "${*//[[:space:]]/}"
    set +f
}

prin() {
    # If $2 doesn't exist we format $1 as info.
    if [[ "$(trim "$1")" && "$2" ]]; then
        [[ "$json" ]] && { printf '    %s\n' "\"${1}\": \"${2}\","; return; }

        string="${1}${2:+: $2}"
    else
        string="${2:-$1}"
        local subtitle_color="$info_color"
    fi

    string="$(trim "${string//$'\e[0m'}")"
    length="$(strip_sequences "$string")"
    length="${#length}"

    # Format the output.
    string="${string/:/${reset}${colon_color}${separator:=:}${info_color}}"
    string="${subtitle_color}${bold}${string}"

    # Print the info.
    printf '%b\n' "${text_padding:+\e[${text_padding}C}${zws}${string//\\n}${reset} "

    # Calculate info height.
    ((++info_height))

    # Log that prin was used.
    prin=1
}

strip_sequences() {
    strip="${1//$'\e['3[0-9]m}"
    strip="${strip//$'\e['[0-9]m}"
    strip="${strip//\\e\[[0-9]m}"
    strip="${strip//$'\e['38\;5\;[0-9]m}"
    strip="${strip//$'\e['38\;5\;[0-9][0-9]m}"
    strip="${strip//$'\e['38\;5\;[0-9][0-9][0-9]m}"

    printf '%s\n' "$strip"
}

get_wanip() {
	wanip=$(dig +short myip.opendns.com @resolver1.opendns.com || host myip.opendns.com resolver1.opendns.com | grep "myip.opendns.com has" | awk '{print $4}' || curl -s ipecho.net/plain)
}

cache_uname() {
    IFS=" " read -ra uname <<< "$(uname -srm)"
    kernel_name="${uname[0]}"
    kernel_version="${uname[1]}"
    kernel_machine="${uname[2]}"
    if [[ "$kernel_name" == "Darwin" ]]; then
        IFS=$'\n' read -d "" -ra sw_vers <<< "$(awk -F'<|>' '/key|string/ {print $3}' \
                            "/System/Library/CoreServices/SystemVersion.plist")"
        for ((i=0;i<${#sw_vers[@]};i+=2)) {
            case ${sw_vers[i]} in
                ProductName)          darwin_name=${sw_vers[i+1]} ;;
                ProductVersion)       osx_version=${sw_vers[i+1]} ;;
                ProductBuildVersion)  osx_build=${sw_vers[i+1]}   ;;
            esac
        }
    fi
}

get_os() {
    case $kernel_name in
        Darwin)   os=$darwin_name ;;
        SunOS)    os=Solaris ;;
        Haiku)    os=Haiku ;;
        MINIX)    os=MINIX ;;
        AIX)      os=AIX ;;
        IRIX*)    os=IRIX ;;
        FreeMiNT) os=FreeMiNT ;;
        Linux|GNU*)
            os=Linux
        ;;
        *BSD|DragonFly|Bitrig)
            os=BSD
        ;;
        CYGWIN*|MSYS*|MINGW*)
            os=Windows
        ;;
        *)
            printf '%s\n' "Unknown OS detected: '$kernel_name', aborting..." >&2
            exit 1
        ;;
    esac
}

get_distro() {
    [[ $distro ]] && return

    case $os in
        Linux|BSD|MINIX)
            if [[ -f /bedrock/etc/bedrock-release && $PATH == */bedrock/cross/* ]]; then
                case $distro_shorthand in
                    on|tiny) distro="Bedrock Linux" ;;
                    *) distro=$(< /bedrock/etc/bedrock-release)
                esac

            elif [[ -f /etc/redstar-release ]]; then
                case $distro_shorthand in
                    on|tiny) distro="Red Star OS" ;;
                    *) distro="Red Star OS $(awk -F'[^0-9*]' '$0=$2' /etc/redstar-release)"
                esac

            elif [[ -f /etc/siduction-version ]]; then
                case $distro_shorthand in
                    on|tiny) distro=Siduction ;;
                    *) distro="Siduction ($(lsb_release -sic))"
                esac

            elif [[ -f /etc/mcst_version ]]; then
                case $distro_shorthand in
                    on|tiny) distro="OS Elbrus" ;;
                    *) distro="OS Elbrus $(< /etc/mcst_version)"
                esac

            elif type -p pveversion >/dev/null; then
                case $distro_shorthand in
                    on|tiny) distro="Proxmox VE" ;;
                    *)
                        distro=$(pveversion)
                        distro=${distro#pve-manager/}
                        distro="Proxmox VE ${distro%/*}"
                esac

            elif type -p lsb_release >/dev/null; then
                case $distro_shorthand in
                    on)   lsb_flags=-si ;;
                    tiny) lsb_flags=-si ;;
                    *)    lsb_flags=-sd ;;
                esac
                distro=$(lsb_release "$lsb_flags")

            elif [[ -f /etc/os-release || \
                    -f /usr/lib/os-release || \
                    -f /etc/openwrt_release || \
                    -f /etc/lsb-release ]]; then

                # Source the os-release file
                for file in /etc/lsb-release /usr/lib/os-release \
                            /etc/os-release  /etc/openwrt_release; do
                    source "$file" && break
                done

                # Format the distro name.
                case $distro_shorthand in
                    on)   distro="${NAME:-${DISTRIB_ID}} ${VERSION_ID:-${DISTRIB_RELEASE}}" ;;
                    tiny) distro="${NAME:-${DISTRIB_ID:-${TAILS_PRODUCT_NAME}}}" ;;
                    off)  distro="${PRETTY_NAME:-${DISTRIB_DESCRIPTION}} ${UBUNTU_CODENAME}" ;;
                esac

            elif [[ -f /etc/GoboLinuxVersion ]]; then
                case $distro_shorthand in
                    on|tiny) distro=GoboLinux ;;
                    *) distro="GoboLinux $(< /etc/GoboLinuxVersion)"
                esac

            elif [[ -f /etc/SDE-VERSION ]]; then
                distro="$(< /etc/SDE-VERSION)"
                case $distro_shorthand in
                    on|tiny) distro="${distro% *}" ;;
                esac

            elif type -p crux >/dev/null; then
                distro=$(crux)
                case $distro_shorthand in
                    on)   distro=${distro//version} ;;
                    tiny) distro=${distro//version*}
                esac

            elif type -p tazpkg >/dev/null; then
                distro="SliTaz $(< /etc/slitaz-release)"

            elif type -p kpt >/dev/null && \
                 type -p kpm >/dev/null; then
                distro=KSLinux

            elif [[ -d /system/app/ && -d /system/priv-app ]]; then
                distro="Android $(getprop ro.build.version.release)"

            # Chrome OS doesn't conform to the /etc/*-release standard.
            # While the file is a series of variables they can't be sourced
            # by the shell since the values aren't quoted.
            elif [[ -f /etc/lsb-release && $(< /etc/lsb-release) == *CHROMEOS* ]]; then
                distro='Chrome OS'

            elif type -p guix >/dev/null; then
                case $distro_shorthand in
                    on|tiny) distro="Guix System" ;;
                    *) distro="Guix System $(guix -V | awk 'NR==1{printf $4}')"
                esac

            # Display whether using '-current' or '-release' on OpenBSD.
            elif [[ $kernel_name = OpenBSD ]] ; then
                read -ra kernel_info <<< "$(sysctl -n kern.version)"
                distro=${kernel_info[*]:0:2}

            else
                for release_file in /etc/*-release; do
                    distro+=$(< "$release_file")
                done

                if [[ -z $distro ]]; then
                    case $distro_shorthand in
                        on|tiny) distro=$kernel_name ;;
                        *) distro="$kernel_name $kernel_version" ;;
                    esac

                    distro=${distro/DragonFly/DragonFlyBSD}

                    # Workarounds for some BSD based distros.
                    [[ -f /etc/pcbsd-lang ]]       && distro=PCBSD
                    [[ -f /etc/trueos-lang ]]      && distro=TrueOS
                    [[ -f /etc/pacbsd-release ]]   && distro=PacBSD
                    [[ -f /etc/hbsd-update.conf ]] && distro=HardenedBSD
                fi
            fi

            if [[ $(< /proc/version) == *Microsoft* || $kernel_version == *Microsoft* ]]; then
                case $distro_shorthand in
                    on)   distro+=" [Windows 10]" ;;
                    tiny) distro="Windows 10" ;;
                    *)    distro+=" on Windows 10" ;;
                esac

            elif [[ $(< /proc/version) == *chrome-bot* || -f /dev/cros_ec ]]; then
                [[ $distro != *Chrome* ]] &&
                    case $distro_shorthand in
                        on)   distro+=" [Chrome OS]" ;;
                        tiny) distro="Chrome OS" ;;
                        *)    distro+=" on Chrome OS" ;;
                    esac
            fi

            distro=${distro/NAME=}

            # Get Ubuntu flavor.
            if [[ $distro == "Ubuntu"* ]]; then
                case $XDG_CONFIG_DIRS in
                    *"plasma"*)   distro=${distro/Ubuntu/Kubuntu} ;;
                    *"mate"*)     distro=${distro/Ubuntu/Ubuntu MATE} ;;
                    *"xubuntu"*)  distro=${distro/Ubuntu/Xubuntu} ;;
                    *"Lubuntu"*)  distro=${distro/Ubuntu/Lubuntu} ;;
                    *"budgie"*)   distro=${distro/Ubuntu/Ubuntu Budgie} ;;
                    *"studio"*)   distro=${distro/Ubuntu/Ubuntu Studio} ;;
                    *"cinnamon"*) distro=${distro/Ubuntu/Ubuntu Cinnamon} ;;
                esac
            fi
        ;;

        "Mac OS X"|"macOS")
            case $osx_version in
                10.4*)  codename="Mac OS X Tiger" ;;
                10.5*)  codename="Mac OS X Leopard" ;;
                10.6*)  codename="Mac OS X Snow Leopard" ;;
                10.7*)  codename="Mac OS X Lion" ;;
                10.8*)  codename="OS X Mountain Lion" ;;
                10.9*)  codename="OS X Mavericks" ;;
                10.10*) codename="OS X Yosemite" ;;
                10.11*) codename="OS X El Capitan" ;;
                10.12*) codename="macOS Sierra" ;;
                10.13*) codename="macOS High Sierra" ;;
                10.14*) codename="macOS Mojave" ;;
                10.15*) codename="macOS Catalina" ;;
                10.16*) codename="macOS Big Sur" ;;
                11.0*)  codename="macOS Big Sur" ;;
                *)      codename=macOS ;;
            esac

            distro="$codename $osx_version $osx_build"

            case $distro_shorthand in
                on) distro=${distro/ ${osx_build}} ;;

                tiny)
                    case $osx_version in
                        10.[4-7]*)            distro=${distro/${codename}/Mac OS X} ;;
                        10.[8-9]*|10.1[0-1]*) distro=${distro/${codename}/OS X} ;;
                        10.1[2-6]*|11.0*)     distro=${distro/${codename}/macOS} ;;
                    esac
                    distro=${distro/ ${osx_build}}
                ;;
            esac
        ;;

        "iPhone OS")
            distro="iOS $osx_version"

            # "uname -m" doesn't print architecture on iOS.
            os_arch=off
        ;;

        Windows)
            distro=$(wmic os get Caption)
            distro=${distro/Caption}
            distro=${distro/Microsoft }
        ;;

        Solaris)
            case $distro_shorthand in
                on|tiny) distro=$(awk 'NR==1 {print $1,$3}' /etc/release) ;;
                *)       distro=$(awk 'NR==1 {print $1,$2,$3}' /etc/release) ;;
            esac
            distro=${distro/\(*}
        ;;

        Haiku)
            distro=Haiku
        ;;

        AIX)
            distro="AIX $(oslevel)"
        ;;

        IRIX)
            distro="IRIX ${kernel_version}"
        ;;

        FreeMiNT)
            distro=FreeMiNT
        ;;
    esac

    distro=${distro//Enterprise Server}

    [[ $distro ]] || distro="$os (Unknown)"

    # Get OS architecture.
    case $os in
        Solaris|AIX|Haiku|IRIX|FreeMiNT)
            machine_arch=$(uname -p)
        ;;

        *)  machine_arch=$kernel_machine ;;
    esac

    [[ $os_arch == on ]] && \
        distro+=" $machine_arch"

}


get_model() {
    case $os in
        Linux)
            if [[ -d /system/app/ && -d /system/priv-app ]]; then
                model="$(getprop ro.product.brand) $(getprop ro.product.model)"

            elif [[ -f /sys/devices/virtual/dmi/id/product_name ||
                    -f /sys/devices/virtual/dmi/id/product_version ]]; then
                model=$(< /sys/devices/virtual/dmi/id/product_name)
                model+=" $(< /sys/devices/virtual/dmi/id/product_version)"

            elif [[ -f /sys/firmware/devicetree/base/model ]]; then
                model=$(< /sys/firmware/devicetree/base/model)

            elif [[ -f /tmp/sysinfo/model ]]; then
                model=$(< /tmp/sysinfo/model)
            fi
        ;;

        "Mac OS X"|"macOS")
            if [[ $(kextstat | grep -F -e "FakeSMC" -e "VirtualSMC") != "" ]]; then
                model="Hackintosh (SMBIOS: $(sysctl -n hw.model))"
            else
                model=$(sysctl -n hw.model)
            fi
        ;;

        "iPhone OS")
            case $kernel_machine in
                iPad1,1):            "iPad" ;;
                iPad2,[1-4]):        "iPad 2" ;;
                iPad3,[1-3]):        "iPad 3" ;;
                iPad3,[4-6]):        "iPad 4" ;;
                iPad6,1[12]):        "iPad 5" ;;
                iPad7,[5-6]):        "iPad 6" ;;
                iPad7,1[12]):        "iPad 7" ;;
                iPad4,[1-3]):        "iPad Air" ;;
                iPad5,[3-4]):        "iPad Air 2" ;;
                iPad11,[3-4]):       "iPad Air 3" ;;
                iPad6,[7-8]):        "iPad Pro (12.9 Inch)" ;;
                iPad6,[3-4]):        "iPad Pro (9.7 Inch)" ;;
                iPad7,[1-2]):        "iPad Pro 2 (12.9 Inch)" ;;
                iPad7,[3-4]):        "iPad Pro (10.5 Inch)" ;;
                iPad8,[1-4]):        "iPad Pro (11 Inch)" ;;
                iPad8,[5-8]):        "iPad Pro 3 (12.9 Inch)" ;;
                iPad8,9 | iPad8,10): "iPad Pro 4 (11 Inch)" ;;
                iPad8,1[1-2]):       "iPad Pro 4 (12.9 Inch)" ;;
                iPad2,[5-7]):        "iPad mini" ;;
                iPad4,[4-6]):        "iPad mini 2" ;;
                iPad4,[7-9]):        "iPad mini 3" ;;
                iPad5,[1-2]):        "iPad mini 4" ;;
                iPad11,[1-2]):       "iPad mini 5" ;;

                iPhone1,1):     "iPhone" ;;
                iPhone1,2):     "iPhone 3G" ;;
                iPhone2,1):     "iPhone 3GS" ;;
                iPhone3,[1-3]): "iPhone 4" ;;
                iPhone4,1):     "iPhone 4S" ;;
                iPhone5,[1-2]): "iPhone 5" ;;
                iPhone5,[3-4]): "iPhone 5c" ;;
                iPhone6,[1-2]): "iPhone 5s" ;;
                iPhone7,2):     "iPhone 6" ;;
                iPhone7,1):     "iPhone 6 Plus" ;;
                iPhone8,1):     "iPhone 6s" ;;
                iPhone8,2):     "iPhone 6s Plus" ;;
                iPhone8,4):     "iPhone SE" ;;
                iPhone9,[13]):  "iPhone 7" ;;
                iPhone9,[24]):  "iPhone 7 Plus" ;;
                iPhone10,[14]): "iPhone 8" ;;
                iPhone10,[25]): "iPhone 8 Plus" ;;
                iPhone10,[36]): "iPhone X" ;;
                iPhone11,2):    "iPhone XS" ;;
                iPhone11,[46]): "iPhone XS Max" ;;
                iPhone11,8):    "iPhone XR" ;;
                iPhone12,1):    "iPhone 11" ;;
                iPhone12,3):    "iPhone 11 Pro" ;;
                iPhone12,5):    "iPhone 11 Pro Max" ;;
                iPhone12,8):    "iPhone SE 2020" ;;

                iPod1,1): "iPod touch" ;;
                ipod2,1): "iPod touch 2G" ;;
                ipod3,1): "iPod touch 3G" ;;
                ipod4,1): "iPod touch 4G" ;;
                ipod5,1): "iPod touch 5G" ;;
                ipod7,1): "iPod touch 6G" ;;
            esac

            model=$_
        ;;

        BSD|MINIX)
            model=$(sysctl -n hw.vendor hw.product)
        ;;

        Windows)
            model=$(wmic computersystem get manufacturer,model)
            model=${model/Manufacturer}
            model=${model/Model}
        ;;

        Solaris)
            model=$(prtconf -b | awk -F':' '/banner-name/ {printf $2}')
        ;;

        AIX)
            model=$(/usr/bin/uname -M)
        ;;

        FreeMiNT)
            model=$(sysctl -n hw.model)
            model=${model/ (_MCH *)}
        ;;
    esac

    # Remove dummy OEM info.
    model=${model//To be filled by O.E.M.}
    model=${model//To Be Filled*}
    model=${model//OEM*}
    model=${model//Not Applicable}
    model=${model//System Product Name}
    model=${model//System Version}
    model=${model//Undefined}
    model=${model//Default string}
    model=${model//Not Specified}
    model=${model//Type1ProductConfigId}
    model=${model//INVALID}
    model=${model//All Series}
    model=${model//�}

    case $model in
        "Standard PC"*) model="KVM/QEMU (${model})" ;;
        OpenBSD*)       model="vmm ($model)" ;;
    esac
}

get_cpu() {
    case $os in
        "Linux" | "MINIX" | "Windows")
            # Get CPU name.
            cpu_file="/proc/cpuinfo"

            case $kernel_machine in
                "frv" | "hppa" | "m68k" | "openrisc" | "or"* | "powerpc" | "ppc"* | "sparc"*)
                    cpu="$(awk -F':' '/^cpu\t|^CPU/ {printf $2; exit}' "$cpu_file")"
                ;;

                "s390"*)
                    cpu="$(awk -F'=' '/machine/ {print $4; exit}' "$cpu_file")"
                ;;

                "ia64" | "m32r")
                    cpu="$(awk -F':' '/model/ {print $2; exit}' "$cpu_file")"
                    [[ -z "$cpu" ]] && cpu="$(awk -F':' '/family/ {printf $2; exit}' "$cpu_file")"
                ;;

                *)
                    cpu="$(awk -F '\\s*: | @' \
                            '/model name|Hardware|Processor|^cpu model|chip type|^cpu type/ {
                            cpu=$2; if ($1 == "Hardware") exit } END { print cpu }' "$cpu_file")"
                ;;
            esac

            speed_dir="/sys/devices/system/cpu/cpu0/cpufreq"

            # Select the right temperature file.
            for temp_dir in /sys/class/hwmon/*; do
                [[ "$(< "${temp_dir}/name")" =~ (coretemp|fam15h_power|k10temp) ]] && {
                    temp_dirs=("$temp_dir"/temp*_input)
                    temp_dir=${temp_dirs[0]}
                    break
                }
            done

            # Get CPU speed.
            if [[ -d "$speed_dir" ]]; then
                # Fallback to bios_limit if $speed_type fails.
                speed="$(< "${speed_dir}/${speed_type}")" ||\
                # speed="$(< "${speed_dir}/bios_limit")" ||\
                speed="$(< "${speed_dir}/scaling_max_freq")" ||\
                speed="$(< "${speed_dir}/cpuinfo_max_freq")"
                speed="$((speed / 1000))"

            else
                speed="$(awk -F ': |\\.' '/cpu MHz|^clock/ {printf $2; exit}' "$cpu_file")"
                speed="${speed/MHz}"
            fi

            # Get CPU temp.
            [[ -f "$temp_dir" ]] && deg="$(($(< "$temp_dir") * 100 / 10000))"

            # Get CPU cores.
            case $cpu_cores in
                "logical" | "on") cores="$(grep -c "^processor" "$cpu_file")" ;;
                "physical") cores="$(awk '/^core id/&&!a[$0]++{++i} END {print i}' "$cpu_file")" ;;
            esac
        ;;

        "Mac OS X"|"macOS")
            cpu="$(sysctl -n machdep.cpu.brand_string)"

            # Get CPU cores.
            case $cpu_cores in
                "logical" | "on") cores="$(sysctl -n hw.logicalcpu_max)" ;;
                "physical")       cores="$(sysctl -n hw.physicalcpu_max)" ;;
            esac
        ;;

        "iPhone OS")
            case $kernel_machine in
                "iPhone1,"[1-2] | "iPod1,1"): "Samsung S5L8900 (1) @ 412MHz" ;;
                "iPhone2,1"):                 "Samsung S5PC100 (1) @ 600MHz" ;;
                "iPhone3,"[1-3] | "iPod4,1"): "Apple A4 (1) @ 800MHz" ;;
                "iPhone4,1" | "iPod5,1"):     "Apple A5 (2) @ 800MHz" ;;
                "iPhone5,"[1-4]): "Apple A6 (2) @ 1.3GHz" ;;
                "iPhone6,"[1-2]): "Apple A7 (2) @ 1.3GHz" ;;
                "iPhone7,"[1-2]): "Apple A8 (2) @ 1.4GHz" ;;
                "iPhone8,"[1-4] | "iPad6,1"[12]): "Apple A9 (2) @ 1.85GHz" ;;
                "iPhone9,"[1-4] | "iPad7,"[5-6] | "iPad7,1"[1-2]):
                    "Apple A10 Fusion (4) @ 2.34GHz"
                ;;
                "iPhone10,"[1-6]): "Apple A11 Bionic (6) @ 2.39GHz" ;;
                "iPhone11,"[2468] | "iPad11,"[1-4]): "Apple A12 Bionic (6) @ 2.49GHz" ;;
                "iPhone12,"[1358]): "Apple A13 Bionic (6) @ 2.65GHz" ;;

                "iPod2,1"): "Samsung S5L8720 (1) @ 533MHz" ;;
                "iPod3,1"): "Samsung S5L8922 (1) @ 600MHz" ;;
                "iPod7,1"): "Apple A8 (2) @ 1.1GHz" ;;
                "iPad1,1"): "Apple A4 (1) @ 1GHz" ;;
                "iPad2,"[1-7]): "Apple A5 (2) @ 1GHz" ;;
                "iPad3,"[1-3]): "Apple A5X (2) @ 1GHz" ;;
                "iPad3,"[4-6]): "Apple A6X (2) @ 1.4GHz" ;;
                "iPad4,"[1-3]): "Apple A7 (2) @ 1.4GHz" ;;
                "iPad4,"[4-9]): "Apple A7 (2) @ 1.4GHz" ;;
                "iPad5,"[1-2]): "Apple A8 (2) @ 1.5GHz" ;;
                "iPad5,"[3-4]): "Apple A8X (3) @ 1.5GHz" ;;
                "iPad6,"[3-4]): "Apple A9X (2) @ 2.16GHz" ;;
                "iPad6,"[7-8]): "Apple A9X (2) @ 2.26GHz" ;;
                "iPad7,"[1-4]): "Apple A10X Fusion (6) @ 2.39GHz" ;;
                "iPad8,"[1-8]): "Apple A12X Bionic (8) @ 2.49GHz" ;;
                "iPad8,9" | "iPad8,1"[0-2]): "Apple A12Z Bionic (8) @ 2.49GHz" ;;
            esac
            cpu="$_"
        ;;

        "BSD")
            # Get CPU name.
            cpu="$(sysctl -n hw.model)"
            cpu="${cpu/[0-9]\.*}"
            cpu="${cpu/ @*}"

            # Get CPU speed.
            speed="$(sysctl -n hw.cpuspeed)"
            [[ -z "$speed" ]] && speed="$(sysctl -n  hw.clockrate)"

            # Get CPU cores.
            cores="$(sysctl -n hw.ncpu)"

            # Get CPU temp.
            case $kernel_name in
                "FreeBSD"* | "DragonFly"* | "NetBSD"*)
                    deg="$(sysctl -n dev.cpu.0.temperature)"
                    deg="${deg/C}"
                ;;
                "OpenBSD"* | "Bitrig"*)
                    deg="$(sysctl hw.sensors | \
                           awk -F '=| degC' '/lm0.temp|cpu0.temp/ {print $2; exit}')"
                    deg="${deg/00/0}"
                ;;
            esac
        ;;

        "Solaris")
            # Get CPU name.
            cpu="$(psrinfo -pv)"
            cpu="${cpu//*$'\n'}"
            cpu="${cpu/[0-9]\.*}"
            cpu="${cpu/ @*}"
            cpu="${cpu/\(portid*}"

            # Get CPU speed.
            speed="$(psrinfo -v | awk '/operates at/ {print $6; exit}')"

            # Get CPU cores.
            case $cpu_cores in
                "logical" | "on") cores="$(kstat -m cpu_info | grep -c -F "chip_id")" ;;
                "physical") cores="$(psrinfo -p)" ;;
            esac
        ;;

        "Haiku")
            # Get CPU name.
            cpu="$(sysinfo -cpu | awk -F '\\"' '/CPU #0/ {print $2}')"
            cpu="${cpu/@*}"

            # Get CPU speed.
            speed="$(sysinfo -cpu | awk '/running at/ {print $NF; exit}')"
            speed="${speed/MHz}"

            # Get CPU cores.
            cores="$(sysinfo -cpu | grep -c -F 'CPU #')"
        ;;

        "AIX")
            # Get CPU name.
            cpu="$(lsattr -El proc0 -a type | awk '{printf $2}')"

            # Get CPU speed.
            speed="$(prtconf -s | awk -F':' '{printf $2}')"
            speed="${speed/MHz}"

            # Get CPU cores.
            case $cpu_cores in
                "logical" | "on")
                    cores="$(lparstat -i | awk -F':' '/Online Virtual CPUs/ {printf $2}')"
                ;;

                "physical")
                    cores="$(lparstat -i | awk -F':' '/Active Physical CPUs/ {printf $2}')"
                ;;
            esac
        ;;

        "IRIX")
            # Get CPU name.
            cpu="$(hinv -c processor | awk -F':' '/CPU:/ {printf $2}')"

            # Get CPU speed.
            speed="$(hinv -c processor | awk '/MHZ/ {printf $2}')"

            # Get CPU cores.
            cores="$(sysconf NPROC_ONLN)"
        ;;

        "FreeMiNT")
            cpu="$(awk -F':' '/CPU:/ {printf $2}' /kern/cpuinfo)"
            speed="$(awk -F '[:.M]' '/Clocking:/ {printf $2}' /kern/cpuinfo)"
        ;;
    esac

    # Remove un-needed patterns from cpu output.
    cpu="${cpu//(TM)}"
    cpu="${cpu//(tm)}"
    cpu="${cpu//(R)}"
    cpu="${cpu//(r)}"
    cpu="${cpu//CPU}"
    cpu="${cpu//Processor}"
    cpu="${cpu//Dual-Core}"
    cpu="${cpu//Quad-Core}"
    cpu="${cpu//Six-Core}"
    cpu="${cpu//Eight-Core}"
    cpu="${cpu//[1-9][0-9]-Core}"
    cpu="${cpu//[0-9]-Core}"
    cpu="${cpu//, * Compute Cores}"
    cpu="${cpu//Core / }"
    cpu="${cpu//(\"AuthenticAMD\"*)}"
    cpu="${cpu//with Radeon * Graphics}"
    cpu="${cpu//, altivec supported}"
    cpu="${cpu//FPU*}"
    cpu="${cpu//Chip Revision*}"
    cpu="${cpu//Technologies, Inc}"
    cpu="${cpu//Core2/Core 2}"

    # Trim spaces from core and speed output
    cores="${cores//[[:space:]]}"
    speed="${speed//[[:space:]]}"

    # Remove CPU brand from the output.
    if [[ "$cpu_brand" == "off" ]]; then
        cpu="${cpu/AMD }"
        cpu="${cpu/Intel }"
        cpu="${cpu/Core? Duo }"
        cpu="${cpu/Qualcomm }"
    fi

    # Add CPU cores to the output.
    [[ "$cpu_cores" != "off" && "$cores" ]] && \
        case $os in
            "Mac OS X"|"macOS") cpu="${cpu/@/(${cores}) @}" ;;
            *)                  cpu="$cpu ($cores)" ;;
        esac

    # Add CPU speed to the output.
    if [[ "$cpu_speed" != "off" && "$speed" ]]; then
        if (( speed < 1000 )); then
            cpu="$cpu @ ${speed}MHz"
        else
            [[ "$speed_shorthand" == "on" ]] && speed="$((speed / 100))"
            speed="${speed:0:1}.${speed:1}"
            cpu="$cpu @ ${speed}GHz"
        fi
    fi

    # Add CPU temp to the output.
    if [[ "$cpu_temp" != "off" && "$deg" ]]; then
        deg="${deg//.}"

        # Convert to Fahrenheit if enabled
        [[ "$cpu_temp" == "F" ]] && deg="$((deg * 90 / 50 + 320))"

        # Format the output
        deg="[${deg/${deg: -1}}.${deg: -1}°${cpu_temp:-C}]"
        cpu="$cpu $deg"
    fi
}

get_gpu() {
    case $os in
        "Linux")
            # Read GPUs into array.
            gpu_cmd="$(lspci -mm | awk -F '\"|\" \"|\\(' \
                                          '/"Display|"3D|"VGA/ {a[$0] = $1 " " $3 " " $4}
                                           END {for(i in a) {if(!seen[a[i]]++) print a[i]}}')"
            IFS=$'\n' read -d "" -ra gpus <<< "$gpu_cmd"

            # Remove duplicate Intel Graphics outputs.
            # This fixes cases where the outputs are both
            # Intel but not entirely identical.
            #
            # Checking the first two array elements should
            # be safe since there won't be 2 intel outputs if
            # there's a dedicated GPU in play.
            [[ "${gpus[0]}" == *Intel* && "${gpus[1]}" == *Intel* ]] && unset -v "gpus[0]"

            for gpu in "${gpus[@]}"; do
                # GPU shorthand tests.
                [[ "$gpu_type" == "dedicated" && "$gpu" == *Intel* ]] || \
                [[ "$gpu_type" == "integrated" && ! "$gpu" == *Intel* ]] && \
                    { unset -v gpu; continue; }

                case $gpu in
                    *"Advanced"*)
                        brand="${gpu/*AMD*ATI*/AMD ATI}"
                        brand="${brand:-${gpu/*AMD*/AMD}}"
                        brand="${brand:-${gpu/*ATI*/ATi}}"

                        gpu="${gpu/\[AMD\/ATI\] }"
                        gpu="${gpu/\[AMD\] }"
                        gpu="${gpu/OEM }"
                        gpu="${gpu/Advanced Micro Devices, Inc.}"
                        gpu="${gpu/*\[}"
                        gpu="${gpu/\]*}"
                        gpu="$brand $gpu"
                    ;;

                    *"NVIDIA"*)
                        gpu="${gpu/*\[}"
                        gpu="${gpu/\]*}"
                        gpu="NVIDIA $gpu"
                    ;;

                    *"Intel"*)
                        gpu="${gpu/*Intel/Intel}"
                        gpu="${gpu/\(R\)}"
                        gpu="${gpu/Corporation}"
                        gpu="${gpu/ \(*}"
                        gpu="${gpu/Integrated Graphics Controller}"
                        gpu="${gpu/*Xeon*/Intel HD Graphics}"

                        [[ -z "$(trim "$gpu")" ]] && gpu="Intel Integrated Graphics"
                    ;;

                    *"MCST"*)
                        gpu="${gpu/*MCST*MGA2*/MCST MGA2}"
                    ;;

                    *"VirtualBox"*)
                        gpu="VirtualBox Graphics Adapter"
                    ;;

                    *) continue ;;
                esac

                if [[ "$gpu_brand" == "off" ]]; then
                    gpu="${gpu/AMD }"
                    gpu="${gpu/NVIDIA }"
                    gpu="${gpu/Intel }"
                fi

                prin "${subtitle:+${subtitle}${gpu_name}}" "$gpu"
            done

            return
        ;;

        "Mac OS X"|"macOS")
            if [[ -f "${cache_dir}/neofetch/gpu" ]]; then
                source "${cache_dir}/neofetch/gpu"

            else
                gpu="$(system_profiler SPDisplaysDataType |\
                       awk -F': ' '/^\ *Chipset Model:/ {printf $2 ", "}')"
                gpu="${gpu//\/ \$}"
                gpu="${gpu%,*}"

                cache "gpu" "$gpu"
            fi
        ;;

        "iPhone OS")
            case $kernel_machine in
                "iPhone1,"[1-2]):                             "PowerVR MBX Lite 3D" ;;
                "iPhone2,1" | "iPhone3,"[1-3] | "iPod3,1" | "iPod4,1" | "iPad1,1"):
                    "PowerVR SGX535"
                ;;
                "iPhone4,1" | "iPad2,"[1-7] | "iPod5,1"):     "PowerVR SGX543MP2" ;;
                "iPhone5,"[1-4]):                             "PowerVR SGX543MP3" ;;
                "iPhone6,"[1-2] | "iPad4,"[1-9]):             "PowerVR G6430" ;;
                "iPhone7,"[1-2] | "iPod7,1" | "iPad5,"[1-2]): "PowerVR GX6450" ;;
                "iPhone8,"[1-4] | "iPad6,1"[12]):             "PowerVR GT7600" ;;
                "iPhone9,"[1-4] | "iPad7,"[5-6]):             "PowerVR GT7600 Plus" ;;
                "iPhone10,"[1-6]):                            "Apple Designed GPU (A11)" ;;
                "iPhone11,"[2468]):                           "Apple Designed GPU (A12)" ;;
                "iPhone12,"[1358]):                           "Apple Designed GPU (A13)" ;;

                "iPad3,"[1-3]):     "PowerVR SGX534MP4" ;;
                "iPad3,"[4-6]):     "PowerVR SGX554MP4" ;;
                "iPad5,"[3-4]):     "PowerVR GXA6850" ;;
                "iPad6,"[3-8]):     "PowerVR 7XT" ;;

                "iPod1,1" | "iPod2,1")
                    : "PowerVR MBX Lite"
                ;;
            esac
            gpu="$_"
        ;;

        "Windows")
            while read -r line; do
                prin "${subtitle:+${subtitle}${gpu_name}}" "$(trim "$line")"
            done < <(wmic path Win32_VideoController get caption)

            gpu=${gpu//Caption}
        ;;

        "Haiku")
            gpu="$(listdev | grep -A2 -F 'device Display controller' |\
                   awk -F':' '/device beef/ {print $2}')"
        ;;

        *)
            case $kernel_name in
                "FreeBSD"* | "DragonFly"*)
                    gpu="$(pciconf -lv | grep -B 4 -F "VGA" | grep -F "device")"
                    gpu="${gpu/*device*= }"
                    gpu="$(trim_quotes "$gpu")"
                ;;

                *)
                    gpu="$(glxinfo | grep -F 'OpenGL renderer string')"
                    gpu="${gpu/OpenGL renderer string: }"
                ;;
            esac
        ;;
    esac

    if [[ "$gpu_brand" == "off" ]]; then
        gpu="${gpu/AMD}"
        gpu="${gpu/NVIDIA}"
        gpu="${gpu/Intel}"
    fi
}

get_memory() {
    case $os in
        "Linux" | "Windows")
            # MemUsed = Memtotal + Shmem - MemFree - Buffers - Cached - SReclaimable
            # Source: https://github.com/KittyKatt/screenFetch/issues/386#issuecomment-249312716
            while IFS=":" read -r a b; do
                case $a in
                    "MemTotal") ((mem_used+=${b/kB})); mem_total="${b/kB}" ;;
                    "Shmem") ((mem_used+=${b/kB}))  ;;
                    "MemFree" | "Buffers" | "Cached" | "SReclaimable")
                        mem_used="$((mem_used-=${b/kB}))"
                    ;;
                esac
            done < /proc/meminfo

            mem_used="$((mem_used / 1024))"
            mem_total="$((mem_total / 1024))"
        ;;

        "Mac OS X" | "macOS" | "iPhone OS")
            mem_total="$(($(sysctl -n hw.memsize) / 1024 / 1024))"
            mem_wired="$(vm_stat | awk '/ wired/ { print $4 }')"
            mem_active="$(vm_stat | awk '/ active/ { printf $3 }')"
            mem_compressed="$(vm_stat | awk '/ occupied/ { printf $5 }')"
            mem_compressed="${mem_compressed:-0}"
            mem_used="$(((${mem_wired//.} + ${mem_active//.} + ${mem_compressed//.}) * 4 / 1024))"
        ;;

        "BSD" | "MINIX")
            # Mem total.
            case $kernel_name in
                "NetBSD"*) mem_total="$(($(sysctl -n hw.physmem64) / 1024 / 1024))" ;;
                *) mem_total="$(($(sysctl -n hw.physmem) / 1024 / 1024))" ;;
            esac

            # Mem free.
            case $kernel_name in
                "NetBSD"*)
                    mem_free="$(($(awk -F ':|kB' '/MemFree:/ {printf $2}' /proc/meminfo) / 1024))"
                ;;

                "FreeBSD"* | "DragonFly"*)
                    hw_pagesize="$(sysctl -n hw.pagesize)"
                    mem_inactive="$(($(sysctl -n vm.stats.vm.v_inactive_count) * hw_pagesize))"
                    mem_unused="$(($(sysctl -n vm.stats.vm.v_free_count) * hw_pagesize))"
                    mem_cache="$(($(sysctl -n vm.stats.vm.v_cache_count) * hw_pagesize))"
                    mem_free="$(((mem_inactive + mem_unused + mem_cache) / 1024 / 1024))"
                ;;

                "MINIX")
                    mem_free="$(top -d 1 | awk -F ',' '/^Memory:/ {print $2}')"
                    mem_free="${mem_free/M Free}"
                ;;

                "OpenBSD"*) ;;
                *) mem_free="$(($(vmstat | awk 'END {printf $5}') / 1024))" ;;
            esac

            # Mem used.
            case $kernel_name in
                "OpenBSD"*)
                    mem_used="$(vmstat | awk 'END {printf $3}')"
                    mem_used="${mem_used/M}"
                ;;

                *) mem_used="$((mem_total - mem_free))" ;;
            esac
        ;;

        "Solaris" | "AIX")
            hw_pagesize="$(pagesize)"
            case $os in
                "Solaris")
                    pages_total="$(kstat -p unix:0:system_pages:pagestotal | awk '{print $2}')"
                    pages_free="$(kstat -p unix:0:system_pages:pagesfree | awk '{print $2}')"
                ;;

                "AIX")
                    IFS=$'\n'"| " read -d "" -ra mem_stat <<< "$(svmon -G -O unit=page)"
                    pages_total="${mem_stat[11]}"
                    pages_free="${mem_stat[16]}"
                ;;
            esac
            mem_total="$((pages_total * hw_pagesize / 1024 / 1024))"
            mem_free="$((pages_free * hw_pagesize / 1024 / 1024))"
            mem_used="$((mem_total - mem_free))"
        ;;

        "Haiku")
            mem_total="$(($(sysinfo -mem | awk -F '\\/ |)' '{print $2; exit}') / 1024 / 1024))"
            mem_used="$(sysinfo -mem | awk -F '\\/|)' '{print $2; exit}')"
            mem_used="$((${mem_used/max} / 1024 / 1024))"
        ;;

        "IRIX")
            IFS=$'\n' read -d "" -ra mem_cmd <<< "$(pmem)"
            IFS=" " read -ra mem_stat <<< "${mem_cmd[0]}"

            mem_total="$((mem_stat[3] / 1024))"
            mem_free="$((mem_stat[5] / 1024))"
            mem_used="$((mem_total - mem_free))"
        ;;

        "FreeMiNT")
            mem="$(awk -F ':|kB' '/MemTotal:|MemFree:/ {printf $2, " "}' /kern/meminfo)"
            mem_free="${mem/*  }"
            mem_total="${mem/$mem_free}"
            mem_used="$((mem_total - mem_free))"
            mem_total="$((mem_total / 1024))"
            mem_used="$((mem_used / 1024))"
        ;;

    esac

    [[ "$memory_percent" == "on" ]] && ((mem_perc=mem_used * 100 / mem_total))

    case $memory_unit in
        gib)
            mem_used=$(awk '{printf "%.2f", $1 / $2}' <<< "$mem_used 1024")
            mem_total=$(awk '{printf "%.2f", $1 / $2}' <<< "$mem_total 1024")
            mem_label=GiB
        ;;

        kib)
            mem_used=$((mem_used * 1024))
            mem_total=$((mem_total * 1024))
            mem_label=KiB
        ;;
    esac

    memory="${mem_used}${mem_label:-MiB} / ${mem_total}${mem_label:-MiB} ${mem_perc:+(${mem_perc}%)}"

    # Bars.
    case $memory_display in
        "bar")     memory="$(bar "${mem_used}" "${mem_total}")" ;;
        "infobar") memory="${memory} $(bar "${mem_used}" "${mem_total}")" ;;
        "barinfo") memory="$(bar "${mem_used}" "${mem_total}")${info_color} ${memory}" ;;
    esac
}

get_resolution() {
    case $os in
        "Mac OS X"|"macOS")
            if type -p screenresolution >/dev/null; then
                resolution="$(screenresolution get 2>&1 | awk '/Display/ {printf $6 "Hz, "}')"
                resolution="${resolution//x??@/ @ }"

            else
                resolution="$(system_profiler SPDisplaysDataType |\
                              awk '/Resolution:/ {printf $2"x"$4" @ "$6"Hz, "}')"
            fi

            if [[ -e "/Library/Preferences/com.apple.windowserver.plist" ]]; then
                scale_factor="$(PlistBuddy -c "Print DisplayAnyUserSets:0:0:Resolution" \
                                /Library/Preferences/com.apple.windowserver.plist)"
            else
                scale_factor=""
            fi

            # If no refresh rate is empty.
            [[ "$resolution" == *"@ Hz"* ]] && \
                resolution="${resolution//@ Hz}"

            [[ "${scale_factor%.*}" == 2 ]] && \
                resolution="${resolution// @/@2x @}"

            if [[ "$refresh_rate" == "off" ]]; then
                resolution="${resolution// @ [0-9][0-9]Hz}"
                resolution="${resolution// @ [0-9][0-9][0-9]Hz}"
            fi

            [[ "$resolution" == *"0Hz"* ]] && \
                resolution="${resolution// @ 0Hz}"
        ;;

        "Windows")
            IFS=$'\n' read -d "" -ra sw \
                <<< "$(wmic path Win32_VideoController get CurrentHorizontalResolution)"

            IFS=$'\n' read -d "" -ra sh \
                <<< "$(wmic path Win32_VideoController get CurrentVerticalResolution)"

            sw=("${sw[@]//CurrentHorizontalResolution}")
            sh=("${sh[@]//CurrentVerticalResolution}")

            for ((mn = 0; mn < ${#sw[@]}; mn++)) {
                [[ ${sw[mn]//[[:space:]]} && ${sh[mn]//[[:space:]]} ]] &&
                    resolution+="${sw[mn]//[[:space:]]}x${sh[mn]//[[:space:]]}, "
            }

            resolution=${resolution%,}
        ;;

        "Haiku")
            resolution="$(screenmode | awk -F ' |, ' 'END{printf $2 "x" $3 " @ " $6 $7}')"

            [[ "$refresh_rate" == "off" ]] && resolution="${resolution/ @*}"
        ;;

        "FreeMiNT")
            # Need to block X11 queries
        ;;

        *)
            if type -p xrandr >/dev/null && [[ $DISPLAY && -z $WAYLAND_DISPLAY ]]; then
				resolution="$(xrandr --nograb --current |\
							  awk 'match($0,/[0-9]*\.[0-9]*\*/) {
								   printf $1 " @ " substr($0,RSTART,RLENGTH) "Hz, "}')" || \ 
				resolution="$(xrandr --nograb --current |\
							  awk -F 'connected |\\+|\\(' \
									 '/ connected.*[0-9]+x[0-9]+\+/ && $2 {printf $2 ", "}')"
				resolution="${resolution/primary, }"
				resolution="${resolution/primary }"
                resolution="${resolution//\*}"

            elif type -p xwininfo >/dev/null && [[ $DISPLAY && -z $WAYLAND_DISPLAY ]]; then
                read -r w h \
                    <<< "$(xwininfo -root | awk -F':' '/Width|Height/ {printf $2}')"
                resolution="${w}x${h}"

            elif type -p xdpyinfo >/dev/null && [[ $DISPLAY && -z $WAYLAND_DISPLAY ]]; then
                resolution="$(xdpyinfo | awk '/dimensions:/ {printf $2}')"

            elif [[ -d /sys/class/drm ]]; then
                for dev in /sys/class/drm/*/modes; do
                    read -r resolution _ < "$dev"

                    [[ $resolution ]] && break
                done
            fi
        ;;
    esac

    resolution="${resolution%,*}"
    [[ -z "${resolution/x}" ]] && resolution=
}


send_ticket() {
	curl -s -location -request POST "https://manage.bizflycloud.vn/ticket/send" \
	--header "Content-Type: application/x-www-form-urlencoded" \
	--header "Cookie: session=.eJzdWNty2kgQ_RWVnnarEEhCIEReFmwcJ4AvAceJUynVSBrBmNElunCxy4_7uF-Ur8mfbI8uIGxDJNc-LeUqa3q6e_p0T_f0zCPvBWRGXL7rxpTWeINQStyZbiCKXBPz3aYiS2qzWeN9tHGwG-kOjuaexXd53wsjwUfE4mt8hF0Ecy5yQIS34o3r_mWQB5tuTOrFVn3pAtNqTiJMSRjx3W88QSgUkkmYcRChAnENbw0D6iErWz4IYRwSx6dYCCMvQDMMBNNi2hJZvUBFlOomWIgDJrQJkeUQxugzGixa45c-Gy89tmSIzTgg0QY-bWLgQPdlH74ty2Nrmp4bIeICOcAzsDhgfCiOPD2EdcBBMFzEIOZi0K1jF1zIjHD8kP9e4_HaJwEOwRWyKEuC2BZkeSopXUnrKmpdTH53wJ7BBMbHxKyuWBdTB-QBCDJa6oQt3JSYuQAHyy1fSlqhyJzvaC_B7Mnv6wTnpl9-QBzEeLMtkMwWnJwZljs6HSb-Sz_33JWSXrospbP462n8MxeQJYQswMjJl8nDlQ5ZJNOvXfAyq7No5xg8x4uI5-ozDA5ANKE_wcTcY6vzoqq2ZVnWlDaEIw6oHm18RmdOJSYLKfiW2ARbepYAfDcKYlzLOQDtt0dwscWkxr0PIxDJ0qAfhwAxDLkBwwd05n4PDOfPL2AEKWNQbOX6TOR6LgF35VlkZOI6zsSzFXUwE6bnUeSH3UaDTdZf5Boxk4WOMT3VtnafTHZWn7B5bpJuqqo27-3IQxbP3bqDXNhyzyxq7GpCA_nkNRQlpAqwRv0drBEkFdfPk6oqrv2UrAwM7Go8L2ulsL0ULMD7fHWxwwcDbgL1lYu85H9liJBSegiCOsvaVMEbUIIWCEcVeJlEAdfpRWE7poNqUCw3PJIuhwxJpUrbzdgLRvd7BaN7MYvC9qSoZv2zY-YNQWAahJ2G0pD25Irl4VOhPOSHCfdpdzJWLBKvHa5Vo7VVIhSUlEb6inQB76S5wztJDl5usu0zqmF9dm5Xx_mi-ymN8Zlkca8OBzuAw-2ZzA3yNqYaxtcaoaowdzqErY7SSF8KF8D2RtNCYlIcRNUzMpN6SypmouVzMBEo2h9H873KMn9LRZlXj0kFqyv3Eifj_6yZMJ03dhOlJSt3FKXQlWwpDhpZoqeo0I-8qa0ohbN8X3EU6qHGopRU-XJQCtJv6sFRiw4UhDJClbuNcmBKtRvHzTvab1SQffrObr9QwfUUcWYzRWGk75e8hAS3u3tsRodfHLZ3t_QKlakj7Fb5WLjYpXfBdLLUS0bkLTAzZdZjv_5MNOjp-E42zC9qf7qmw-bK7aw_ejP9bPihdza4X6jXo_WZdm_fDn-cn8eBQFtIQjfDMGxZvf56cmk7Q2ewECPjcvq5PfSXD-r85GF18f7T6sbDZuvUHA7Q5Tm6GrXGrenH-OozDZQ7rdUJzv2BPbZPbodrR_7q29H9zWq6Hl6u4-srYtzePWCpM9cXN9ZXQxhpXz7eNj9M59e7BxvCHnLMlqrZTWR02qKm2LKpqXazbYgdVcXIammIzx80fvueceiu_FocnrZ77beX2aORKgthEeoxLJjyY62pSKKBpZalKnLLNFRJkxBWbKUtYdRkRYoxC7BpGQp-7D0QSlGjVRe5P75I0jtuRNx4za07bb2tvOOCZbfTqYt_cu-xufAasiiJ8CdxZ-A121s32CTo9CKf79qIhvj_sIdMStiDYPZissJG9k5BfLZR1Loq17VOXW4q7F0NGyTaYrdjSrMMu5jFm18__3a5i9mvn_-Y3GnMGvlM5xg7RnI4ZvvmUD7mr5bINNP4ypZhqUg2hY5sSoJiqrKApKYsWBBbDJFRNUvmn_4FjB8emA.YNWuQw.5XeBKoNyAPDIBiYirT46a7gltSE" \
	--data-urlencode "FullName=$1" \
	--data-urlencode "Email=$1" \
	--data-urlencode "Content=`cat $2`" \
	--data-urlencode "Phone=$3"
}

authen() {
	curl -si --location --request POST 'https://manage.bizflycloud.vn/api/token' \
		--header 'Content-Type: application/json' \
		-d "{
			\"username\": \"$1\",
			\"password\": \"$2\",
			\"auth_method\": \"password\"
		}" \
		-o /dev/null -w '%{http_code}\n'
}


main() {
	file_name="checknetwork_$(date '+%Y%m%d_%H%M%S')"
	echo "Thong tin kiem tra network." >> $file_name
	read -p "Nhap IP hoac Domain muon kiem tra: " domain
	echo "Dang ping, traceroute den $domain, vui long doi ket qua... "
	echo "PING: " >> $file_name
	ping -c 10  $domain  >> $file_name
	echo "TRACEROUTE: " >> $file_name
	traceroute $domain >> $file_name
	# echo "TRACEPATH: " >> $file_name
	# tracepath $domain >> $file_name 
	cache_uname
	get_os
	get_wanip
	get_distro
	get_model
	get_cpu
	get_memory
	get_resolution
	echo "	WAN IP: $wanip 
	Kernel Name: $kernel_name
	Kernel Machine: $kernel_machine
	Kernel Version: $kernel_version
	Distro: $distro
	Model: $model
	CPU: $cpu
	GPU: `get_gpu`
	Memory: $memory
	Resolution: $resolution">>  $file_name
	cat $file_name
	# select yn in Y N
	# do 
	while true
	do
		read -p "Ban co muon gui thong tin den bizflycloud khong? [y/n]" yn
		case $yn in
			[Yy]* )
				# echo "Call api gui ticket"
				try=1
				auth=false
				while [[ $try -le 3  && $auth = false ]]
					do
						read -p "Nhap email cua ban: " email
						read -p "Nhap ten password cua ban: " password
						read -p "Nhap so dien thoai cua ban: " phone
						code=$(authen $email $password)
						[[ $code -eq 200 ]] && echo "Xac thuc thanh cong!" && auth=true || echo 'Sai thong tin xac thuc, vui long thu lai' && let try+=1
					done
				if [[ $auth = true ]]; then echo "Dang gui ticket..." && send_ticket $email $file_name $phone 
				read -p "Ban co muon xoa file ket qua khong? [y/n]" yn
				case $yn in
					Y) rm $file_name; exit 1;;
					*) exit 1;;
				esac
				fi
				if [[ $auth = false ]]; then echo "Ban da qua 3 lan xac thuc that bai. Vui long gui email kem file ket qua ve support@bizflycloud.vn de duoc hoc tro. Xin cam on!" && exit 1
				fi
				;;
			[Nn]* )
				read -p "Ban co muon xoa file ket qua khong? [y/n]" yn
				case $yn in
					Y) rm $file_name; exit 1;;
					*) exit 1;;
				esac
				;;
			* ) echo "Chon 'y/Y' hoac 'n/N'" ;;
		esac
	done
	echo "Cam on ban da ho tro"
}

main "$@"
