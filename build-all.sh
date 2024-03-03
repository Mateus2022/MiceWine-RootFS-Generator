#!/bin/bash
setupBuildEnv()
{
	case $NDK_VERSION in "25b")
		export PATH=$(echo $PATH | sed "s|:$NDK_ROOT/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin||g")
		;;
		"26b")
		export PATH=$(echo $PATH | sed "s|:$NDK_ROOT/26.1.10909125/toolchains/llvm/prebuilt/linux-x86_64/bin||g")
	esac

	case $1 in "25b")
		export PATH+=:$NDK_ROOT/25.2.9519653/toolchains/llvm/prebuilt/linux-x86_64/bin
	  	;;
	  	"26b")
	  	export PATH+=:$NDK_ROOT/26.1.10909125/toolchains/llvm/prebuilt/linux-x86_64/bin
	  	;;
	  	*)
	  	exit
	esac

	export NDK_VERSION="$1"

	export ANDROID_SDK="$2"

	export ARCH="$3"

	if [ "$ARCH" == "i686" ]; then
		export CC=i686-linux-android$ANDROID_SDK-clang
		export CXX=i686-linux-android$ANDROID_SDK-clang++
		export TOOLCHAIN_VERSION="x86-4.9"
		export TOOLCHAIN_TRIPLE="i686-linux-android"
	elif [ "$ARCH" == "x86_64" ]; then
		export CC=x86_64-linux-android$ANDROID_SDK-clang
		export CXX=x86_64-linux-android$ANDROID_SDK-clang++
		export TOOLCHAIN_VERSION="x86_64-4.9"
		export TOOLCHAIN_TRIPLE="x86_64-linux-android"
	elif [ "$ARCH" == "armeabi-v7a" ]; then
		export CC=armv7a-linux-androideabi$ANDROID_SDK-clang
		export CXX=armv7a-linux-androideabi$ANDROID_SDK-clang++
		export TOOLCHAIN_VERSION="arm-linux-androideabi-4.9"
		export TOOLCHAIN_TRIPLE="arm-linux-androideabi"
	elif [ "$ARCH" == "aarch64" ]; then
		export CC=aarch64-linux-android$ANDROID_SDK-clang
		export CXX=aarch64-linux-android$ANDROID_SDK-clang++
		export TOOLCHAIN_VERSION="aarch64-linux-android-4.9"
		export TOOLCHAIN_TRIPLE="aarch64-linux-android"
	fi

	export PKG_CONFIG_PATH=/data/data/com.micewine.emu/files/usr/share/pkgconfig:/data/data/com.micewine.emu/files/usr/lib/pkgconfig

	if [ "$4" != "--silent" ]; then
		echo -e "NDK Version: $NDK_VERSION\nAndroid API: $ANDROID_SDK\nArchitecture: $ARCH"
	fi
}

downloadPackages()
{
	for package in $PACKAGES; do 
		unset SRC_URL CONFIGURE_ARGS MESON_ARGS CMAKE_ARGS USE_NDK_VERSION RUN_POST_APPLY_PATCH CFLAGS LDFLAGS LIBS

		. ../packages/$package/build.sh

		echo "Downloading '$package'..."

		curl -# -L -O $SRC_URL

		case "$(basename $SRC_URL)" in *".tar"*)
			tar -xf "$(basename $SRC_URL)"

			ARCHIVE_CONTENT=$(tar -tf "$(basename $SRC_URL)")
			;;
			*".zip"*)
			unzip -o "$(basename $SRC_URL)" 1> /dev/null

			ARCHIVE_CONTENT=$(unzip -Z1 "$(basename $SRC_URL)")
		esac

		cd $(echo $ARCHIVE_CONTENT | cut -d"/" -f 1 | head -n 1)

		echo

		case $(ls ../../packages/$package | sed "s/build.sh//g") in "")
			;;
			*)
			for patch in $(ls ../../packages/$package | sed "s/build.sh//g"); do
				echo "Applying '$patch' for '$package'..."
				git apply -v ../../packages/$package/$patch
				$RUN_POST_APPLY_PATCH
				echo
			done
		esac

		#echo "export CFLAGS=$CFLAGS LIBS=$LIBS LDFLAGS=$LDFLAGS" > build.sh

		if [ -e "configure" ]; then
			echo "../configure --prefix=$PREFIX $CONFIGURE_ARGS" >> build.sh
			echo "make -j $(nproc) install" >> build.sh
		elif [ -e "autogen.sh" ]; then
			echo "../autogen.sh --prefix=$PREFIX $CONFIGURE_ARGS" >> build.sh
			echo "make -j $(nproc) install" >> build.sh
		elif [ -e "CMakeLists.txt" ]; then
			echo "cmake -DCMAKE_INSTALL_PREFIX=$PREFIX -DCMAKE_INSTALL_LIBDIR=$PREFIX/lib $CMAKE_ARGS .." >> build.sh
			echo "make -j $(nproc) install" >> build.sh
		elif [ -e "meson.build" ]; then
			echo "meson setup -Dprefix=$PREFIX $MESON_ARGS .." >> build.sh
			echo "ninja -j $(nproc) install" >> build.sh
		else
			echo "Unsupported build system. Stopping..."
			exit 1
		fi

		echo "setupBuildEnv $USE_NDK_VERSION 32 $ARCHITECTURE --silent" > setup-ndk.sh

		chmod +x build.sh

		cd ..

		mv $(echo $ARCHIVE_CONTENT | cut -d"/" -f 1 | head -n 1) $package

		rm "$(basename $SRC_URL)"
	done
}

compileAll()
{
	for i in $(ls); do
		mkdir -p "$i/build_dir"

		cd "$i/build_dir"

		echo "Compiling Package '$i'..."

		. ../setup-ndk.sh

		../build.sh 1> "$INIT_DIR/logs/$i-log.txt" 2> "$INIT_DIR/logs/$i-error_log.txt"

		cd ../..
	done
}

export PREFIX=/data/data/com.micewine.emu/files/usr

export ARCHITECTURE=aarch64

if [ "$NDK_ROOT" == "" ]; then
	echo "Please Provide a Valid Folder with NDK 25b and 26b on 'NDK_ROOT' environment variable."
	exit
fi

if [ ! -e "$PREFIX" ]; then
	sudo mkdir -p "$PREFIX"
	sudo chown -R $(whoami):$(whoami) "$PREFIX"
	sudo chmod 755 -R "$PREFIX"
else
	echo "Cleaning Prefix..."

	rm -rf $PREFIX/*
fi

if [ -e "workdir" ]; then
	echo "Cleaning Workdir..."
	rm -rf workdir
fi

if [ -e "logs" ]; then
	echo "Cleaning logs..."
	rm -rf logs
fi

setupBuildEnv 26b 32 aarch64 --silent

export PACKAGES=$(ls packages)

export INIT_DIR=$PWD

mkdir -p logs

mkdir -p workdir
cd workdir

downloadPackages
compileAll
