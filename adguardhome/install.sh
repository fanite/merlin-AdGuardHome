#!/bin/sh
source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
MODEL=
UI_TYPE=ASUSWRT
FW_TYPE_CODE=
FW_TYPE_NAME=
DIR=$(cd $(dirname $0); pwd)
module=${DIR##*/}

get_model(){
	local ODMPID=$(nvram get odmpid)
	local PRODUCTID=$(nvram get productid)
	if [ -n "${ODMPID}" ];then
		MODEL="${ODMPID}"
	else
		MODEL="${PRODUCTID}"
	fi
}

get_fw_type() {
	local KS_TAG=$(nvram get extendno|grep koolshare)
	if [ -d "/koolshare" ];then
		if [ -n "${KS_TAG}" ];then
			FW_TYPE_CODE="2"
			FW_TYPE_NAME="koolshare官改固件"
		else
			FW_TYPE_CODE="4"
			FW_TYPE_NAME="koolshare梅林改版固件"
		fi
	else
		if [ "$(uname -o|grep Merlin)" ];then
			FW_TYPE_CODE="3"
			FW_TYPE_NAME="梅林原版固件"
		else
			FW_TYPE_CODE="1"
			FW_TYPE_NAME="华硕官方固件"
		fi
	fi
}

platform_test(){
	local LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')
	if [ -d "/koolshare" -a -f "/usr/bin/skipd" -a "${LINUX_VER}" -eq "26" ];then
		echo_date 机型："${MODEL} ${FW_TYPE_NAME} 符合安装要求，开始安装插件！"
	else
		exit_install 1
	fi
}

get_ui_type(){
	# default value
	[ "${MODEL}" == "RT-AC86U" ] && local ROG_RTAC86U=0
	[ "${MODEL}" == "GT-AC2900" ] && local ROG_GTAC2900=1
	[ "${MODEL}" == "GT-AC5300" ] && local ROG_GTAC5300=1
	[ "${MODEL}" == "GT-AX11000" ] && local ROG_GTAX11000=1
	[ "${MODEL}" == "GT-AXE11000" ] && local ROG_GTAXE11000=1
	local KS_TAG=$(nvram get extendno|grep koolshare)
	local EXT_NU=$(nvram get extendno)
	local EXT_NU=$(echo ${EXT_NU%_*} | grep -Eo "^[0-9]{1,10}$")
	local BUILDNO=$(nvram get buildno)
	[ -z "${EXT_NU}" ] && EXT_NU="0" 
	# RT-AC86U
	if [ -n "${KS_TAG}" -a "${MODEL}" == "RT-AC86U" -a "${EXT_NU}" -lt "81918" -a "${BUILDNO}" != "386" ];then
		# RT-AC86U的官改固件，在384_81918之前的固件都是ROG皮肤，384_81918及其以后的固件（包括386）为ASUSWRT皮肤
		ROG_RTAC86U=1
	fi
	# GT-AC2900
	if [ "${MODEL}" == "GT-AC2900" ] && [ "${FW_TYPE_CODE}" == "3" -o "${FW_TYPE_CODE}" == "4" ];then
		# GT-AC2900从386.1开始已经支持梅林固件，其UI是ASUSWRT
		ROG_GTAC2900=0
	fi
	# GT-AX11000
	if [ "${MODEL}" == "GT-AX11000" -o "${MODEL}" == "GT-AX11000_BO4" ] && [ "${FW_TYPE_CODE}" == "3" -o "${FW_TYPE_CODE}" == "4" ];then
		# GT-AX11000从386.2开始已经支持梅林固件，其UI是ASUSWRT
		ROG_GTAX11000=0
	fi
	# ROG UI
	if [ "${ROG_GTAC5300}" == "1" -o "${ROG_RTAC86U}" == "1" -o "${ROG_GTAC2900}" == "1" -o "${ROG_GTAX11000}" == "1" -o "${ROG_GTAXE11000}" == "1" ];then
		# GT-AC5300、RT-AC86U部分版本、GT-AC2900部分版本、GT-AX11000部分版本、GT-AXE11000全部版本，骚红皮肤
		UI_TYPE="ROG"
	fi
	# TUF UI
	if [ "${MODEL}" == "TUF-AX3000" ];then
		# 官改固件，橙色皮肤
		UI_TYPE="TUF"
	fi
}

exit_install(){
	local state=$1
	case $state in
		1)
			echo_date "本插件适用于【koolshare merlin armv7l 384/386】固件平台！"
			echo_date "你的固件平台不能安装！！!"
			echo_date "本插件支持机型/平台：https://github.com/koolshare/armsoft#armsoft"
			echo_date "退出安装！"
			rm -rf /tmp/${module}* >/dev/null 2>&1
			exit 1
			;;
		0|*)
			rm -rf /tmp/${module}* >/dev/null 2>&1
			exit 0
			;;
	esac
}

copy() {
	# echo_date "$*" 2>&1
	"$@" 2>/dev/null
	# "$@" 2>&1
	if [ "$?" != "0" ];then
		#echo_date "$* 命令运行错误！可能是/jffs分区空间不足！"
		echo_date "复制文件错误！可能是/jffs分区空间不足！"
		echo_date "尝试删除本次已经安装的文件..."
		remove_files
		exit 1
	fi
}

remove_files(){
	# files should be removed before install
	echo_date "删除AdGuardHome插件相关文件！"
	#sed -Ei '/【AdGuardHome】|^$/d' /koolshare/bin/ks-services-start.sh
	rm -rf /tmp/adguardhome* >/dev/null 2>&1
	rm -rf /koolshare/adguardhome  >/dev/null 2>&1
	rm -rf /koolshare/bin/adguardhome* >/dev/null 2>&1
	rm -rf /koolshare/res/*adguardhome* >/dev/null 2>&1
	rm -rf /koolshare/scripts/adguardhome_* >/dev/null 2>&1
	rm -rf /koolshare/scripts/uninstall_adguardhome.sh >/dev/null 2>&1
	rm -rf /koolshare/webs/Module_adguardhome.asp >/dev/null 2>&1
	find /koolshare/init.d -name "*adguardhome*" | xargs rm -rf
}

install_now(){
	# default value
	local TITLE="AdGuardHome"
	local DESCR="AdGuardHome 广告过滤"
	#local PLVER=$(cat ${DIR}/version)

	# stop first
	local ENABLE=$(dbus get ${module}_enable)
	if [ "${ENABLE}" == "1" -a -f "/koolshare/scripts/${module}_config.sh" ];then
		echo_date "先关闭AdGuardHome插件，保证文件更新成功..."
		/koolshare/${module}/adguardhome.sh stop
	fi

	# remove some file first
	rm -rf /koolshare/scripts/adguardhome*
	find /koolshare/init.d -name "*adguardhome*" | xargs rm -rf

	# isntall file
	echo_date "安装插件相关文件..."
	cd /tmp
	copy cp -rf /tmp/${module}/${module} /koolshare/
	copy cp -rf /tmp/${module}/scripts/* /koolshare/scripts/
	copy cp -rf /tmp/${module}/webs/* /koolshare/webs/
	copy cp -rf /tmp/${module}/res/* /koolshare/res/
	copy cp -rf /tmp/${module}/perp/* /koolshare/perp/
	copy cp -rf /tmp/${module}/uninstall.sh /koolshare/scripts/uninstall_${module}.sh

	echo_date "安装主程序AdGuardHome..."
	# copy cp -fP /tmp/${module}/bin/* /koolshare/bin/
	#sed -Ei '/【AdGuardHome】|^$/d' /koolshare/bin/ks-services-start.sh
#cat >> "/koolshare/bin/ks-services-start.sh" <<-OSC
	#/koolshare/scripts/${module}_config.sh  # 【AdGuardHome】
#OSC

	if [ `ls /koolshare/init.d|grep "adguardhome.sh"|wc -l` -gt 0 ]; then
		rm -rf /koolshare/init.d/*adguardhome.sh
	fi

	# Permissions
	chmod 755 /koolshare/adguardhome/*
	chmod 755 /koolshare/init.d/*
	chmod 755 /koolshare/scripts/*
	chmod 755 /koolshare/perp/adguardhome/*

	# dbus value
	# echo_date "设置插件默认参数..."
	# dbus set ${module}_version="${PLVER}"
	# dbus set softcenter_module_${module}_version="${PLVER}"
	# dbus set softcenter_module_${module}_install="1"
	# dbus set softcenter_module_${module}_name="${module}"
	# dbus set softcenter_module_${module}_title="${TITLE}"
	# dbus set softcenter_module_${module}_description="${DESCR}"

	# re-enable
	if [ "${ENABLE}" == "1" -a -f "/koolshare/adguardhome/adguardhome.sh" ];then
		echo_date "安装完毕，重新启用AdGuardHome插件！"
		/koolshare/adguardhome/adguardhome.sh show
	fi
	
	# finish
	echo_date "${TITLE}插件安装完毕！"
	exit_install
}

install(){
	get_model
	get_fw_type
	platform_test
	install_now
}

install
