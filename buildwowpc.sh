#!/bin/bash
# Author: mosquito
# Email: sensor.wen@gmail.com
# Version: 0.2.1
# Date: Mon Jan 26 2015
# Reference:
# - chameleon - http://bbs.pcbeta.com/viewthread-1518901-1-1.html
# - chameleon 下载 - http://bbs.pcbeta.com/viewthread-1518850-1-1.html
# - smbios.plist 介绍 - http://bbs.pcbeta.com/viewthread-936953-1-1.html
# - plist 参数说明 - http://bbs.pcbeta.com/viewthread-798366-1-1.html
# - FakeSMC.kext 说明 - http://bbs.pcbeta.com/viewthread-799385-1-1.html
# - FakeSMC.kext 下载 - http://bbs.pcbeta.com/viewthread-1470065-1-1.html
# - boot1x - http://www.insanelymac.com/forum/topic/302938-exfat-volume-boot-record-for-chameleon
# - AIO Guides For Hackintosh - http://www.insanelymac.com/forum/topic/298027-guide-aio-guides-for-hackintosh
# - 黑苹果工具 Hackintosh Vietnam Tool - http://bbs.pcbeta.com/viewthread-1520292-1-1.html
# - Chain0 - http://wiki.osx86project.org/wiki/index.php/Chain0

## Changelog
# Mon Jan 26 2015 - 0.2.1
# - check revision
# Sun Jan 25 2015 - 0.2
# - add kext
# - check download file size
# Thu Jan 22 2015 - 0.1
# - initial version

Name="Chameleon"
#Version=`cat version`
#Revision=`cat revision`
#CopyFiles="doc/archive doc/BootHelp.txt \
CopyFiles="doc/BootHelp.txt \
doc/*.plist doc/*.pdf doc/*.png doc/README"

UserID=`id -u`
TopDir="$HOME/$Name"
PkgDir="${TopDir}/buildpkg"
BuildDir="${TopDir}/buildmedia"

SvnURL="http://forge.voodooprojects.org/svn/chameleon/trunk"
FakeDmg="http://hwsensors.com/content/01-releases/35-release-1364/HWSensors.6.14.1364.Binaries.dmg"
FakeDmgName="fakesmc.dmg"
FakePkg="http://hwsensors.com/content/01-releases/35-release-1364/HWSensors.6.14.1364.pkg"
FakePkgName="HWSensors.6.14.1364.pkg"
kextName="FakeSMC.kext"
MultiBeast="http://www.tonymacx86.com/downloads.php?do=file&id=252&act=down&actionhash=guest"
MultiName="multibeast-7.1.1.zip"
MultiDir="MultiBeast - Yosemite Edition/MultiBeast.app/Contents/Resources/"
kextPkgList="GenericUSBXHCI-v1.2.7.pkg NullCPUPowerManagement.pkg PS2-Keyboard-Mouse.pkg"


## curl to support multi-part download
# http://bbs.chinaunix.net/thread-917952-1-1.html
function mcurl() {
# usage: mcurl URL Output_Name PartNum
    url="$1"
    output="$2"
    opt="-s -A chrome -L"
    if [ "0$3" != "0" ];then
	parts="$3"
    else
	parts="6"
    fi

    # check length
    length=`curl -I $opt $url|awk '/Content-Length/{printf("%d",$2)}'`  # awk 'BEGIN{ORS=""}{print $0;}'
    if [ "0$length" -eq "0" ];then
	sleep 3
	mcurl $url $output $parts owner
    fi

    if [ "0$4" == "0" ];then
	echo -n "    "
    fi

    segsize=$((length/parts))
    curr=0
    error=0
    sleep 5

    # main
    for (( i=1; i <= parts; i++ ));do
	if [ $i -eq $parts ];then
	    curl -r $curr- $opt "$url" -o $output.$i || error=1
	else
	    curl -r $curr-$((curr+segsize-1)) $opt "$url" -o $output.$i || error=1
	    curr=$((curr+segsize))
	fi

	# curl download error
	if [ $error -eq 1 ];then
	    mv $output.$i $output
	    rm $output.* 2> /dev/null
	    error=0
	    break
	else
	    cat $output.$i >> $output
	    rm $output.$i
	    echo -n "."
	fi
    done

    # check file size
    size=`ls -l $output|awk '{printf("%d",$5)}'`
    if [ "0$length" -ne "0$size" ];then
	rm $output
	sleep 3
	mcurl $url $output $parts owner
    else
	echo "done"
    fi
}


## Check svn revision
function checksvn() {
    LocalRev=`svn info --xml | awk -F\" '/revision/{print $2;exit}'`
    RemoteRev=`svn info "$1" --xml | awk -F\" '/revision/{print $2;exit}'`
    if [ "0$LocalRev" -ne "0$RemoteRev" ];then
	echo "==> Updating $Name From $LocalRev to $RemoteRev ..."
	svn up -q -r HEAD
    fi
    NowRev=`svn info --xml | awk -F\" '/revision/{print $2;exit}'`
}


## Check environment
CheckOK=1

# os type
if [ ! -f /System/Library/CoreServices/SystemVersion.plist ];then
    echo "__Error: Require OS X system environment."
    CheckOK=0
else
    # root permission
    if [ $UserID -eq 0 ];then
	echo "__Error: Do not require ROOT permission."
	CheckOK=0
    fi

    # owner permission
    if [ ! -x $0 ];then
	echo "__Error: $0 permission denied. Please execution 'chmod 755 $0'."
	CheckOK=0
    fi

    # xcode
    if [ ! -d /Applications/Xcode.app ];then
	echo "__Error: No developer tools were found at '/Applications/Xcode.app', \
	Please install Xcode developer tools."
	CheckOK=0
    fi

    # gettext
    if [[ ! -f /usr/bin/msgmerge && ! -f /usr/local/bin/msgmerge ]];then
	echo "__Error: No such /usr/bin/msgmerge or /usr/local/bin/msgmerge command. \
	Please install 'homebrew', and then execution: brew install gettext."
	echo -e "\n  Easy install brew:\n  1. mkdir homebrew && curl -L https://github.com/Homebrew/homebrew/tarball/master | tar xz --strip 1 -C homebrew\n  2. sudo ln -s ~/homebrew/bin/brew /usr/local/bin/; sudo chown -R <UserName> /usr/local/"
	echo "    homebrew website: http://brew.sh"
	echo "    homebrew github: https://github.com/Homebrew/homebrew"
	CheckOK=0
    fi
fi

if [ $CheckOK -eq 0 ]; then
    exit 1
fi


## Banner
Banner="========== Welcome to use $0 script =========="
WordNum=`echo -n $Banner|wc -c`
echo -e "\n$Banner"
echo "    Author: mosquito"
echo "    Version: 0.2.1"
echo "    Date: Mon Jan 26 2015"
echo -e "\n    Next, build $Name and wowpc.iso ..."

for ((i=0;i<$WordNum;i++));do
    echo -n "="
done
echo -e "\n"


## Compile chameleon
cd $HOME

# svn checkout
if [ ! -d $TopDir ];then
    echo "==> Get $Name source code ..."
    svn co -q $SvnURL $Name || exit 1
#    chown -R $UserID $TopDir
fi

# check revision
echo "==> Check $Name source code Rev ..."
cd $TopDir
checksvn $SvnURL
echo "==> Current revision: $NowRev"

# compile chameleon
echo "==> Built $Name ..."
make > /dev/null
echo "==> Built $Name tgz ..."
make dist > /dev/null
echo "==> Built $Name pkg ..."
make pkg > /dev/null
Version=`cat version`
Revision=`cat revision`
SrcName="$Name-$Version-r$Revision.src.tar.xz"


## Build bootmedia
echo "==> Start build wowpc.iso ..."
mkdir -p $PkgDir/{doc,boot} $BuildDir
cp -R sym/$Name-$Version-r$Revision/ $BuildDir/
cp $BuildDir/usr/standalone/i386/boot $BuildDir/

# Require kext: AppleACPIPS2Nub.kext ApplePS2Controller.kext or VoodooPS2Controller.kext, FakeSMC.kext, GenericUSBXHCI.kext, NullCPUPowerManagement.kext # PS2 驱动, 模拟苹果设备, USB3.0 驱动, 禁用电源管理
# Source code:
# - AppleACPIPS2Nub https://github.com/AppleLife/ACPIPS2Nub
# - ApplePS2Controller https://github.com/AppleLife/ApplePS2Controller
# - VoodooPS2Controller https://github.com/RehabMan/OS-X-Voodoo-PS2-Controller
# - FakeSMC https://bitbucket.org/kozlek/hwsensors/commits/all
# - GenericUSBXHCI https://github.com/RehabMan/OS-X-Generic-USB3
# - NullCPUPowerManagement https://github.com/AppleLife/NullCPUPowerManagement
# - 其他源码: http://opensource.apple.com/source
# - MultiBeast 驱动包: http://www.tonymacx86.com
# - Hackintosh Vietnam Tool 驱动包:
#     http://www.hackintoshosx.com/files/file/3842-hackintosh-vietnam-ultimate-aio-tool
#     http://www.insanelymac.com/forum/files/file/210-hackintosh-vietnam-ultimate-aio-tool
# kext's path /System/Library/Extension, /Extra/Extensions
mkdir $BuildDir/Extra/Extensions/
if [ ! -f $FakeDmgName ];then
    echo "==> Download $kextName to EE/ ..."
    mcurl $FakeDmg $FakeDmgName || (echo "__Error: Download failed." && exit 1)
fi
echo "==> Mount $FakeDmgName ..."
hdiutil attach -mountpoint fakesmc -noverify -quiet $FakeDmgName
echo "==> Install $kextName to EE/ ..."
cp -R fakesmc/$kextName $BuildDir/Extra/Extensions/
echo "==> Umount $FakeDmgName ..."
hdiutil detach fakesmc -quiet

if [ ! -f $MultiName ];then
    echo "==> Download $MultiName ..."
    mcurl $MultiBeast $MultiName 1 || (echo "__Error: Download failed." && exit 1)
#    cp $MultiName $PkgDir/
fi

# Expand pkg
unzip -q $MultiName || exit 1
cd "$MultiDir"

for i in $kextPkgList;do
    xar -xf $i
    mv Payload Payload.gz
    gzip -d Payload.gz
    cat Payload | cpio -id
    echo "==> Install ${i%.*} to EE/ ..."
done
cp -R *.kext $BuildDir/Extra/Extensions/
cd - > /dev/null

# org.chameleon.Boot.plist main configure file
# 使用变色龙助手 chameleon wizard 可图形配置
echo "==> Write org.chameleon.Boot.plist to Extra/ ..."
cat > $BuildDir/Extra/org.chameleon.Boot.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Instant Menu</key>		<string>Yes</string>
<!--	自定义配置文件位置
	<key>config</key>		<string>/Extra/org.chameleon.Boot.plist</string>
	<key>SMBIOS</key>		<string>/Extra/smbios.plist</string>
	<key>DSDT</key>			<string>/Extra/DSDT.aml</string>
	<key>kext</key>			<string>/Extra/Extensions</string>
-->
	<key>ShowInfo</key>		<string>Yes</string>
	<key>Graphics Mode</key>	<string>1024x768x32</string>
	<key>GraphicsEnabler</key>	<string>No</string>  <!-- 自动侦测显卡, 代替 DSDT 中添加的显卡参数 -->
	<key>Theme</key>		<string>Default</string>
	<key>Kernel</key>		<string>/System/Library/Kernels/kernel</string>
	<key>Kernel Flags</key>		<string>-v -f kext-dev-mode=1</string>  <!-- -f 启动时重建kext缓存 -x 安全模式, 加载全部kext; -s 单用户 -->
	<key>UseKernelCache</key>	<string>No</string>
<!--	<key>Default Partition</key>	<string>hd(0,1)</string>         <hd(x,y)|UUID|Label>  -->
<!--	<key>Hide Partition</key>	<string>hd(0,1) hd(0,5)</string> <hd(x,y)|UUID|Label>  -->
<!--	<key>Rename Partition</key>	<string>hd(0,1) OSX</string>     <hd(x,y)|UUID|Label] <alias>  -->
	<key>Quiet Boot</key>		<string>No</string>
	<key>Timeout</key>		<string>4</string>
	<key>Boot Banner</key>		<string>No</string>  <!-- 变色龙版本信息 -->
	<key>Legacy Logo</key>		<string>No</string>
	<key>RestartFix</key>		<string>Yes</string>  <!-- 重启修复功能 -->
	<key>System-Type</key>		<string>2</string>  <!-- 1,台式 2,笔记本 3,工作站 -->
	<key>DropSSDT</key>		<string>No</string>  <!-- 忽略BIOS内的SSDT, 加载Extra内的SSDT -->
	<key>GenerateCStates</key>	<string>Yes</string>  <!-- 启用生成 CPU C-State, 闲置状态降频 -->
	<key>GeneratePStates</key>	<string>Yes</string>  <!-- 启用生成 CPU P-State, 在不同负载下改变频率 -->
	<key>EnableC2State</key>	<string>Yes</string>  <!-- 启用 C2 State -->
	<key>EnableC3State</key>	<string>Yes</string>  <!-- 启用 C3 State -->
	<key>EnableC4State</key>	<string>Yes</string>  <!-- 启用 C4 State -->
	<key>UseNvidiaROM</key>		<string>No</string>  <!-- Nvidia EEPRom 功能, 不刷显卡BIOS情况下, 使用修改的Rom. 命名: VenderID_DeviceID.rom, 保存至Extra. -->
	<key>UseAtiROM</key>		<string>No</string>  <!-- Ati EEPRom 功能 -->
	<key>EthernetBuiltIn</key>	<string>No</string>  <!-- 将网卡识别为内置网卡 -->
	<key>Wake</key>			<string>Yes</string>  <!-- 睡眠唤醒功能 -->
	<key>SMBIOSdefaults</key>	<string>No</string>  <!-- 启用 smbios 预设值 -->
</dict>
</plist>
EOF

# SMBios.plist - 捕捉 OSX 侦测所显示的错误信息, 如硬件信息, 序列号, Boot Rom 版本等
# 可由 chameleon wizard 生成, SSDT/DSDT.aml 可用 Everest 查询
echo "==> Write smbios.plist to Extra/ ..."
cat > $BuildDir/Extra/smbios.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>SMfamily</key>		<string>MacBookPro</string>  <!-- 产品类型 MacPro/Mac -->
	<key>SMproductname</key>	<string>MacBookPro6,1</string>  <!-- 产品型号, 需对应产品类型 -->
	<key>SMmanufacturer</key>	<string>Apple Inc.</string>  <!-- 制造商 -->
	<key>SMbiosvendor</key>		<string>Apple Inc.</string>  <!-- BIOS 供应商 -->
	<key>SMbiosdate</key>		<string>01/02/08</string>
	<key>SMbiosversion</key>	<string>MBP61.88Z.0057.B0C.1007261552</string>  <!-- BIOS版本 -->
	<key>SMboardmanufacturer</key>	<string>Apple Inc.</string>  <!-- 主板制造商 -->
	<key>SMboardproduct</key>	<string>Mac-F22589C8</string>  <!-- 主板型号 -->
	<key>SMserial</key>		<string>C02CJ2DNDC79</string>  <!-- 序列号 -->
	<key>SMsystemversion</key>	<string>1.0</string>
	<key>SMcputype</key>		<string>1537</string>  <!-- CPU 类型, Core 2 Solo/257 Core 2 Duo/769 Core 2 Quad/1281 Core i5/1537 Core i7/1793 -->
	<key>SMmaximalclock</key>	<string>2400</string>  <!-- CPU 主频, 外频x倍频 -->
	<key>SMexternalclock</key>	<string>100</string>  <!-- CPU 外频 -->
	<key>SMbusspeed</key>		<string>2400</string>  <!-- 总线速度 -->
	<key>SMmemtype</key>		<string>24</string>  <!-- 内存类型 DDR2=19 DDR3=24 -->
	<key>SMmemspeed</key>		<string>1333</string>  <!-- 内存速度 -->
	<key>SMmemmanufacturer_1</key>	<string>Kingston</string>  <!-- 内存制造商 -->
	<key>SMmemmanufacturer_2</key>	<string>Kingston</string>  <!-- 内存制造商 -->
	<key>SMmempart_1</key>		<string>9905458-009.A00LF</string>  <!-- 内存编号 -->
	<key>SMmempart_2</key>		<string>9905458-009.A00LF</string>  <!-- 内存编号 -->
	<key>SMmemserial_1</key>	<string>76344B29</string>  <!-- 内存序号 -->
	<key>SMmemserial_2</key>	<string>76344B29</string>  <!-- 内存序号 -->
</dict>
</plist>
EOF

# Backup wowpc.iso content to boot/ directory
cp -R $BuildDir/ $PkgDir/boot/

# Delete some files
rm -rf $BuildDir/Extra/{Keymaps,modules/*}
cp $PkgDir/boot/Extra/modules/Keylayout.dylib $BuildDir/Extra/modules/
#sudo chown -R root:wheel $BuildDir/

# Build wowpc.iso
# <Linux build bootable ISO>
# mkisofs -part -hfs -joliet -rock -eltorito-boot usr/standalone/i386/cdboot -no-emul-boot \
#	-volid "Chameleon" -hfs-volid "Chameleon" -o wowpc.iso boot/
# mkisofs -part -h -J -R -b usr/standalone/i386/cdboot -no-emul-boot \
#	-V "Chameleon" -hfs-volid "Chameleon" -o wowpc.iso boot/
# 部分参数:
# -no-emul-boot 非模拟模式, -mac-name 使用mac文件名, -part 生成HFS分区表
# -J 生成Joliet目录信息, -R 生成Rock Ridge目录信息, -quiet 安静模式
# -boot-load-size #  载入扇区数
# -sysid 'APPLE INC., TYPE: 0002'  系统 ID, 32字符
# -A, -appid ''  应用 ID, 128字符
# -iso-level 1..4  ISO 级别, 1 文件可能只包含一部分, 文件名限制为8.3字符. 2 文件可能只包含一部分. 3 无限制
#   级别 1-3, 文件名限制为大写字母,数字,下划线, 31字符, 目录嵌套最多8层, 路径名限制为 255 字符.
# -ucs-level 1..3  Joliet 级别
# -no-iso-translate 不转换ISO字符 '~', '-', '#'
# -l, -full-iso9660-filenames 允许完整 31 字符长文件名
# -d, -omit-period 省略文件名尾句点
# -N, -omit-version-number 省略文件版本号
# -allow-leading-dots 允许文件名以 . 开头
# -relaxed-filenames 允许文件名包含7bit ASCII字符
# -allow-lowercase 允许使用小写字符
# -allow-multidot 允许多个点
# -U, -untranslated-filenames 不转换文件名 (-l, -d, -N, -allow-leading-dots, -relaxed-filenames, -allow-lowercase, -allow-multidot)
echo "==> Build wowpc.iso to $PkgDir/ ..."
hdiutil makehybrid -iso -hfs -joliet -quiet \
 -eltorito-boot $BuildDir/usr/standalone/i386/cdboot -no-emul-boot \
 -hfs-volume-name "$Name" \
 -joliet-volume-name "$Name" \
 -iso-volume-name "$Name" \
 -o $PkgDir/wowpc.iso $BuildDir/
#sudo chown -R $UserID $TopDir


## Build package
echo "==> Copy some files to $PkgDir/ ..."
cp -R $CopyFiles $PkgDir/doc/
cp sym/*.pkg $PkgDir/

# Download FakeSMC.kext
if [ ! -f $PkgDir/$FakePkgName ];then
    echo "==> Download $FakePkgName to $PkgDir/ ..."
    mcurl $FakePkg $PkgDir/$FakePkgName || (echo "__Error: Download failed." && exit 1)
fi

# Help files
echo "==> Write README_en.txt ..."
cat > $PkgDir/README_en.txt <<EOF

------------------------------------------------------------------------

                            Installation
                        ====================
 
  Normal Install (non-RAID)(Install Mac to first-disk)(boot0, boot0hfs):
------------------------------------------------------------------------
  List the partitions of root disk
            diskutil list
  /dev/disk0
   #:                       TYPE NAME            SIZE       IDENTIFIER
   0:     FDisk_partition_scheme		*320.0 GB   disk0
   1:               Windows_NTFS	WinXP	  30.0 GB   disk0s1
   2:               Apple_HFS		MacSnow	  40.0 GB   disk0s2
   3:               Windows_NTFS	Win7	  50.0 GB   disk0s3
   4:               Windows_NTFS	Data	 200.0 GB   disk0s5

  Suppose that your installation is on /dev/disk0s2 
   - Install boot0hfs to the MBR:
            sudo ./fdisk440 -f boot0hfs -u -y /dev/rdisk0
   - Install boot1h to the partition's bootsector:
            sudo dd if=boot1h of=/dev/rdisk0s2
   - Install boot to the partition's root directory:
            sudo cp boot /                                  Finish.
  

  Normal Install (non-RAID)(Install Mac to second-disk)(boot0md):
------------------------------------------------------------------------
  List the partitions of root disk
            diskutil list
  /dev/disk0
   #:                       TYPE NAME            SIZE       IDENTIFIER
   0:     FDisk_partition_scheme		*320.0 GB   disk0
   1:               Windows_NTFS	WinXP	  40.0 GB   disk0s1
   2:               Windows_NTFS	Win7	  60.0 GB   disk0s2
   3:               Windows_NTFS	Data	 220.0 GB   disk0s3
  /dev/disk1
   #:                       TYPE NAME            SIZE       IDENTIFIER
   0:     FDisk_partition_scheme		*500.0 GB   disk1
   1:               Windows_NTFS	Temp	 150.0 GB   disk1s1
   2:               Apple_HFS		MacSnow	  50.0 GB   disk1s2
   3:               Windows_NTFS	data	 300.0 GB   disk1s3

  Suppose that your installation is on /dev/disk1s2 
   - Install boot0md to the MBR of first-disk(boot disk):
            sudo ./fdisk440 -f boot0md -u -y /dev/rdisk0
   - Install boot1h to the partition's bootsector of second-disk:
            sudo dd if=boot1h of=/dev/rdisk1s2
   - Install boot to the partition's root directory:
            sudo cp boot /                                  Finish.

 boot0		searches for boot1h on the first active partition. 
		Need to activates your selected target partition.
 boot0hfs	searches for boot1h on the first partition, regardless 
		of active flag.
 boot0md	could search for boot1h on the first active partition
		of second disk. Need to activates the target partition.

Rename to be /Extra/com.apple.Boot.plist by yourself for Rev 1104 before only.
Rename to be /Extra/org.chameleon.Boot.plist by yourself for Rev 1105 after only.

------------------------------------------------------------------------


README


------------------------------------------------------------------------
EOF

cat $PkgDir/doc/README >> $PkgDir/README_en.txt
cat >> $PkgDir/README_en.txt <<EOF
------------------------------------------------------------------------


BootHelp.txt


------------------------------------------------------------------------

EOF
cat $PkgDir/doc/BootHelp.txt >> $PkgDir/README_en.txt

echo "==> Write README_cn.txt ..."
cat > $PkgDir/README_cn.txt <<EOF

------------------------------------------------------------------------

                              前   言
                           =============

  如何选择合适的 bootloader ?
------------------------------------------------------------------------
  目前主流的引导工具有 Chameleon 和 Clover.
  - Chameleon 历史悠久, 但功能上不及 Clover, 只支持 Legacy BIOS 引导.
  - Clover 是一款基于 EFI 的引导工具, 可在传统 BIOS 启动内置 CloverEFI(模拟EFI)
引导. 很多问题, 如五国/-v卡死都可以通过配置 config.plist 解决, 兼容 UEFI/BIOS.

  镜像版本:
  - 懒人版: 支持安装到 MBR/GPT 分区表的磁盘. 可方便替换安装盘内容, 但不生成
RecoveryHD 恢复分区.
  - 原版: 可由 Clover 直接引导原版镜像, 自动生成恢复分区, 但仅支持安装到 GPT
分区表的磁盘.

  引导与镜像搭配方案:
  - BIOS+MBR: Clover/变色龙 + 懒人版
  - UEFI+GPT: Clover + 原版/懒人版
  - BIOS+GPT: Clover/变色龙 + 原版/懒人版
  - UEFT+MBR: MBR 转 GPT or Clover + 懒人版 or 修改为 BIOS 引导

  附: Chameleon 启动流程
  BIOS -> MBR(boot0*) -> PBR(boot1h*) -> boot -> OSLoader
  PS: 完成加电自检后, BIOS 会加载 MBR 的前 446 字节引导代码至内存, 之后检查分区表(DPT)
      由分区表项记录的分区 LBA 找到分区引导记录(PBR), 由 PBR 加载分区中的引导文件,
      最后完成系统启动.


------------------------------------------------------------------------

                            手动安装说明
                         =================

  操作 MBR 存在一定风险, 建议首先备份 MBR 至外部存储 !!!
------------------------------------------------------------------------
  - Linux 系统备份 MBR:
	# sudo dd if=/dev/sda of=stage1 bs=512 count=1

  - 单独备份分区表:
	# sudo dd if=/dev/sda of=stage1.dpt bs=1 count=64 skip=446

  - 单独恢复分区表:
	# sudo dd if=stage1.dpt of=/dev/sda bs=1 count=64 seek=446
	PS: ibs 一次读取字节数; obs 一次写入字节数; skip 跳过ibs N次后读取;
	    seek 跳过obs N次后写入. Mac, Windows 系统同理.

  附: 备份 GPT 分区表
  - 备份 GPT 表头:
	# sudo dd if=/dev/sda of=GPT.head bs=512 count=2
	PS: Protection MBR 和 GPT Header 占用 2 个扇区.

  - 备份 GPT 分区表:
	# sudo dd if=/dev/sda of=GPT.full bs=512 count=34
	PS: GPT 分区表最小占用 34 扇区, 一般安装系统时会保留前 2048 扇区.


  正常安装 (non-RAID)(安装 Mac 到第一个硬盘)(boot0, boot0hfs):
------------------------------------------------------------------------
  查询 Mac 分区位置: diskutil list
  /dev/disk0
     #:                       TYPE NAME            SIZE       IDENTIFIER
     0:     FDisk_partition_scheme                *320.0 GB   disk0
     1:               Windows_NTFS WinXP           30.0 GB    disk0s1
     2:                  Apple_HFS MacSnow         40.0 GB    disk0s2
     3:               Windows_NTFS Win7            50.0 GB    disk0s3
     4:               Windows_NTFS Data            200.0 GB   disk0s5

  假设您的 Mac 安装在 /dev/disk0s2
   - 安装 boot0hfs 至 MBR (Mac):
            sudo ./fdisk440 -f boot0hfs -u -y /dev/rdisk0
   - 安装 boot0hfs 至 MBR (Linux):
            sudo dd if=boot0hfs of=/dev/sdX bs=440 count=1
            PS: MBR 前 446 字节为启动代码, 之后 64 字节为分区表, 55AA 结束标志.
		chameleon 启动代码 440 字节, 所以不用担心影响分区表.
   - 安装 boot1h 至分区引导扇区 (Mac/Linux):
            sudo dd if=boot1h of=/dev/rdisk0s2
   - 安装 boot 至 Mac 分区根目录:
            sudo cp boot /                                  完成安装


  正常安装 (non-RAID)(安装 Mac 到第二个硬盘)(boot0md):
------------------------------------------------------------------------
  查询 Mac 分区位置: diskutil list
  /dev/disk0
     #:                       TYPE NAME            SIZE       IDENTIFIER
     0:     FDisk_partition_scheme                *320.0 GB   disk0
     1:               Windows_NTFS WinXP           40.0 GB    disk0s1
     2:               Windows_NTFS Win7            60.0 GB    disk0s2
     3:               Windows_NTFS Data            220.0 GB   disk0s3
  /dev/disk1
     #:                       TYPE NAME            SIZE       IDENTIFIER
     0:     FDisk_partition_scheme                *500.0 GB   disk1
     1:               Windows_NTFS Temp            150.0 GB   disk1s1
     2:                  Apple_HFS MacSnow         50.0 GB    disk1s2
     3:               Windows_NTFS data            300.0 GB   disk1s3

  假设您的 Mac 安装在 /dev/disk1s2
   - 安装 boot0md 至第一磁盘 (引导磁盘) 的 MBR (Mac):
            sudo ./fdisk440 -f boot0md -u -y /dev/rdisk0
   - 安装 boot0md 至第一磁盘 (引导磁盘) 的 MBR (Linux):
            sudo dd if=boot0hfs of=/dev/sdX bs=440 count=1
   - 安装 boot1h 至第二磁盘 Mac 分区引导扇区 (Mac/Linux):
            sudo dd if=boot1h of=/dev/rdisk1s2
   - 安装 boot 至 Mac 分区根目录:
            sudo cp boot /                                  完成安装


  选择合适的 boot0xxx, boot1xxx 进行手动安装
------------------------------------------------------------------------
 boot		变色龙核心文件 (stage2, 以下文件为 stage1).
 boot0		寻找第一个激活分区的 boot1h, 需激活目标分区.
 boot0hfs	寻找第一个 HFS 分区的 boot1h, 不需要激活标志.
 boot0md	同 boot0, 寻找第二个磁盘的第一个激活分区的 boot1h, 需激活
		目标分区.
 boot1f32	适用于 FAT32 文件系统分区的 stage1.5 引导信息.
 boot1h		适用于 HFS+ 文件系统分区的 stage1.5 引导信息.
 boot1x		适用于 exFAT 文件系统分区的 stage1.5 引导信息.
 cdboot		用于引导 iso 镜像的引导信息.

 工具:
 bdmesg		记录/查看启动信息.

 boot1-install	安装分区引导信息 boot1f32, boot1h, boot1x 至指定分区.
	用法: boot1-install [-yMu] [-f boot_code_file] disk
	 boot_code_file 是一个可选的引导模版
	 -y: 不询问任何问题
	 -M: 保持挂载卷, 并进行安装 (用于根文件系统)
	 -u: 强制卸载 (抑制 -M 选项)
	 'disk' 参数形式为 /dev/rdiskUsS 或 /dev/diskUsS

 cham-mklayout	将 i386/modules/Keylayout/layouts/layouts-src/*.slt 文件转换
		为键布局文件 *.lyt

 fdisk440	安装 boot0xxx 至 MBR 前 440 字节.
	用法: fdisk440 [-ieu] [-f mbrboot] [-c cyl -h head -s sect] [-S size]
	      [-r] [-a style] disk
	 -i: 以新 MBR 初始化磁盘
	 -u: 更新 MBR 代码, 不影响分区表
	 -e: 交互式编辑磁盘 MBR
	 -f: 指定非标准 MBR 模版
	 -chs: 指定磁盘结构 (柱面/磁头/扇区)
	 -S: 指定磁盘大小
	 -r: 从标准输入读取分区规格 (隐含 -i)
	 -a: 使用指定 style 自动分区
	 -d: 转储分区表
	 -y: 不询问任何问题
	 -t: 测试, 如果磁盘已分区
	 'disk' 参数形式为 /dev/rdisk0

	auto-partition styles:
	  boothfs     8Mb boot+ HFS+ 根分区 (默认)
	  bootufs     8Mb boot+ UFS 根分区
	  hfs         整个磁盘为一个 HFS+ 分区
	  ufs         整个磁盘为一个 UFS 分区
	  dos         整个磁盘为一个 DOS 分区
	  raid        整个磁盘为一个 0xAC 分区

配置文件名为 /Extra/com.apple.Boot.plist (Rev 1104 以前版本)
            /Extra/org.chameleon.Boot.plist (Rev 1105 以后版本)


------------------------------------------------------------------------

                        4kb 硬盘手动安装说明
                     =========================

    用于 MBR 分区, 主要解决 4kb 扇区的硬盘, 无法顺利安装 Mac 版变色龙 pkg 的
问题. 如 WD, Seagate 1TB, 2TB 的 4kb 大硬盘, 会发生以下错误, 无法引导 boot.
boot0: test
boot0: error
------------------------------------------------------------------------
4kb 硬盘手动安装 boot1h 的方法 (适用 MBR, GPT 分区)

方法一:
  1. Mac 下载安装变色龙 pkg, 将 boot1h 复制到 /Extra/.
  2. 进入 linux, 终端输入 "fdisk -l /dev/sda", 确认 Mac 分区位置.
  3. 挂载 Mac 分区: "mount /dev/sda2 /mnt/"
  4. 写入 boot1h 至 /dev/sda2:
     "dd if=/mnt/Extra/boot1h of=/dev/sda2 bs=4096 count=1"

方法二:
  1. Mac 下载安装变色龙 pkg, 将 boot1h 复制到 U 盘.
  2. Win 下载 http://www.chrysocome.net/downloads/dd-0.6beta3.zip, 找到 dd.exe.
  3. 用 "管理员身份" 运行 cmd, 执行 "dd.exe --list" 查看分区表.
  4. 假设 Mac 分区为 "\\?\Device\Harddisk0\Partition2", 则执行以下命令:
     "dd.exe if=boot1h of=\\?\Device\Harddisk0\Partition2 bs=4096 count=1"


------------------------------------------------------------------------

                             相关问题
                          ==============
 URL: http://bbs.pcbeta.com/viewthread-863656-1-1.html
------------------------------------------------------------------------
  1. 启动卡在 SMC: successfully initialized.
     BIOS 关闭 Legacy USB/EHCI Hand-Off.

  2. 可使用以下两款驱动工具包, 完善系统对硬件的支持.
     - MultiBeast:
       http://www.tonymacx86.com

     - Hackintosh Vietnam Tool:
       http://www.hackintoshosx.com/files/file/3842-hackintosh-vietnam-ultimate-aio-tool
       http://www.insanelymac.com/forum/files/file/210-hackintosh-vietnam-ultimate-aio-tool

参考:
  http://bbs.pcbeta.com/viewthread-971434-1-1.html
  http://forge.voodooprojects.org/p/chameleon/issues/129/#ic1566

EOF

echo "==> Generation $Name-$Version-r$Revision.tar.xz ..."
mv $PkgDir $Name-$Version-r$Revision
tar --exclude=".DS_Store" \
  -Jcf $HOME/Desktop/$Name-$Version-r$Revision.tar.xz $Name-$Version-r$Revision/

echo "==> Generation $SrcName ..."
rm -rf $BuildDir $Name-$Version-r$Revision MultiBeast* __MACOSX
make clean > /dev/null
cd $HOME
tar --exclude=".DS_Store" --exclude=".svn" \
    --exclude="$MultiName" --exclude="$FakeDmgName" \
  -Jcf $HOME/Desktop/$SrcName $Name/

echo "==> Done."
#rm -rf $TopDir
